#include "AddOnActivations.h"

#include "JsonList.h"
#include "Session.h"

namespace matome {

AddOnActivations::AddOnActivations(Session &session, AddOnManager &addOns)
    : QObject(&session), m_session(session), m_addOns(addOns), m_backend(addOns.backend())
{
    connect(this, &AddOnActivations::changed, this, [this] {
        if (changedSince(m_listed, QJsonArray{QJsonArray::fromVariantList(rows())}))
            emit listsChanged();
    });
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    connect(&addOns, &AddOnManager::changed, this, [this] {
        if (active() && !m_addOns.busy() && stamp() != m_stamp) refresh();
    });
}

QString AddOnActivations::stamp() const
{
    QStringList parts;
    for (const auto &space : m_addOns.spaces()) parts.append(space.toMap().value(QStringLiteral("id")).toString());
    for (const auto &value : m_addOns.products()) {
        const auto product = value.toObject();
        parts.append(product.value(QStringLiteral("key")).toString() + QLatin1Char('=')
                     + product.value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString());
    }
    return parts.join(QLatin1Char(','));
}

QVariantList AddOnActivations::rows() const
{
    QVariantList list;
    for (const auto &value : m_addOns.spaces()) {
        const auto space = value.toMap();
        const QString id = space.value(QStringLiteral("id")).toString();
        for (const auto &listed : m_spaceRows.value(id)) {
            QVariantMap row = listed.toObject().toVariantMap();
            row.insert(QStringLiteral("space_id"), id);
            row.insert(QStringLiteral("space_name"), space.value(QStringLiteral("name")).toString());
            list.append(row);
        }
    }
    return list;
}

QJsonObject AddOnActivations::row(const QString &spaceId, const QString &key) const
{
    for (const auto &value : m_spaceRows.value(spaceId))
        if (value.toObject().value(QStringLiteral("product_key")).toString() == key) return value.toObject();
    return {};
}

void AddOnActivations::open()
{
    if (m_session.currentOrgId().isEmpty())
        return;
    if (m_orgId != m_session.currentOrgId()) {
        close();
        m_orgId = m_session.currentOrgId();
    }
    refresh();
}

void AddOnActivations::close()
{
    if (!active())
        return;
    ++m_generation;
    m_reading = m_writing = 0;
    m_orgId.clear(); m_stamp.clear(); m_readError.clear(); m_errorCode.clear(); m_notice.clear();
    m_spaceRows.clear();
    emit changed();
}

// Each space answers on its own; a space whose read is refused lists nothing.
void AddOnActivations::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_stamp = stamp();
    m_readError.clear();
    m_writing = 0;
    QHash<QString, QJsonArray> kept;
    const QVariantList spaces = m_addOns.spaces();
    for (const auto &value : spaces) {
        const QString id = value.toMap().value(QStringLiteral("id")).toString();
        if (m_spaceRows.contains(id)) kept.insert(id, m_spaceRows.value(id));
    }
    m_spaceRows = kept;
    m_reading = int(spaces.size());
    emit changed();
    for (const auto &value : spaces) {
        const QString id = value.toMap().value(QStringLiteral("id")).toString();
        m_backend.request("GET", contentPath(m_orgId, id, QStringLiteral("add-ons")), {}, {},
                          [this, generation, id](const Client::Reply &reply) {
            if (!live(generation)) return;
            --m_reading;
            if (reply.ok) m_spaceRows.insert(id, reply.json.value(QStringLiteral("add_ons")).toArray());
            else {
                m_spaceRows.remove(id);
                if (m_readError.isEmpty()) m_readError = failCode(reply);
            }
            emit changed();
        });
    }
}

void AddOnActivations::read(AddOnBackend &backend, const QString &orgId, const QString &spaceId, const QString &product,
                            AddOnBackend::Live live, std::function<void(const QJsonObject &activation, const QString &error)> done)
{
    backend.request("GET", contentPath(orgId, spaceId, QStringLiteral("add-ons")), {}, {},
                    [live, done, product](const Client::Reply &reply) {
        if (!live()) return;
        if (!reply.ok) {
            done({}, failCode(reply));
            return;
        }
        for (const auto &value : reply.json.value(QStringLiteral("add_ons")).toArray())
            if (value.toObject().value(QStringLiteral("product_key")).toString() == product) {
                done(value.toObject(), {});
                return;
            }
        done({}, {});
    });
}

void AddOnActivations::activate(const QString &spaceId, const QString &key, const QVariantMap &settings)
{
    const auto current = row(spaceId, key);
    if (busy() || current.isEmpty())
        return;
    QJsonObject body;
    if (!settings.isEmpty()) body.insert(QStringLiteral("settings"), QJsonObject::fromVariantMap(settings));
    const bool on = current.value(QStringLiteral("status")).toString() == QLatin1String("active");
    change("PUT", spaceId, key, body, on ? QStringLiteral("activation_saved") : QStringLiteral("activated"));
}

void AddOnActivations::deactivate(const QString &spaceId, const QString &key)
{
    if (busy() || row(spaceId, key).value(QStringLiteral("status")).toString() != QLatin1String("active"))
        return;
    change("DELETE", spaceId, key, {}, QStringLiteral("deactivated"));
}

// The activation's revision goes as `If-Match`; the first activation has none.
// Core answers the space's row of the add-on, which takes the place of the
// one read.
void AddOnActivations::change(const QByteArray &method, const QString &spaceId, const QString &key,
                              const QJsonObject &body, const QString &notice)
{
    const int generation = m_generation;
    const QJsonValue revision = row(spaceId, key).value(QStringLiteral("revision"));
    ++m_writing;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request(method, contentPath(m_orgId, spaceId, QStringLiteral("add-ons/%1").arg(key)), body,
                      revision.isDouble() ? idempotentMatchHeader(revision.toInt()) : idempotencyHeader(),
                      [this, generation, spaceId, key, notice](const Client::Reply &reply) {
        if (!live(generation)) return;
        --m_writing;
        if (!reply.ok) {
            m_errorCode = failCode(reply);
            emit changed();
            return;
        }
        QJsonArray listed = m_spaceRows.value(spaceId);
        for (qsizetype at = 0; at < listed.size(); ++at)
            if (listed.at(at).toObject().value(QStringLiteral("product_key")).toString() == key)
                listed.replace(at, reply.json.value(QStringLiteral("add_on")).toObject());
        m_spaceRows.insert(spaceId, listed);
        m_notice = notice;
        emit changed();
    });
}
}
