#include "PrincipalAccess.h"

#include "JsonList.h"
#include "Session.h"

namespace matome {

PrincipalAccess::PrincipalAccess(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_directory(directory), m_places(places), m_backend(backend)
{
    connect(this, &PrincipalAccess::changed, this, [this] {
        if (changedSince(m_listed, QJsonArray{QJsonArray::fromVariantList(rows()), QJsonArray::fromVariantList(roles()),
                                              QJsonArray::fromStringList(roleIds())}))
            emit listsChanged();
    });
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    connect(&directory, &AccessDirectory::listsChanged, this, &PrincipalAccess::changed);
    // Roles given or taken and group changes reach what the principal holds.
    connect(&directory, &AccessDirectory::saved, this, &PrincipalAccess::refresh);
    connect(&places, &PlaceNames::changed, this, &PrincipalAccess::changed);
}

QVariantMap PrincipalAccess::place(const QJsonObject &resource) const
{
    const QString kind = resource.value(QStringLiteral("kind")).toString();
    const QString id = jsonId(resource.value(QStringLiteral("id")));
    const QString spaceId = jsonId(resource.value(QStringLiteral("space_id")));
    return {{QStringLiteral("placeKind"), kind},
            {QStringLiteral("placeId"), id},
            {QStringLiteral("spaceId"), spaceId},
            {QStringLiteral("name"), m_places.name(kind, spaceId, id)},
            {QStringLiteral("spaceName"), spaceId.isEmpty() ? QString() : m_places.name(QStringLiteral("space"), spaceId, spaceId)}};
}

QVariantList PrincipalAccess::rows() const
{
    QVariantList list;
    const QString principalKind = m_principal.section(QLatin1Char(':'), 0, 0);
    for (const auto &value : m_roles) {
        const auto row = value.toObject();
        const auto role = row.value(QStringLiteral("role")).toObject();
        const QString id = jsonId(row.value(QStringLiteral("id")));
        list.append(QVariantMap{{QStringLiteral("key"), QStringLiteral("assignment:") + id},
                                {QStringLiteral("kind"), QStringLiteral("assignment")},
                                {QStringLiteral("id"), id},
                                {QStringLiteral("roleId"), jsonId(row.value(QStringLiteral("role_id")))},
                                {QStringLiteral("roleKey"), role.value(QStringLiteral("key")).toString()},
                                {QStringLiteral("roleName"), role.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("origin"), role.value(QStringLiteral("origin")).toString()},
                                {QStringLiteral("placeKind"), QStringLiteral("organization")},
                                {QStringLiteral("idle"), m_directory.placeOnly(jsonId(row.value(QStringLiteral("role_id"))))},
                                {QStringLiteral("via"), m_principal},
                                {QStringLiteral("viaKind"), principalKind},
                                {QStringLiteral("viaName"), m_directory.principalName(m_principal)},
                                {QStringLiteral("direct"), true}});
    }
    for (const auto &value : m_access) {
        const auto grant = value.toObject();
        const auto viaObject = grant.value(QStringLiteral("via")).toObject();
        const QString viaKind = viaObject.value(QStringLiteral("kind")).toString();
        const QString via = viaKind + QLatin1Char(':') + jsonId(viaObject.value(QStringLiteral("id")));
        const QString id = jsonId(grant.value(QStringLiteral("id")));
        const QString roleId = jsonId(grant.value(QStringLiteral("role_id")));
        const QJsonObject role = m_directory.role(roleId);
        QVariantMap row = place(grant.value(QStringLiteral("resource")).toObject());
        row.insert(QStringLiteral("key"), QStringLiteral("grant:") + id);
        row.insert(QStringLiteral("kind"), QStringLiteral("grant"));
        row.insert(QStringLiteral("id"), id);
        row.insert(QStringLiteral("roleId"), roleId);
        row.insert(QStringLiteral("roleKey"), role.isEmpty() ? grant.value(QStringLiteral("role_key")).toString()
                                                              : role.value(QStringLiteral("key")).toString());
        row.insert(QStringLiteral("roleName"), role.value(QStringLiteral("name")).toString());
        row.insert(QStringLiteral("origin"), role.value(QStringLiteral("origin")).toString());
        row.insert(QStringLiteral("via"), via);
        row.insert(QStringLiteral("viaKind"), viaKind);
        row.insert(QStringLiteral("viaName"), m_directory.principalName(via));
        row.insert(QStringLiteral("viaKey"), viaKind == QLatin1String("role")
                   ? m_directory.role(via.section(QLatin1Char(':'), 1)).value(QStringLiteral("key")).toString() : QString());
        row.insert(QStringLiteral("direct"), via == m_principal);
        list.append(row);
    }
    for (const auto &value : m_open) {
        const auto resource = value.toObject();
        QVariantMap row = place(resource);
        row.insert(QStringLiteral("key"), QStringLiteral("open:%1:%2").arg(row.value(QStringLiteral("placeKind")).toString(),
                                                                           row.value(QStringLiteral("placeId")).toString()));
        row.insert(QStringLiteral("kind"), QStringLiteral("open"));
        row.insert(QStringLiteral("direct"), false);
        list.append(row);
    }
    return list;
}

QVariantList PrincipalAccess::roles() const
{
    QVariantList list;
    for (const auto &value : m_roles) {
        const auto row = value.toObject();
        const auto role = row.value(QStringLiteral("role")).toObject();
        list.append(QVariantMap{{QStringLiteral("id"), jsonId(row.value(QStringLiteral("id")))},
                                {QStringLiteral("roleId"), jsonId(row.value(QStringLiteral("role_id")))},
                                {QStringLiteral("roleKey"), role.value(QStringLiteral("key")).toString()},
                                {QStringLiteral("roleName"), role.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("origin"), role.value(QStringLiteral("origin")).toString()},
                                {QStringLiteral("actions"), role.value(QStringLiteral("actions")).toArray().toVariantList()}});
    }
    return list;
}

QStringList PrincipalAccess::roleIds() const
{
    QStringList ids;
    for (const auto &value : m_roles)
        ids.append(jsonId(value.toObject().value(QStringLiteral("role_id"))));
    return ids;
}

void PrincipalAccess::open(const QString &principal)
{
    const QString kind = principal.section(QLatin1Char(':'), 0, 0);
    if ((kind != QLatin1String("user") && kind != QLatin1String("group")) || principal.section(QLatin1Char(':'), 1).isEmpty()
        || m_session.currentOrgId().isEmpty())
        return;
    if (principal != m_principal) close();
    m_orgId = m_session.currentOrgId();
    m_principal = principal;
    m_notice.clear();
    refresh();
}

void PrincipalAccess::close()
{
    if (!active())
        return;
    ++m_generation;
    ++m_opened;
    m_reading = m_writing = 0;
    m_orgId.clear();
    m_principal.clear();
    m_errorCode.clear();
    m_notice.clear();
    m_access = m_roles = m_open = {};
    emit changed();
}

void PrincipalAccess::finished(const Client::Reply &reply)
{
    if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
    --m_reading;
    emit changed();
}

void PrincipalAccess::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_reading = 2;
    m_errorCode.clear();
    emit changed();
    const auto isLive = [this, generation] { return live(generation); };
    const bool user = m_principal.startsWith(QLatin1String("user:"));
    const QString id = m_principal.section(QLatin1Char(':'), 1);
    m_backend.list(orgPath(m_orgId, (user ? QStringLiteral("members/%1/access") : QStringLiteral("groups/%1/access")).arg(id)),
                   QStringLiteral("access"), isLive, [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_access = rows;
        m_open = reply.json.value(QStringLiteral("open")).toArray();
        const auto want = [this](const QJsonObject &resource) {
            m_places.want(resource.value(QStringLiteral("kind")).toString(), jsonId(resource.value(QStringLiteral("space_id"))),
                          jsonId(resource.value(QStringLiteral("id"))));
        };
        for (const auto &value : rows) want(value.toObject().value(QStringLiteral("resource")).toObject());
        for (const auto &value : std::as_const(m_open)) want(value.toObject());
        finished(reply);
    });
    m_backend.list(orgPath(m_orgId, QStringLiteral("principal-roles?%1=%2")
                                            .arg(user ? QStringLiteral("organization_membership_id") : QStringLiteral("group_id"), id)),
                   QStringLiteral("principal_roles"), isLive, [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_roles = rows;
        finished(reply);
    });
}

void PrincipalAccess::setRoles(const QStringList &roleIds)
{
    if (!active() || busy())
        return;
    QList<AddOnBackend::Step> grants, revokes;
    const QStringList held = this->roleIds();
    for (const QString &role : roleIds) {
        if (held.contains(role) || m_directory.role(role).isEmpty())
            continue;
        QJsonObject body = AccessDirectory::principalField(m_principal);
        body.insert(QStringLiteral("role_id"), role);
        grants.append({"POST", orgPath(m_orgId, QStringLiteral("principal-roles")), body});
    }
    for (const auto &value : std::as_const(m_roles)) {
        const auto row = value.toObject();
        if (!roleIds.contains(jsonId(row.value(QStringLiteral("role_id")))))
            revokes.append({"DELETE", orgPath(m_orgId, QStringLiteral("principal-roles/%1").arg(jsonId(row.value(QStringLiteral("id"))))), {}});
    }
    // The missing roles land first, so a member never passes through holding none.
    write(grants, revokes, QStringLiteral("roles_saved"));
}

void PrincipalAccess::grant(const QString &kind, const QString &spaceId, const QString &id, const QStringList &roleIds)
{
    if (!active() || busy() || id.isEmpty())
        return;
    QStringList held;
    for (const auto &value : std::as_const(m_access)) {
        const auto row = value.toObject();
        const auto resource = row.value(QStringLiteral("resource")).toObject();
        const auto via = row.value(QStringLiteral("via")).toObject();
        if (resource.value(QStringLiteral("kind")).toString() == kind && jsonId(resource.value(QStringLiteral("id"))) == id
            && via.value(QStringLiteral("kind")).toString() + QLatin1Char(':') + jsonId(via.value(QStringLiteral("id"))) == m_principal)
            held.append(jsonId(row.value(QStringLiteral("role_id"))));
    }
    QList<AddOnBackend::Step> steps;
    for (const QString &role : roleIds)
        if (!held.contains(role) && !m_directory.role(role).isEmpty())
            steps.append(AccessDirectory::grantStep(m_orgId, kind, spaceId, id, m_principal, role));
    write(steps, {}, QStringLiteral("access_added"));
}

void PrincipalAccess::remove(const QStringList &keys)
{
    if (!active() || busy())
        return;
    QList<AddOnBackend::Step> steps;
    for (const QVariant &value : rows()) {
        const QVariantMap row = value.toMap();
        if (!keys.contains(row.value(QStringLiteral("key")).toString()) || !row.value(QStringLiteral("direct")).toBool())
            continue;
        const QString id = row.value(QStringLiteral("id")).toString();
        steps.append({"DELETE", row.value(QStringLiteral("kind")) == QLatin1String("assignment")
                         ? orgPath(m_orgId, QStringLiteral("principal-roles/%1").arg(id))
                         : AccessDirectory::resourcePath(m_orgId, row.value(QStringLiteral("placeKind")).toString(),
                                                         row.value(QStringLiteral("spaceId")).toString(),
                                                         row.value(QStringLiteral("placeId")).toString(), QStringLiteral("grants/%1").arg(id)),
                      {}});
    }
    write(steps, {}, QStringLiteral("access_removed"));
}

void PrincipalAccess::write(const QList<AddOnBackend::Step> &first, const QList<AddOnBackend::Step> &then, const QString &notice)
{
    if (first.isEmpty() && then.isEmpty())
        return;
    const int opened = m_opened;
    m_writing = 1;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    const auto open = [this, opened] { return stillOpen(opened); };
    // Whatever landed shows; a refusal says why and names no notice.
    const auto finish = [this, notice](const QString &failure, bool landed) {
        m_writing = 0;
        refresh();
        m_errorCode = failure;
        m_notice = failure.isEmpty() ? notice : QString();
        emit changed();
        if (landed) emit rolesChanged();
    };
    const auto next = [this, open, finish, then](const QString &failure, bool landed) {
        if (!failure.isEmpty() || then.isEmpty())
            finish(failure, landed);
        else
            m_backend.requestAll(then, open, [finish, landed](const QString &failed, bool more) { finish(failed, landed || more); });
    };
    if (first.isEmpty()) next({}, false);
    else m_backend.requestAll(first, open, next);
}
}
