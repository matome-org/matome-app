// Linked into the e2e WASM build only (.scripts/e2e.sh), never into
// the shipped studio. It gives the browser suite eyes on the canvas:
// window.matomeE2E(request) finds items by objectName and answers where they
// are on the page and what they show. It never clicks, types, or calls into
// the app; Playwright drives the page with real mouse, keyboard, and touch.
//
// A request is one JSON object with an `op`:
//   items    {name | prefix, title?, child?, props?}  every match, visible first
//   focus    {}                                       the focused item and its ancestors
//   object   {name, props}                            a QML singleton (Session, Theme)
//   rows     {object, model, roles}                   a singleton model's rows
//   wiring   {}                                       fonts, icon, names, window colour and width, double-click interval
// Rectangles are CSS pixels relative to the Qt screen element.

#include "Wiring.h"

#include <QAbstractItemModel>
#include <QAccessible>
#include <QColor>
#include <QFont>
#include <QFontInfo>
#include <QJsonDocument>
#include <QPolygonF>
#include <QStyleHints>

#include <emscripten.h>
#include <emscripten/bind.h>

#include <string>

namespace {

using matome::probe::descendants;

QJsonValue toJson(const QVariant &value)
{
    switch (value.metaType().id()) {
    case QMetaType::QColor:
        return value.value<QColor>().name(QColor::HexArgb);
    case QMetaType::QFont: {
        const QFont font = value.value<QFont>();
        return QJsonObject{{QStringLiteral("family"), font.families().value(0, font.family())},
                           {QStringLiteral("resolved"), QFontInfo(font).family()},
                           {QStringLiteral("pixelSize"), font.pixelSize()},
                           {QStringLiteral("italic"), font.italic()}};
    }
    default:
        break;
    }
    if (value.metaType().flags() & QMetaType::PointerToQObject) {
        const QObject *object = value.value<QObject *>();
        return object ? QJsonValue(object->objectName()) : QJsonValue();
    }
    return QJsonValue::fromVariant(value);
}

QString roleName(QAccessible::Role role)
{
    const QMetaEnum names = QMetaEnum::fromType<QAccessible::Role>();
    const char *name = names.valueToKey(role);
    return name ? QString::fromLatin1(name) : QString::number(role);
}

// Every non-empty `text` shown at or under `item`: a tooltip's words and key
// chip, an empty state's phrase.
QJsonArray texts(QQuickItem *item)
{
    QJsonArray out;
    for (QQuickItem *at : descendants(item)) {
        const QString text = at->property("text").toString();
        if (at->isVisible() && !text.isEmpty())
            out.append(text);
    }
    return out;
}

// Where it is, whether it shows, the properties asked for ("$texts" for
// texts()), and what it says to a screen reader.
QJsonObject describe(QQuickItem *item, const QJsonArray &props)
{
    // The box around the four mapped corners: rotated or scaled items (a
    // turned chevron) are hit where they are drawn.
    QPolygonF corners;
    for (const QPointF &corner : {QPointF(0, 0), QPointF(item->width(), 0), QPointF(0, item->height()),
                                  QPointF(item->width(), item->height())})
        corners.append(item->mapToGlobal(corner));
    const QRectF box = corners.boundingRect();
    QJsonObject values;
    for (const QJsonValue &prop : props) {
        const QString name = prop.toString();
        values.insert(name, name == QLatin1String("$texts")
                                    ? QJsonValue(texts(item))
                                    : toJson(item->property(name.toUtf8().constData())));
    }
    QJsonObject out{{QStringLiteral("name"), item->objectName()},
                    {QStringLiteral("visible"), item->isVisible()},
                    {QStringLiteral("focus"), item->hasActiveFocus()},
                    {QStringLiteral("x"), box.x()},
                    {QStringLiteral("y"), box.y()},
                    {QStringLiteral("w"), box.width()},
                    {QStringLiteral("h"), box.height()},
                    {QStringLiteral("props"), values}};
    if (QAccessibleInterface *named = QAccessible::queryAccessibleInterface(item)) {
        const QAccessible::State state = named->state();
        out.insert(QStringLiteral("a11y"),
                   QJsonObject{{QStringLiteral("name"), named->text(QAccessible::Name)},
                               {QStringLiteral("role"), roleName(named->role())},
                               {QStringLiteral("checkable"), bool(state.checkable)},
                               {QStringLiteral("checked"), bool(state.checked)}});
    }
    return out;
}

// Items named `name` (or starting with `prefix`) that show `title` when
// asked, or their first descendant named `child`; visible ones first.
QJsonArray items(QQuickWindow *window, const QJsonObject &request)
{
    const QString name = request.value(QStringLiteral("name")).toString();
    const QString prefix = request.value(QStringLiteral("prefix")).toString();
    const QJsonValue title = request.value(QStringLiteral("title"));
    const QString child = request.value(QStringLiteral("child")).toString();
    const QJsonArray props = request.value(QStringLiteral("props")).toArray();
    QList<QQuickItem *> shown;
    QList<QQuickItem *> hidden;
    for (QQuickItem *item : descendants(window->contentItem())) {
        const QString at = item->objectName();
        if (prefix.isEmpty() ? at != name : !at.startsWith(prefix))
            continue;
        if (!title.isUndefined() && item->property("title").toString() != title.toString())
            continue;
        QQuickItem *found = item;
        if (!child.isEmpty()) {
            found = nullptr;
            for (QQuickItem *below : descendants(item)) {
                if (below != item && below->objectName() == child) {
                    found = below;
                    break;
                }
            }
            if (!found)
                continue;
        }
        (item->isVisible() ? shown : hidden).append(found);
    }
    QJsonArray out;
    for (QQuickItem *item : shown + hidden)
        out.append(describe(item, props));
    return out;
}

QJsonObject focus(QQuickWindow *window)
{
    QJsonArray chain;
    for (QQuickItem *at = window->activeFocusItem(); at; at = at->parentItem()) {
        if (!at->objectName().isEmpty())
            chain.append(at->objectName());
    }
    QQuickItem *item = window->activeFocusItem();
    return {{QStringLiteral("name"), item ? item->objectName() : QString()},
            {QStringLiteral("chain"), chain},
            {QStringLiteral("text"), item ? item->property("text").toString() : QString()}};
}

QJsonObject object(QQuickWindow *window, const QJsonObject &request)
{
    QObject *target = matome::probe::singleton(window, request.value(QStringLiteral("name")).toString());
    QJsonObject out;
    if (!target)
        return out;
    for (const QJsonValue &prop : request.value(QStringLiteral("props")).toArray()) {
        const QString name = prop.toString();
        out.insert(name, toJson(target->property(name.toUtf8().constData())));
    }
    return out;
}

QJsonArray rows(QQuickWindow *window, const QJsonObject &request)
{
    QObject *target = matome::probe::singleton(window, request.value(QStringLiteral("object")).toString());
    const QByteArray property = request.value(QStringLiteral("model")).toString().toUtf8();
    auto *model = target ? target->property(property.constData()).value<QAbstractItemModel *>()
                         : nullptr;
    QJsonArray out;
    if (!model)
        return out;
    const QHash<int, QByteArray> names = model->roleNames();
    const QJsonArray roles = request.value(QStringLiteral("roles")).toArray();
    for (int row = 0; row < model->rowCount(); ++row) {
        QJsonObject values;
        for (const QJsonValue &role : roles) {
            const int key = names.key(role.toString().toUtf8(), -1);
            values.insert(role.toString(), toJson(model->index(row, 0).data(key)));
        }
        out.append(values);
    }
    return out;
}

QJsonObject wiring(QQuickWindow *window)
{
    QJsonObject out = matome::probe::wiring();
    out.insert(QStringLiteral("windowColor"), window->color().name(QColor::HexArgb));
    out.insert(QStringLiteral("doubleClickMs"), QGuiApplication::styleHints()->mouseDoubleClickInterval());
    out.insert(QStringLiteral("width"), window->width());
    return out;
}

QJsonValue answer(QQuickWindow *window, const QJsonObject &request)
{
    const QString op = request.value(QStringLiteral("op")).toString();
    if (op == QLatin1String("items"))
        return items(window, request);
    if (op == QLatin1String("focus"))
        return focus(window);
    if (op == QLatin1String("object"))
        return object(window, request);
    if (op == QLatin1String("rows"))
        return rows(window, request);
    if (op == QLatin1String("wiring"))
        return wiring(window);
    return {};
}

std::string query(const std::string &json)
{
    const QJsonObject request = QJsonDocument::fromJson(QByteArray::fromStdString(json)).object();
    QQuickWindow *window = matome::probe::exposedWindow();
    // Before the window is exposed every question answers null.
    const QJsonValue result = window ? answer(window, request) : QJsonValue();
    return QJsonDocument(QJsonObject{{QStringLiteral("result"), result}})
            .toJson(QJsonDocument::Compact)
            .toStdString();
}

// The page reaches the module through one global, set once Qt is up.
void expose()
{
    EM_ASM({ window.matomeE2E = (request) => JSON.parse(Module.matomeE2E(JSON.stringify(request))).result; });
}

} // namespace

EMSCRIPTEN_BINDINGS(matome_e2e)
{
    emscripten::function("matomeE2E", &query);
}

Q_COREAPP_STARTUP_FUNCTION(expose)
