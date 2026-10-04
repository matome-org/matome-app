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
    m_saving = m_loaded = m_again = false;
    m_catalog = m_products = m_spaces = m_members = {};
    m_entitlements = {};
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
}

bool AddOnManager::live(int generation) const
{
    return generation == m_generation && !m_orgId.isEmpty();
}

// A refresh asked for while a load or a change runs comes once that ends.
void AddOnManager::refresh()
{
    if (m_orgId.isEmpty() || !m_canRead) return;
    if (busy()) {
        m_again = true;
        return;
    }
    m_again = false;
    const int generation = ++m_generation;
    m_pending = m_canInstall ? 5 : 3;
    m_loaded = false;
    m_errorCode.clear();
    emit changed();
    const QPointer<AddOnManager> self(this);
    const auto isLive = [self, generation] { return self && self->live(generation); };
    const auto list = [this, isLive](const QString &path, const QString &key, QJsonArray &data) {
        m_backend.list(path, key, isLive,
                [this, &data](const Client::Reply &reply, const QJsonArray &rows) {
            data = reply.ok ? rows : QJsonArray();
            loaded(reply);
        });
    };
    list(QStringLiteral("/api/v1/add-ons"), QStringLiteral("products"), m_catalog);
    list(orgPath(m_orgId, QStringLiteral("add-ons")), QStringLiteral("products"), m_products);
    if (m_canInstall) {
        list(orgPath(m_orgId, QStringLiteral("spaces")), QStringLiteral("spaces"), m_spaces);
        list(orgPath(m_orgId, QStringLiteral("members")), QStringLiteral("members"), m_members);
    }
    m_backend.request("GET", orgPath(m_orgId, QStringLiteral("entitlements")), {}, {},
            [this, isLive](const Client::Reply &reply) {
        if (!isLive()) return;
        m_entitlements = reply.ok ? reply.json.value(QStringLiteral("entitlements")).toObject() : QJsonObject();
        loaded(reply);
    });
}

void AddOnManager::loaded(const Client::Reply &reply)
{
    if (!reply.ok) m_errorCode = failCode(reply);
    --m_pending;
    m_loaded = m_pending == 0 && m_errorCode.isEmpty();
    emit changed();
    if (m_pending == 0 && m_again) refresh();
}

// An uninstalled installation is kept by Core for a reinstall; here it is
// no installation at all.
QJsonObject AddOnManager::product(const QString &key) const
{
    for (const auto &value : m_products) {
        auto row = value.toObject();
        if (row.value(QStringLiteral("key")).toString() != key) continue;
        if (row.value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString()
            == QLatin1String("uninstalled"))
            row.insert(QStringLiteral("installation"), QJsonValue::Null);
        return row;
    }
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
        auto row = product(value.toObject().value(QStringLiteral("key")).toString());
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

QVariantList AddOnManager::members() const
{
    QVariantList list;
    for (const auto &value : m_members) {
        const auto row = value.toObject();
        if (row.value(QStringLiteral("status")).toString() != QLatin1String("active")) continue;
        list.append(QVariantMap{{QStringLiteral("value"), jsonId(row.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), memberLabel(row)}});
    }
    return list;
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

QVariantMap AddOnManager::state(const QString &key) const
{
    const QString status = product(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString();
    const bool allowed = entitled(key);
    return {{QStringLiteral("known"), m_loaded}, {QStringLiteral("entitled"), allowed},
            {QStringLiteral("status"), status},
            {QStringLiteral("available"), m_loaded && allowed && catalogued(key) && status == QLatin1String("active")}};
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
            if (m_again) refresh();
            return;
        }
        m_notice = notice;
        refresh();
    });
}

void AddOnManager::install(const QString &key, const QVariantMap &settings)
{
    if (!entitled(key) || !catalogued(key)) return;
    auto merged = product(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("settings")).toObject();
    for (auto it = settings.begin(); it != settings.end(); ++it) merged.insert(it.key(), QJsonValue::fromVariant(it.value()));
    mutate("PUT", key, {}, {{QStringLiteral("settings"), merged}}, idempotencyHeader(), QStringLiteral("installation_saved"));
}

// Core resumes on PUT, which replaces the settings: the saved ones go back unchanged.
void AddOnManager::resume(const QString &key)
{
    const auto installation = product(key).value(QStringLiteral("installation")).toObject();
    if (installation.value(QStringLiteral("status")).toString() != QLatin1String("paused") || !entitled(key)) return;
    mutate("PUT", key, {}, {{QStringLiteral("settings"), installation.value(QStringLiteral("settings")).toObject()}},
           idempotencyHeader(), QStringLiteral("installation_resumed"));
}

void AddOnManager::saveSettings(const QString &key, const QVariantMap &settings)
{
    if (settings.isEmpty() || product(key).value(QStringLiteral("installation")).toObject().isEmpty()) return;
    mutate("PATCH", key, {}, {{QStringLiteral("settings"), QJsonObject::fromVariantMap(settings)}},
           idempotencyHeader(), QStringLiteral("settings_saved"));
}

void AddOnManager::assign(const QString &key, const QString &membershipId)
{
    const auto installation = product(key).value(QStringLiteral("installation")).toObject();
    if (installation.isEmpty() || membershipId.isEmpty()
            || jsonId(installation.value(QStringLiteral("responsible_membership_id"))) == membershipId) return;
    mutate("PATCH", key, {}, {{QStringLiteral("responsible_membership_id"), membershipId}},
           idempotencyHeader(), QStringLiteral("responsibility_saved"));
}

void AddOnManager::pause(const QString &key)
{
    if (product(key).value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")).toString()
            != QLatin1String("active")) return;
    mutate("POST", key, QStringLiteral("/pause"), {}, idempotencyHeader(), QStringLiteral("installation_paused"));
}

void AddOnManager::uninstall(const QString &key, const QString &reason)
{
    const bool controlled = key == QLatin1String("controlled_docs");
    if (controlled && !validReason(reason)) {
        m_errorCode = QStringLiteral("reason_required"); emit changed(); return;
    }
    const auto installation = product(key).value(QStringLiteral("installation")).toObject();
    if (installation.isEmpty()) return;
    mutate("DELETE", key, {}, controlled ? QJsonObject{{QStringLiteral("reason"), reason.trimmed()}} : QJsonObject(),
           idempotentMatchHeader(installation.value(QStringLiteral("revision")).toInt()), QStringLiteral("installation_removed"));
}
}
