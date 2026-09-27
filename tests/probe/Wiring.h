#pragma once

// What main.cpp wires before the window shows, and the walks over the
// window, shared by the desktop smoke probe, the browser suite's probe, and
// the studio tests.

#include <QCoreApplication>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonArray>
#include <QJsonObject>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>

namespace matome::probe {

// The bundled font families, the window icon, and the app and org names.
inline QJsonObject wiring()
{
    QJsonArray families;
    for (int id = 0; id < 64; ++id) {
        for (const QString &family : QFontDatabase::applicationFontFamilies(id)) {
            if (!families.contains(family))
                families.append(family);
        }
    }
    const QIcon icon = QGuiApplication::windowIcon();
    return {{QStringLiteral("fonts"), families},
            {QStringLiteral("icon"), !icon.isNull() && !icon.pixmap(64, 64).isNull()},
            {QStringLiteral("application"), QCoreApplication::applicationName()},
            {QStringLiteral("organization"), QCoreApplication::organizationName()}};
}

// The first exposed Quick window: the studio once it shows.
inline QQuickWindow *exposedWindow()
{
    for (QWindow *window : QGuiApplication::topLevelWindows()) {
        if (auto *quick = qobject_cast<QQuickWindow *>(window); quick && quick->isExposed())
            return quick;
    }
    return nullptr;
}

// `root` and everything under it, breadth first.
inline QList<QQuickItem *> descendants(QQuickItem *root)
{
    QList<QQuickItem *> all{root};
    for (qsizetype i = 0; i < all.size(); ++i)
        all.append(all.at(i)->childItems());
    return all;
}

// The `matome` QML singleton `name` (Session, Theme) behind `window`.
inline QObject *singleton(QQuickWindow *window, const QString &name)
{
    QQmlEngine *engine = qmlEngine(window);
    return engine ? engine->singletonInstance<QObject *>(QStringLiteral("matome"), name) : nullptr;
}

} // namespace matome::probe
