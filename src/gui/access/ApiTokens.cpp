#include "ApiTokens.h"

#include "JsonList.h"
#include "Session.h"

#include <QDateTime>
#include <QJsonObject>
#include <QPointer>

namespace matome {

ApiTokens::ApiTokens(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, [this] {
        if (m_active && !m_session.signedIn()) close();
    });
}

QVariantList ApiTokens::tokens() const
{
    OrgModel *orgs = m_session.organizations();
    QVariantList list;
    for (const auto &value : m_tokens) {
        const auto token = value.toObject();
        QVariantList scopes;
        for (const auto &scopeValue : token.value(QStringLiteral("scopes")).toArray()) {
            const auto scope = scopeValue.toObject();
            const QString orgId = jsonId(scope.value(QStringLiteral("organization_id")));
            scopes.append(QVariantMap{{QStringLiteral("organizationId"), orgId},
                                      {QStringLiteral("organizationName"), orgs->nameOf(orgId)},
                                      {QStringLiteral("action"), scope.value(QStringLiteral("action")).toString()},
                                      {QStringLiteral("spaceId"), jsonId(scope.value(QStringLiteral("space_id")))},
                                      {QStringLiteral("allSpaces"), scope.value(QStringLiteral("all_spaces")).toBool()}});
        }
        list.append(QVariantMap{{QStringLiteral("id"), jsonId(token.value(QStringLiteral("id")))},
                                {QStringLiteral("name"), token.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("prefix"), token.value(QStringLiteral("token_prefix")).toString()},
                                {QStringLiteral("expiresAt"), token.value(QStringLiteral("expires_at")).toString()},
                                {QStringLiteral("lastUsedAt"), token.value(QStringLiteral("last_used_at")).toString()},
                                {QStringLiteral("scopes"), scopes}});
    }
    return list;
}

QVariantList ApiTokens::organizations() const
{
    OrgModel *orgs = m_session.organizations();
    QVariantList list;
    for (int row = 0; row < orgs->rowCount(); ++row) {
        const QModelIndex index = orgs->index(row);
        list.append(QVariantMap{{QStringLiteral("value"), orgs->data(index, OrgModel::OrgIdRole)},
                                {QStringLiteral("label"), orgs->data(index, OrgModel::NameRole)}});
    }
    return list;
}

QVariantList ApiTokens::spaces() const
{
    QVariantList list;
    for (const auto &value : m_spaces) {
        const auto space = value.toObject();
        list.append(QVariantMap{{QStringLiteral("value"), jsonId(space.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), space.value(QStringLiteral("name")).toString()}});
    }
    return list;
}

QVariantList ApiTokens::actions() const
{
    // Core judges `allowed` only for a named target; every space is checked when the token is used.
    const bool organization = m_target.isEmpty(), everySpace = m_target == QLatin1String("*");
    QVariantList list;
    for (const auto &value : m_catalog) {
        const auto action = value.toObject();
        const QString scope = action.value(QStringLiteral("token_scope")).toString();
        if (action.value(QStringLiteral("system_only")).toBool()
            || scope == (organization ? QLatin1String("space") : QLatin1String("organization"))
            || (!everySpace && !action.value(QStringLiteral("allowed")).toBool()))
            continue;
        list.append(QVariantMap{{QStringLiteral("key"), action.value(QStringLiteral("key")).toString()},
                                {QStringLiteral("area"), AccessDirectory::actionArea(action)}});
    }
    return list;
}

bool ApiTokens::needsPassword() const
{
    return m_stale || !m_session.recentlySignedIn();
}

void ApiTokens::open()
{
    m_active = true;
    m_errorCode.clear();
    m_notice.clear();
    refresh();
}

void ApiTokens::close()
{
    ++m_generation;
    m_active = m_stale = m_spacesLoading = m_catalogLoading = false;
    m_pending = 0;
    m_tokens = m_spaces = m_catalog = {};
    m_orgId.clear();
    m_target.clear();
    m_secret.clear();
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
}

void ApiTokens::refresh()
{
    if (!m_active) return;
    const int generation = m_generation;
    ++m_pending;
    emit changed();
    m_backend.request("GET", QStringLiteral("/api/auth/tokens"), {}, {},
                      [this, self = QPointer<ApiTokens>(this), generation](const Client::Reply &reply) {
        if (!self || !live(generation)) return;
        --m_pending;
        if (reply.ok) m_tokens = reply.json.value(QStringLiteral("tokens")).toArray();
        else m_errorCode = failCode(reply);
        emit changed();
    });
}

void ApiTokens::choose(const QString &orgId, const QString &target)
{
    if (!m_active || orgId.isEmpty()) return;
    const int generation = m_generation;
    const QPointer<ApiTokens> self(this);
    if (orgId != m_orgId) {
        m_orgId = orgId;
        m_spaces = {};
        m_spacesLoading = true;
        const auto current = [this, self, generation, orgId] { return self && live(generation) && orgId == m_orgId; };
        m_backend.list(orgPath(orgId, QStringLiteral("spaces")), QStringLiteral("spaces"), current,
                       [this, current](const Client::Reply &reply, const QJsonArray &rows) {
            if (!current()) return;
            m_spacesLoading = false;
            m_spaces = reply.ok ? rows : QJsonArray();
            if (!reply.ok) m_errorCode = failCode(reply);
            emit changed();
        });
    }
    m_target = target;
    m_catalog = {};
    m_catalogLoading = true;
    emit changed();
    const int choice = ++m_choice;
    const bool space = !target.isEmpty() && target != QLatin1String("*");
    Permissions::readCatalog(m_backend, orgId, space ? target : QString(),
                                 [this, self, generation, choice] { return self && live(generation) && choice == m_choice; },
                                 [this](const Client::Reply &reply, const QJsonArray &actions) {
        m_catalogLoading = false;
        m_catalog = reply.ok ? actions : QJsonArray();
        if (!reply.ok) m_errorCode = failCode(reply);
        emit changed();
    });
}

void ApiTokens::create(const QString &name, int days, const QVariantList &scopes, const QString &password)
{
    if (!m_active || busy() || name.trimmed().isEmpty() || scopes.isEmpty()) return;
    QJsonArray body;
    for (const auto &scope : scopes) body.append(QJsonObject::fromVariantMap(scope.toMap()));
    m_errorCode.clear();
    m_notice.clear();
    if (!needsPassword()) {
        post(name.trimmed(), days, body);
        return;
    }
    if (password.isEmpty()) {
        m_stale = true;
        m_errorCode = QStringLiteral("password_required");
        emit changed();
        return;
    }
    const int generation = m_generation;
    ++m_pending;
    emit changed();
    m_session.reauthenticate(password, [this, self = QPointer<ApiTokens>(this), generation, name, days, body](const QString &code) {
        if (!self || !live(generation)) return;
        --m_pending;
        if (!code.isEmpty()) {
            m_errorCode = code;
            emit changed();
            return;
        }
        m_stale = false;
        post(name.trimmed(), days, body);
    });
}

void ApiTokens::post(const QString &name, int days, const QJsonArray &scopes)
{
    const int generation = m_generation;
    ++m_pending;
    emit changed();
    const QJsonObject body{{QStringLiteral("name"), name},
                           {QStringLiteral("expires_at"), QDateTime::currentDateTimeUtc().addDays(days).toString(Qt::ISODate)},
                           {QStringLiteral("scopes"), scopes}};
    m_backend.request("POST", QStringLiteral("/api/auth/tokens"), body, {},
                      [this, self = QPointer<ApiTokens>(this), generation](const Client::Reply &reply) {
        if (!self || !live(generation)) return;
        --m_pending;
        finish(reply);
    });
}

void ApiTokens::finish(const Client::Reply &reply)
{
    if (!reply.ok) {
        // Core refuses token creation from a session signed in over 15 minutes ago.
        m_stale = reply.status == 403;
        m_errorCode = m_stale ? QStringLiteral("password_required") : failCode(reply);
        emit changed();
        return;
    }
    m_secret = reply.json.value(QStringLiteral("token")).toString();
    m_notice = QStringLiteral("token_created");
    refresh();
}

void ApiTokens::revoke(const QString &id)
{
    if (!m_active || busy() || id.isEmpty()) return;
    const int generation = m_generation;
    ++m_pending;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request("DELETE", QStringLiteral("/api/auth/tokens/%1").arg(id), {}, {},
                      [this, self = QPointer<ApiTokens>(this), generation](const Client::Reply &reply) {
        if (!self || !live(generation)) return;
        --m_pending;
        if (!reply.ok) {
            m_errorCode = failCode(reply);
            emit changed();
            return;
        }
        m_notice = QStringLiteral("token_revoked");
        refresh();
    });
}

void ApiTokens::forgetSecret()
{
    m_secret.clear();
    emit changed();
}
}
