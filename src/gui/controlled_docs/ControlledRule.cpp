#include "ControlledRule.h"

#include "JsonList.h"
#include "Session.h"

#include <QUrl>
#include <QUuid>

namespace matome {

ControlledRule::ControlledRule(Session &session)
    : QObject(&session), m_session(session), m_addOns(*session.addOns()), m_backend(m_addOns.backend())
{
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    connect(&m_addOns, &AddOnManager::changed, this, &ControlledRule::changed);
}

bool ControlledRule::installed() const
{
    return active() && !m_addOns.state(QStringLiteral("controlled_docs"), m_spaceId)
                                .value(QStringLiteral("status")).toString().isEmpty();
}

bool ControlledRule::canGrantSelf() const
{
    return m_ruleError == QLatin1String("forbidden") && !m_membershipId.isEmpty()
            && m_session.organizations()->canAdminister(m_orgId);
}

QJsonArray ControlledRule::actions(Profile profile)
{
    QJsonArray list{QStringLiteral("document.review_read")};
    if (profile == Profile::Manager) {
        list.append(QStringLiteral("document.controlled_docs_manage"));
        list.append(QStringLiteral("space.controlled_docs_manage"));
    } else {
        list.append(QStringLiteral("document.approve"));
    }
    return list;
}

// The organization role with exactly the profile's actions.
QString ControlledRule::roleId(Profile profile) const
{
    const QJsonArray expected = actions(profile);
    for (const auto &value : m_roles) {
        const auto role = value.toObject();
        const auto held = role.value(QStringLiteral("actions")).toArray();
        bool same = held.size() == expected.size();
        for (const auto &action : expected) same = same && held.contains(action);
        if (same) return jsonId(role.value(QStringLiteral("id")));
    }
    return {};
}

bool ControlledRule::rolesMissing() const
{
    return !m_roles.isEmpty() && (roleId(Profile::Reviewer).isEmpty() || roleId(Profile::Manager).isEmpty());
}

void ControlledRule::open(const QString &spaceId)
{
    if (spaceId == m_spaceId || m_session.currentOrgId().isEmpty())
        return;
    close();
    m_orgId = m_session.currentOrgId();
    m_spaceId = spaceId;
    refresh();
}

void ControlledRule::close()
{
    if (!active())
        return;
    ++m_generation;
    m_pending = 0;
    m_ruleRead = false;
    m_orgId.clear(); m_spaceId.clear(); m_membershipId.clear();
    m_ruleError.clear(); m_errorCode.clear(); m_notice.clear();
    m_rule = {};
    m_roles = {};
    emit changed();
}

void ControlledRule::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_pending = 3;
    m_ruleRead = false;
    m_ruleError.clear();
    emit changed();
    const auto isLive = [this, generation] { return live(generation); };
    m_backend.request("GET", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule")), {}, {},
                      [this, isLive](const Client::Reply &reply) {
        if (!isLive()) return;
        m_rule = reply.ok ? reply.json.value(QStringLiteral("data")).toObject() : QJsonObject();
        m_ruleRead = reply.ok || reply.status == 404;
        if (!m_ruleRead) m_ruleError = failCode(reply);
        --m_pending;
        emit changed();
    });
    m_backend.list(orgPath(m_orgId, QStringLiteral("roles")), QStringLiteral("roles"), isLive,
                   [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_roles = reply.ok ? rows : QJsonArray();
        --m_pending;
        emit changed();
    });
    m_backend.list(orgPath(m_orgId, QStringLiteral("members")), QStringLiteral("members"), isLive,
                   [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_membershipId.clear();
        for (const auto &value : rows) {
            const auto member = value.toObject();
            if (reply.ok && member.value(QStringLiteral("email")).toString().compare(m_session.email(), Qt::CaseInsensitive) == 0)
                m_membershipId = jsonId(member.value(QStringLiteral("id")));
        }
        --m_pending;
        emit changed();
    });
}

void ControlledRule::save(bool active, bool requireVersionReferences)
{
    if (busy() || !readable())
        return;
    change("PUT", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule")),
           {{QStringLiteral("active"), active}, {QStringLiteral("require_version_references"), requireVersionReferences}},
           idempotentMatchHeader(m_rule.value(QStringLiteral("revision")).toInt()), QStringLiteral("rule_saved"));
}

void ControlledRule::remove(const QString &reason)
{
    if (busy() || !readable() || m_rule.isEmpty())
        return;
    if (!validReason(reason)) {
        m_errorCode = QStringLiteral("reason_required");
        emit changed();
        return;
    }
    change("DELETE", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule?reason="))
                   + QString::fromLatin1(QUrl::toPercentEncoding(reason.trimmed())),
           {}, idempotentMatchHeader(m_rule.value(QStringLiteral("revision")).toInt()), QStringLiteral("rule_removed"));
}

void ControlledRule::createRole(Profile profile, std::function<void(const QString &)> done)
{
    const int generation = m_generation;
    m_backend.request("POST", orgPath(m_orgId, QStringLiteral("roles")),
                      {{QStringLiteral("key"), QStringLiteral("controlled-docs-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))},
                       {QStringLiteral("name"), profile == Profile::Manager ? QStringLiteral("Document control managers")
                                                                             : QStringLiteral("Document reviewers")},
                       {QStringLiteral("actions"), actions(profile)}},
                      idempotencyHeader(), [this, generation, done](const Client::Reply &reply) {
        if (!live(generation)) return;
        const QString id = jsonId(reply.json.value(QStringLiteral("role")).toObject().value(QStringLiteral("id")));
        if (!reply.ok || id.isEmpty()) {
            finish(reply.ok ? Client::Reply{false, 0, QStringLiteral("invalid_request"), {}, {}} : reply, {});
            return;
        }
        m_roles.append(reply.json.value(QStringLiteral("role")));
        done(id);
    });
}

void ControlledRule::addRoles()
{
    if (busy() || !rolesMissing())
        return;
    ++m_pending;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    const auto manager = [this] {
        if (!roleId(Profile::Manager).isEmpty()) { finish({true, 200, {}, {}, {}}, QStringLiteral("roles_added")); return; }
        createRole(Profile::Manager, [this](const QString &) { finish({true, 200, {}, {}, {}}, QStringLiteral("roles_added")); });
    };
    if (roleId(Profile::Reviewer).isEmpty())
        createRole(Profile::Reviewer, [manager](const QString &) { manager(); });
    else
        manager();
}

void ControlledRule::grantSelf()
{
    if (busy() || !canGrantSelf())
        return;
    ++m_pending;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    const int generation = m_generation;
    const auto grant = [this, generation](const QString &role) {
        m_backend.request("POST", contentPath(m_orgId, m_spaceId, QStringLiteral("grants")),
                          {{QStringLiteral("organization_membership_id"), m_membershipId}, {QStringLiteral("role_id"), role}},
                          idempotencyHeader(), [this, generation](const Client::Reply &reply) {
            if (live(generation)) finish(reply, QStringLiteral("access_saved"));
        });
    };
    const QString role = roleId(Profile::Manager);
    if (role.isEmpty()) createRole(Profile::Manager, grant);
    else grant(role);
}

void ControlledRule::change(const QByteArray &method, const QString &path, const QJsonObject &body,
                            const Client::Headers &headers, const QString &notice)
{
    const int generation = m_generation;
    ++m_pending;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request(method, path, body, headers, [this, generation, notice](const Client::Reply &reply) {
        if (live(generation)) finish(reply, notice);
    });
}

void ControlledRule::finish(const Client::Reply &reply, const QString &notice)
{
    --m_pending;
    if (!reply.ok) {
        m_errorCode = failCode(reply);
        emit changed();
        return;
    }
    m_notice = notice;
    emit accessChanged();
    refresh();
}
}
