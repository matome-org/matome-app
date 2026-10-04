#include "AccessDirectory.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonObject>
#include <QUuid>

#include <algorithm>

#include <memory>

namespace matome {

namespace {

// The built-in organization roles, in Core's order of reach.
const QStringList &organizationKeys()
{
    static const QStringList keys{QStringLiteral("owner"), QStringLiteral("admin"), QStringLiteral("member"),
                                  QStringLiteral("billing"), QStringLiteral("guest")};
    return keys;
}

// The built-in space roles, atomic then broad, in Core's order.
const QStringList &spaceKeys()
{
    static const QStringList keys{QStringLiteral("content_reader"), QStringLiteral("content_contributor"),
                                  QStringLiteral("content_purger"), QStringLiteral("content_sharer"),
                                  QStringLiteral("access_manager"), QStringLiteral("space_maintainer"),
                                  QStringLiteral("add_on_manager"), QStringLiteral("automation_manager"),
                                  QStringLiteral("content_manager"), QStringLiteral("space_operator"),
                                  QStringLiteral("space_admin")};
    return keys;
}

bool custom(const QJsonObject &role)
{
    return role.value(QStringLiteral("origin")).toString() == QLatin1String("organization");
}

QJsonObject byId(const QJsonArray &rows, const QString &id)
{
    for (const auto &row : rows)
        if (jsonId(row.toObject().value(QStringLiteral("id"))) == id) return row.toObject();
    return {};
}

} // namespace

AccessDirectory::AccessDirectory(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    // The catalog the roles are judged by is the organization's own.
    connect(session.permissions(), &Permissions::changed, this, [this] {
        if (active() && m_reading == 0) publish();
    });
}

QVariantList AccessDirectory::members() const
{
    QVariantList list;
    for (const auto &value : m_members) {
        const auto member = value.toObject();
        list.append(QVariantMap{{QStringLiteral("id"), jsonId(member.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), memberLabel(member)},
                                {QStringLiteral("email"), member.value(QStringLiteral("email")).toString()},
                                {QStringLiteral("username"), member.value(QStringLiteral("username")).toString()},
                                {QStringLiteral("name"), member.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("managed"), member.value(QStringLiteral("managed")).toBool()},
                                {QStringLiteral("roles"), member.value(QStringLiteral("roles")).toArray().toVariantList()}});
    }
    return list;
}

QVariantList AccessDirectory::groups() const
{
    QVariantList list;
    for (const auto &value : m_groups) {
        const auto group = value.toObject();
        const QString id = jsonId(group.value(QStringLiteral("id")));
        QVariantList people;
        for (const auto &row : m_groupMembers.value(id)) {
            const QString membership = jsonId(row.toObject().value(QStringLiteral("organization_membership_id")));
            people.append(QVariantMap{{QStringLiteral("id"), membership},
                                      {QStringLiteral("label"), principalName(QStringLiteral("user:") + membership)}});
        }
        list.append(QVariantMap{{QStringLiteral("id"), id},
                                {QStringLiteral("name"), group.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("revision"), group.value(QStringLiteral("revision")).toInt()},
                                {QStringLiteral("members"), people}});
    }
    return list;
}

QHash<QString, QJsonObject> AccessDirectory::described() const
{
    QHash<QString, QJsonObject> rows;
    for (const auto &value : m_session.permissions()->catalog())
        rows.insert(value.toObject().value(QStringLiteral("key")).toString(), value.toObject());
    return rows;
}

// Core reads a grant-bound action only from a grant on the place, so such a
// role without an organization action does nothing given across the
// organization.
bool AccessDirectory::placeOnly(const QJsonObject &role, const QHash<QString, QJsonObject> &described)
{
    if (role.value(QStringLiteral("origin")).toString() == QLatin1String("system")
        && organizationKeys().contains(role.value(QStringLiteral("key")).toString()))
        return false;
    bool placed = false;
    for (const auto &action : role.value(QStringLiteral("actions")).toArray()) {
        const QJsonObject descriptor = described.value(action.toString());
        if (descriptor.value(QStringLiteral("axis")).toString() == QLatin1String("organization"))
            return false;
        placed = placed || descriptor.value(QStringLiteral("resource_grant")).toBool();
    }
    return placed;
}

bool AccessDirectory::placeOnly(const QString &roleId) const
{
    return placeOnly(role(roleId), described());
}

QVariantList AccessDirectory::roles() const
{
    const QHash<QString, QJsonObject> actions = described();
    QVariantList list;
    for (const auto &value : m_roles) {
        const auto role = value.toObject();
        const bool system = role.value(QStringLiteral("origin")).toString() == QLatin1String("system");
        const QString key = role.value(QStringLiteral("key")).toString();
        bool organization = false;
        for (const auto &action : role.value(QStringLiteral("actions")).toArray())
            organization = organization || actions.value(action.toString()).value(QStringLiteral("axis")).toString() == QLatin1String("organization");
        const bool builtInOrganization = system && organizationKeys().contains(key);
        const bool placed = placeOnly(role, actions);
        list.append(QVariantMap{{QStringLiteral("id"), jsonId(role.value(QStringLiteral("id")))},
                                {QStringLiteral("key"), key},
                                {QStringLiteral("name"), role.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("actions"), role.value(QStringLiteral("actions")).toArray().toVariantList()},
                                {QStringLiteral("origin"), role.value(QStringLiteral("origin")).toString()},
                                {QStringLiteral("custom"), custom(role)},
                                {QStringLiteral("assignable"), (!system || builtInOrganization) && !placed},
                                {QStringLiteral("placeOnly"), placed},
                                {QStringLiteral("appliesTo"), (system ? builtInOrganization : organization)
                                                                  ? QStringLiteral("organization") : QStringLiteral("space")}});
    }
    return list;
}

QString AccessDirectory::actionArea(const QJsonObject &action)
{
    const QString product = action.value(QStringLiteral("product_key")).toString();
    return product.isEmpty() ? action.value(QStringLiteral("key")).toString().section(QLatin1Char('.'), 0, 0)
                             : QStringLiteral("addon.") + product;
}

QVariantList AccessDirectory::catalog() const
{
    QVariantList list;
    for (const auto &value : m_session.permissions()->catalog()) {
        const auto action = value.toObject();
        if (action.value(QStringLiteral("system_only")).toBool())
            continue;
        list.append(QVariantMap{{QStringLiteral("key"), action.value(QStringLiteral("key")).toString()},
                                {QStringLiteral("axis"), action.value(QStringLiteral("axis")).toString()},
                                {QStringLiteral("area"), actionArea(action)}});
    }
    return list;
}

QVariantList AccessDirectory::tags() const
{
    return m_tags.toVariantList();
}

QVariantList AccessDirectory::assignableRoles() const
{
    QVariantList system(organizationKeys().size()), others;
    for (const QVariant &value : roles()) {
        const QVariantMap row = value.toMap();
        if (!row.value(QStringLiteral("assignable")).toBool())
            continue;
        if (row.value(QStringLiteral("origin")).toString() != QLatin1String("system"))
            others.append(row);
        else
            system[organizationKeys().indexOf(row.value(QStringLiteral("key")).toString())] = row;
    }
    system.removeAll(QVariant());
    return system + others;
}

QVariantList AccessDirectory::grantableRoles() const
{
    QVariantList system, addOn, others;
    for (const QVariant &value : roles()) {
        const QVariantMap row = value.toMap();
        const QString origin = row.value(QStringLiteral("origin")).toString();
        if (origin == QLatin1String("system") && !row.value(QStringLiteral("assignable")).toBool()) system.append(row);
        else if (origin == QLatin1String("add_on")) addOn.append(row);
        else if (origin != QLatin1String("system")) others.append(row);
    }
    // A built-in role Core adds later goes after the ones listed.
    std::stable_sort(system.begin(), system.end(), [](const QVariant &a, const QVariant &b) {
        const auto rank = [](const QVariant &row) {
            const qsizetype at = spaceKeys().indexOf(row.toMap().value(QStringLiteral("key")).toString());
            return at < 0 ? spaceKeys().size() : at;
        };
        return rank(a) < rank(b);
    });
    return system + addOn + others;
}

QString AccessDirectory::tagName(const QString &tagId) const
{
    return byId(m_tags, tagId).value(QStringLiteral("name")).toString();
}

QString AccessDirectory::principalName(const QString &principal) const
{
    const QString kind = principal.section(QLatin1Char(':'), 0, 0);
    const QString id = principal.section(QLatin1Char(':'), 1);
    if (kind == QLatin1String("user"))
        return memberLabel(byId(m_members, id));
    if (kind == QLatin1String("group"))
        return byId(m_groups, id).value(QStringLiteral("name")).toString();
    return role(id).value(QStringLiteral("name")).toString();
}

QJsonObject AccessDirectory::role(const QString &roleId) const
{
    return byId(m_roles, roleId);
}

QVariantList AccessDirectory::principals(bool withRoles) const
{
    QVariantList list;
    for (const auto &value : m_members) {
        const auto member = value.toObject();
        list.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("user:") + jsonId(member.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), memberLabel(member)},
                                {QStringLiteral("kind"), QStringLiteral("user")}});
    }
    for (const auto &value : m_groups) {
        const auto group = value.toObject();
        list.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("group:") + jsonId(group.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), group.value(QStringLiteral("name")).toString()},
                                {QStringLiteral("kind"), QStringLiteral("group")}});
    }
    if (withRoles) {
        for (const auto &value : m_roles) {
            const auto role = value.toObject();
            list.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("role:") + jsonId(role.value(QStringLiteral("id")))},
                                    {QStringLiteral("label"), role.value(QStringLiteral("name")).toString()},
                                    {QStringLiteral("key"), role.value(QStringLiteral("key")).toString()},
                                    {QStringLiteral("kind"), QStringLiteral("role")}});
        }
    }
    return list;
}

QVariantMap AccessDirectory::holding(const QJsonArray &grants) const
{
    QVariantList held;
    QStringList ids, archived;
    for (const auto &value : grants) {
        const auto grant = value.toObject();
        const QString id = jsonId(grant.value(QStringLiteral("role_id")));
        const QJsonObject active = role(id);
        if (active.isEmpty()) {
            archived.append(grant.value(QStringLiteral("role_key")).toString());
            continue;
        }
        if (ids.contains(id))
            continue;
        ids.append(id);
        held.append(QVariantMap{{QStringLiteral("id"), id},
                                {QStringLiteral("key"), active.value(QStringLiteral("key")).toString()},
                                {QStringLiteral("name"), active.value(QStringLiteral("name")).toString()}});
    }
    return {{QStringLiteral("roles"), held}, {QStringLiteral("roleIds"), ids}, {QStringLiteral("archived"), archived}};
}

QString AccessDirectory::resourcePath(const QString &orgId, const QString &kind, const QString &spaceId, const QString &id,
                                     const QString &leaf)
{
    if (kind == QLatin1String("tag"))
        return orgPath(orgId, QStringLiteral("tags/%1/%2").arg(id, leaf));
    if (kind == QLatin1String("space"))
        return contentPath(orgId, spaceId, leaf);
    return contentPath(orgId, spaceId, QStringLiteral("%1/%2/%3")
                               .arg(kind == QLatin1String("folder") ? QStringLiteral("folders") : QStringLiteral("documents"), id, leaf));
}

QString AccessDirectory::principalFieldName(const QString &kind)
{
    return kind == QLatin1String("group") ? QStringLiteral("group_id")
         : kind == QLatin1String("role") ? QStringLiteral("role_principal_id")
                                         : QStringLiteral("organization_membership_id");
}

QJsonObject AccessDirectory::principalField(const QString &principal)
{
    return {{principalFieldName(principal.section(QLatin1Char(':'), 0, 0)), principal.section(QLatin1Char(':'), 1)}};
}

AddOnBackend::Step AccessDirectory::grantStep(const QString &orgId, const QString &kind, const QString &spaceId, const QString &id,
                                              const QString &principal, const QString &roleId)
{
    QJsonObject body = principalField(principal);
    body.insert(QStringLiteral("role_id"), roleId);
    return {"POST", resourcePath(orgId, kind, spaceId, id, QStringLiteral("grants")), body};
}

void AccessDirectory::open()
{
    const QString org = m_session.currentOrgId();
    if (org.isEmpty() || !m_session.signedIn())
        return;
    if (org != m_orgId) {
        close();
        m_orgId = org;
    }
    m_notice.clear();
    load();
}

void AccessDirectory::close()
{
    if (!active())
        return;
    ++m_generation;
    ++m_opened;
    m_reading = m_writing = 0;
    m_orgId.clear();
    m_errorCode.clear();
    m_notice.clear();
    m_members = m_groups = m_roles = m_tags = {};
    m_groupMembers.clear();
    m_listed.clear();
    emit changed();
    emit listsChanged();
}

void AccessDirectory::finished(const Client::Reply &reply)
{
    if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
    if (--m_reading == 0) publish();
    emit changed();
}

void AccessDirectory::publish()
{
    QJsonObject members;
    for (auto it = m_groupMembers.cbegin(); it != m_groupMembers.cend(); ++it) members.insert(it.key(), it.value());
    if (changedSince(m_listed, QJsonArray{m_members, m_groups, members, m_roles, m_session.permissions()->catalog(), m_tags}))
        emit listsChanged();
}

void AccessDirectory::load()
{
    const int generation = ++m_generation;
    m_reading = 4;
    m_errorCode.clear();
    emit changed();
    m_session.permissions()->reload();
    const auto isLive = [this, generation] { return live(generation); };
    const auto read = [this, isLive](const QString &leaf, QJsonArray &target) {
        m_backend.list(orgPath(m_orgId, leaf), leaf, isLive, [this, &target](const Client::Reply &reply, const QJsonArray &rows) {
            target = reply.ok ? rows : QJsonArray();
            finished(reply);
        });
    };
    read(QStringLiteral("members"), m_members);
    read(QStringLiteral("roles"), m_roles);
    read(QStringLiteral("tags"), m_tags);
    m_backend.list(orgPath(m_orgId, QStringLiteral("groups")), QStringLiteral("groups"), isLive,
                   [this, isLive](const Client::Reply &reply, const QJsonArray &rows) {
        m_groups = reply.ok ? rows : QJsonArray();
        m_groupMembers.clear();
        m_reading += int(m_groups.size());
        for (const auto &value : std::as_const(m_groups)) {
            const QString id = jsonId(value.toObject().value(QStringLiteral("id")));
            m_backend.list(orgPath(m_orgId, QStringLiteral("groups/%1/members").arg(id)), QStringLiteral("members"), isLive,
                           [this, id](const Client::Reply &reply, const QJsonArray &rows) {
                m_groupMembers.insert(id, rows);
                finished(reply);
            });
        }
        finished(reply);
    });
}

QStringList AccessDirectory::groupMembers(const QString &groupId) const
{
    QStringList ids;
    for (const auto &row : m_groupMembers.value(groupId))
        ids.append(jsonId(row.toObject().value(QStringLiteral("organization_membership_id"))));
    return ids;
}

void AccessDirectory::change(QList<AddOnBackend::Step> steps, const QString &notice, const QString &createdKey)
{
    if (!active() || busy() || steps.isEmpty())
        return;
    for (auto &step : steps) step.path = orgPath(m_orgId, step.path);
    const int opened = m_opened;
    auto created = std::make_shared<QString>();
    m_writing += int(steps.size());
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.requestAll(steps, [this, opened] { return stillOpen(opened); },
                         [this, created, createdKey](qsizetype step, const Client::Reply &reply) {
        --m_writing;
        if (reply.ok && step == 0 && !createdKey.isEmpty())
            *created = jsonId(reply.json.value(createdKey).toObject().value(QStringLiteral("id")));
    }, [this, created, notice](const QString &failure) {
        // Whatever landed shows; a refusal says why and names no notice.
        load();
        m_errorCode = failure;
        m_notice = failure.isEmpty() ? notice : QString();
        emit changed();
        if (failure.isEmpty()) emit saved(notice, *created);
    });
}

void AccessDirectory::createRole(const QString &name, const QStringList &actions)
{
    if (name.trimmed().isEmpty() || actions.isEmpty())
        return;
    change({{"POST", QStringLiteral("roles"),
             {{QStringLiteral("key"), QStringLiteral("custom-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))},
              {QStringLiteral("name"), name.trimmed()},
              {QStringLiteral("actions"), QJsonArray::fromStringList(actions)}}}},
           QStringLiteral("role_created"), QStringLiteral("role"));
}

void AccessDirectory::updateRole(const QString &roleId, const QString &name, const QStringList &actions)
{
    if (!custom(role(roleId)) || name.trimmed().isEmpty() || actions.isEmpty())
        return;
    change({{"PATCH", QStringLiteral("roles/%1").arg(roleId),
             {{QStringLiteral("name"), name.trimmed()}, {QStringLiteral("actions"), QJsonArray::fromStringList(actions)}}}},
           QStringLiteral("role_saved"));
}

void AccessDirectory::archiveRole(const QString &roleId)
{
    if (custom(role(roleId)))
        change({{"POST", QStringLiteral("roles/%1/archive").arg(roleId), {}}}, QStringLiteral("role_archived"));
}

void AccessDirectory::createGroup(const QString &name)
{
    if (!name.trimmed().isEmpty())
        change({{"POST", QStringLiteral("groups"), {{QStringLiteral("name"), name.trimmed()}}}},
               QStringLiteral("group_created"), QStringLiteral("group"));
}

void AccessDirectory::renameGroup(const QString &groupId, const QString &name)
{
    if (!byId(m_groups, groupId).isEmpty() && !name.trimmed().isEmpty())
        change({{"PATCH", QStringLiteral("groups/%1").arg(groupId), {{QStringLiteral("name"), name.trimmed()}}}},
               QStringLiteral("group_saved"));
}

void AccessDirectory::archiveGroup(const QString &groupId)
{
    if (!byId(m_groups, groupId).isEmpty())
        change({{"POST", QStringLiteral("groups/%1/archive").arg(groupId), {}}}, QStringLiteral("group_archived"));
}

void AccessDirectory::setGroupMembers(const QString &groupId, const QStringList &membershipIds)
{
    if (byId(m_groups, groupId).isEmpty())
        return;
    const QStringList held = groupMembers(groupId);
    QList<AddOnBackend::Step> steps;
    for (const QString &membership : membershipIds)
        if (!held.contains(membership) && !byId(m_members, membership).isEmpty())
            steps.append({"POST", QStringLiteral("groups/%1/members").arg(groupId),
                          {{QStringLiteral("organization_membership_id"), membership}}});
    for (const QString &membership : held)
        if (!membershipIds.contains(membership))
            steps.append({"DELETE", QStringLiteral("groups/%1/members/%2").arg(groupId, membership), {}});
    change(steps, QStringLiteral("group_members_saved"));
}

void AccessDirectory::setMemberGroups(const QString &membershipId, const QStringList &groupIds)
{
    if (byId(m_members, membershipId).isEmpty())
        return;
    QList<AddOnBackend::Step> steps;
    for (const auto &value : std::as_const(m_groups)) {
        const QString group = jsonId(value.toObject().value(QStringLiteral("id")));
        const bool held = groupMembers(group).contains(membershipId);
        if (!held && groupIds.contains(group))
            steps.append({"POST", QStringLiteral("groups/%1/members").arg(group),
                          {{QStringLiteral("organization_membership_id"), membershipId}}});
        else if (held && !groupIds.contains(group))
            steps.append({"DELETE", QStringLiteral("groups/%1/members/%2").arg(group, membershipId), {}});
    }
    change(steps, QStringLiteral("groups_saved"));
}

void AccessDirectory::createTag(const QString &name, bool controlled)
{
    if (!name.trimmed().isEmpty())
        change({{"POST", QStringLiteral("tags"),
                 {{QStringLiteral("name"), name.trimmed()}, {QStringLiteral("access_controlled"), controlled}}}},
               QStringLiteral("tag_created"), QStringLiteral("tag"));
}

void AccessDirectory::updateTag(const QString &tagId, const QString &name, bool controlled)
{
    const QJsonObject tag = byId(m_tags, tagId);
    if (tag.isEmpty() || name.trimmed().isEmpty())
        return;
    const bool restricting = controlled != tag.value(QStringLiteral("access_controlled")).toBool();
    change({{"PATCH", QStringLiteral("tags/%1").arg(tagId),
             {{QStringLiteral("name"), name.trimmed()}, {QStringLiteral("access_controlled"), controlled}}}},
           !restricting ? QStringLiteral("tag_saved") : controlled ? QStringLiteral("tag_restricted") : QStringLiteral("tag_opened"));
}

void AccessDirectory::archiveTag(const QString &tagId)
{
    if (!byId(m_tags, tagId).isEmpty())
        change({{"POST", QStringLiteral("tags/%1/archive").arg(tagId), {}}}, QStringLiteral("tag_archived"));
}

void AccessDirectory::renameSpace(const QString &spaceId, const QString &name)
{
    if (!spaceId.isEmpty() && !name.trimmed().isEmpty())
        change({{"PATCH", QStringLiteral("spaces/%1").arg(spaceId), {{QStringLiteral("name"), name.trimmed()}}}},
               QStringLiteral("space_renamed"));
}

void AccessDirectory::archiveSpace(const QString &spaceId)
{
    if (!spaceId.isEmpty())
        change({{"POST", QStringLiteral("spaces/%1/archive").arg(spaceId), {}}}, QStringLiteral("space_archived"));
}
}
