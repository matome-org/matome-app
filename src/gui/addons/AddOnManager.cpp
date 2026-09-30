#include "AddOnManager.h"
#include "JsonList.h"
#include <QPointer>

namespace matome {
AddOnManager::AddOnManager(AddOnBackend &backend, QObject *parent)
    : QObject(parent), m_backend(backend) {}

void AddOnManager::setContext(const QString &orgId, bool canRead, bool canInstall)
{
    if (orgId == m_orgId && canRead == m_canRead && canInstall == m_canInstall) return;
    ++m_generation;
    m_orgId = orgId;
    m_canRead = canRead;
    m_canInstall = canInstall;
    m_pending = 0;
    m_saving = m_loaded = false;
    m_catalog = m_products = m_spaces = {};
    m_entitlements = {};
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
}

bool AddOnManager::live(int generation) const
{
    return generation == m_generation && !m_orgId.isEmpty();
}

void AddOnManager::refresh()
{
    if (m_orgId.isEmpty() || busy() || !m_canRead) return;
    const int generation = ++m_generation;
    m_pending = m_canInstall ? 4 : 3;
    m_loaded = false;
    m_errorCode.clear();
    emit changed();
    const QPointer<AddOnManager> self(this);
    const auto isLive = [self, generation] { return self && self->live(generation); };
    const auto list = [this, isLive](const QString &path, const QString &key, QJsonArray &data) {
        m_backend.list(path, key, isLive,
                [this, isLive, &data](const Client::Reply &reply, const QJsonArray &rows) {
            if (!isLive()) return;
            data = reply.ok ? rows : QJsonArray();
            if (!reply.ok) m_errorCode = failCode(reply);
            --m_pending;
            m_loaded = m_pending == 0 && m_errorCode.isEmpty();
            emit changed();
        });
    };
    list(QStringLiteral("/api/v1/add-ons"), QStringLiteral("products"), m_catalog);
    list(orgPath(m_orgId, QStringLiteral("add-ons")), QStringLiteral("products"), m_products);
    if (m_canInstall) list(orgPath(m_orgId, QStringLiteral("spaces")), QStringLiteral("spaces"), m_spaces);
    m_backend.request("GET", orgPath(m_orgId, QStringLiteral("entitlements")), {}, {},
            [this, isLive](const Client::Reply &reply) {
        if (!isLive()) return;
        m_entitlements = reply.ok ? reply.json.value(QStringLiteral("entitlements")).toObject() : QJsonObject();
        if (!reply.ok) m_errorCode = failCode(reply);
        --m_pending;
        m_loaded = m_pending == 0 && m_errorCode.isEmpty();
        emit changed();
    });
}

QJsonObject AddOnManager::product(const QString &key) const
{
    for (const auto &value : m_products)
        if (value.toObject().value(QStringLiteral("key")).toString() == key) return value.toObject();
    return {};
}

QJsonArray AddOnManager::products() const
{
    QJsonArray result;
    for (const auto &value : m_catalog) {
        auto row = value.toObject();
        const auto owned = product(row.value(QStringLiteral("key")).toString());
        for (auto it = owned.begin(); it != owned.end(); ++it) row.insert(it.key(), it.value());
        const QString key = row.value(QStringLiteral("key")).toString();
        row.insert(QStringLiteral("entitled"), entitled(key));
        row.insert(QStringLiteral("catalogued"), true);
        result.append(row);
    }
    for (const auto &value : m_products) {
        auto row = value.toObject();
        bool found = false;
        for (const auto &listed : result)
            found |= listed.toObject().value(QStringLiteral("key")) == row.value(QStringLiteral("key"));
        if (!found) {
            row.insert(QStringLiteral("name"), row.value(QStringLiteral("key")));
            row.insert(QStringLiteral("skus"), QJsonArray());
            row.insert(QStringLiteral("entitled"), entitled(row.value(QStringLiteral("key")).toString()));
            row.insert(QStringLiteral("catalogued"), false);
            result.append(row);
        }
    }
    return result;
}

bool AddOnManager::catalogued(const QString &key) const
{
    for (const auto &value : m_catalog)
        if (value.toObject().value(QStringLiteral("key")).toString() == key) return true;
    return false;
}

bool AddOnManager::entitled(const QString &key) const
{
    QString capability = product(key).value(QStringLiteral("capability")).toString();
    if (capability.isEmpty()) for (const auto &value : m_catalog) {
        const auto row = value.toObject();
        if (row.value(QStringLiteral("key")).toString() == key) capability = row.value(QStringLiteral("capability")).toString();
    }
    return m_entitlements.value(QStringLiteral("capabilities")).toObject().value(capability).toBool();
}

QVariantMap AddOnManager::state(const QString &key, const QString &spaceId) const
{
    const auto row = product(key);
    const auto installation = row.value(QStringLiteral("installation")).toObject();
    const auto ids = installation.value(QStringLiteral("space_ids")).toArray();
    bool covered = ids.isEmpty();
    for (const auto &id : ids) covered |= jsonId(id) == spaceId;
    const bool allowed = entitled(key);
    return {{QStringLiteral("known"), m_loaded}, {QStringLiteral("entitled"), allowed},
            {QStringLiteral("status"), installation.value(QStringLiteral("status")).toString()},
            {QStringLiteral("covered"), covered},
            {QStringLiteral("available"), m_loaded && allowed && covered && catalogued(key)
                && installation.value(QStringLiteral("status")).toString() == QLatin1String("active")}};
}

void AddOnManager::mutate(const QByteArray &method, const QString &key, const QString &suffix,
                          const QJsonObject &body, Client::Headers headers, const QString &notice)
{
    if (!m_canInstall || busy() || !m_loaded) return;
    const int generation = m_generation;
    const QPointer<AddOnManager> self(this);
    m_saving = true;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request(method, orgPath(m_orgId, QStringLiteral("add-ons/%1/installation%2").arg(key, suffix)),
                      body, headers, [this, self, generation, notice](const Client::Reply &reply) {
        if (!self || !live(generation)) return;
        m_saving = false;
        if (!reply.ok) {
            m_errorCode = failCode(reply);
            emit changed();
            return;
        }
        m_notice = notice;
        refresh();
    });
}

void AddOnManager::install(const QString &key, const QVariantList &spaceIds, const QVariantMap &settings)
{
    if (!entitled(key) || !catalogued(key)) return;
    for (const auto &id : spaceIds) {
        bool found = false;
        for (const auto &space : m_spaces) found |= jsonId(space.toObject().value(QStringLiteral("id"))) == id.toString();
        if (!found) { m_errorCode = QStringLiteral("invalid_space"); emit changed(); return; }
    }
    auto merged = product(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("settings")).toObject();
    for (auto it = settings.begin(); it != settings.end(); ++it) merged.insert(it.key(), QJsonValue::fromVariant(it.value()));
    mutate("PUT", key, {}, {{QStringLiteral("settings"), merged},
           {QStringLiteral("space_ids"), QJsonArray::fromVariantList(spaceIds)}},
           idempotencyHeader(), QStringLiteral("installation_saved"));
}

void AddOnManager::saveSettings(const QString &key, const QVariantMap &settings)
{
    if (settings.isEmpty() || product(key).value(QStringLiteral("installation")).toObject().isEmpty()) return;
    mutate("PATCH", key, {}, {{QStringLiteral("settings"), QJsonObject::fromVariantMap(settings)}},
           idempotencyHeader(), QStringLiteral("settings_saved"));
}

void AddOnManager::pause(const QString &key)
{
    if (product(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString()
            != QLatin1String("active")) return;
    mutate("POST", key, QStringLiteral("/pause"), {}, idempotencyHeader(), QStringLiteral("installation_paused"));
}

void AddOnManager::uninstallControlledDocs(const QString &reason)
{
    if (!validReason(reason)) {
        m_errorCode = QStringLiteral("reason_required"); emit changed(); return;
    }
    const auto installation = product(QStringLiteral("controlled_docs")).value(QStringLiteral("installation")).toObject();
    if (installation.isEmpty()) return;
    auto headers = idempotentMatchHeader(installation.value(QStringLiteral("revision")).toInt());
    // The DELETE contract accepts a removal reason in its query parameters.
    const QString suffix = QStringLiteral("?reason=") + QString::fromLatin1(QUrl::toPercentEncoding(reason.trimmed()));
    mutate("DELETE", QStringLiteral("controlled_docs"), suffix, {}, headers, QStringLiteral("installation_removed"));
}
}
