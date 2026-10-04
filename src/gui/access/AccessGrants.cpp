#include "AccessGrants.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonObject>

#include <algorithm>

namespace matome {

AccessGrants::AccessGrants(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_directory(directory), m_places(places), m_backend(backend)
{
    connect(this, &AccessGrants::changed, this, [this] {
        if (changedSince(m_listed, QJsonArray{QJsonArray::fromVariantList(holders()), QJsonArray::fromVariantList(inherited()),
                                              QJsonArray::fromVariantList(principals()), QJsonObject::fromVariantMap(summary())}))
            emit listsChanged();
    });
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    connect(&directory, &AccessDirectory::listsChanged, this, &AccessGrants::changed);
    connect(&places, &PlaceNames::changed, this, &AccessGrants::changed);
}

namespace {

// The request that leaves exactly `roleIds` granted to `principal` on the
// resource whose grants live at `grantsPath`, which lands whole or not at
// all. Core answers the principal's grants there under `grants`.
AddOnBackend::Step replacement(const QString &grantsPath, const QString &principal, const QStringList &roleIds)
{
    QJsonObject body = AccessDirectory::principalField(principal);
    body.insert(QStringLiteral("role_ids"), QJsonArray::fromStringList(roleIds));
    return {"PUT", grantsPath, body};
}

// The space actions that manage access, which a grant above a break in
// inheritance still gives below it.
const QStringList &accessActions()
{
    static const QStringList actions{QStringLiteral("resource_grant.read"), QStringLiteral("resource_grant.create"),
                                     QStringLiteral("resource_grant.revoke"), QStringLiteral("access.configure")};
    return actions;
}

QString sourceOf(const QJsonObject &grant)
{
    const auto source = grant.value(QStringLiteral("source")).toObject();
    return source.value(QStringLiteral("kind")).toString() + QLatin1Char(':') + jsonId(source.value(QStringLiteral("id")));
}

} // namespace

QString AccessGrants::principalOf(const QJsonObject &grant)
{
    const QString kind = grant.value(QStringLiteral("principal_kind")).toString();
    return kind + QLatin1Char(':') + jsonId(grant.value(AccessDirectory::principalFieldName(kind)));
}

QVariantMap AccessGrants::holder(const QString &principal, const QJsonArray &grants) const
{
    const QString kind = principal.section(QLatin1Char(':'), 0, 0);
    QVariantMap row = m_directory.holding(grants);
    row.insert(QStringLiteral("principal"), principal);
    row.insert(QStringLiteral("principalKind"), kind);
    row.insert(QStringLiteral("principalName"), m_directory.principalName(principal));
    row.insert(QStringLiteral("principalKey"), kind == QLatin1String("role")
               ? m_directory.role(principal.section(QLatin1Char(':'), 1)).value(QStringLiteral("key")).toString()
               : QString());
    return row;
}

QVariantList AccessGrants::holders() const
{
    QVariantList list;
    for (const QJsonArray &grants : grouped(m_grants, principalOf))
        list.append(holder(principalOf(grants.first().toObject()), grants));
    return list;
}

QVariantList AccessGrants::inherited() const
{
    QVariantList list;
    const auto keyOf = [](const QJsonObject &grant) { return sourceOf(grant) + QLatin1Char('|') + principalOf(grant); };
    for (const QJsonArray &grants : grouped(m_inherited, keyOf)) {
        const auto first = grants.first().toObject();
        const auto source = first.value(QStringLiteral("source")).toObject();
        const QString kind = source.value(QStringLiteral("kind")).toString();
        const QString id = jsonId(source.value(QStringLiteral("id")));
        QVariantMap row = holder(principalOf(first), grants);
        row.insert(QStringLiteral("sourceKind"), kind);
        row.insert(QStringLiteral("sourceId"), id);
        row.insert(QStringLiteral("sourceName"), m_places.name(kind, m_spaceId, id));
        row.insert(QStringLiteral("scope"), first.value(QStringLiteral("scope")).toString(QStringLiteral("full")));
        list.append(row);
    }
    return list;
}

QVariantMap AccessGrants::summary() const
{
    if (m_summary.isEmpty())
        return {};
    const auto nameOf = [this](const QJsonObject &place) {
        const QString kind = place.value(QStringLiteral("kind")).toString();
        const QString id = jsonId(place.value(QStringLiteral("id")));
        return id == m_targetId && kind == m_kind ? m_name : m_places.name(kind, m_spaceId, id);
    };
    const auto breaking = m_summary.value(QStringLiteral("break")).toObject();
    const auto open = m_summary.value(QStringLiteral("open_source")).toObject();
    return {{QStringLiteral("visibility"), m_summary.value(QStringLiteral("visibility")).toString()},
            {QStringLiteral("inheritance"), m_summary.value(QStringLiteral("inheritance")).toString()},
            {QStringLiteral("breakKind"), breaking.value(QStringLiteral("kind")).toString()},
            {QStringLiteral("breakName"), breaking.isEmpty() ? QString() : nameOf(breaking)},
            {QStringLiteral("openToMembers"), m_summary.value(QStringLiteral("open_to_members")).toBool()},
            {QStringLiteral("openKind"), open.value(QStringLiteral("kind")).toString()},
            {QStringLiteral("openName"), open.isEmpty() ? QString() : nameOf(open)}};
}

QStringList AccessGrants::heldRoles(const QString &principal) const
{
    QStringList held;
    for (const auto &value : m_grants) {
        const auto grant = value.toObject();
        const QString role = jsonId(grant.value(QStringLiteral("role_id")));
        if (principalOf(grant) == principal && !m_directory.role(role).isEmpty() && !held.contains(role)) held.append(role);
    }
    return held;
}

QString AccessGrants::path(const QString &leaf) const
{
    return AccessDirectory::resourcePath(m_orgId, m_kind, m_spaceId, m_targetId, leaf);
}

void AccessGrants::open(const QString &kind, const QString &spaceId, const QString &targetId, const QString &name)
{
    static const QStringList kinds{QStringLiteral("space"), QStringLiteral("folder"), QStringLiteral("document"),
                                   QStringLiteral("tag")};
    if (!kinds.contains(kind) || targetId.isEmpty() || m_session.currentOrgId().isEmpty()
        || (kind != QLatin1String("tag") && spaceId.isEmpty()))
        return;
    close();
    m_orgId = m_session.currentOrgId();
    m_kind = kind;
    m_spaceId = kind == QLatin1String("tag") ? QString() : spaceId;
    m_targetId = targetId;
    m_name = name;
    if (!m_directory.active()) m_directory.open();
    // A refusal here is explained from the space's catalog.
    if (!m_spaceId.isEmpty()) m_session.permissions()->watch(m_spaceId);
    refresh();
}

void AccessGrants::close()
{
    if (!active())
        return;
    ++m_generation;
    m_pending = m_checking = 0;
    m_principalRoles.clear();
    m_tagGrants.clear();
    m_orgId.clear(); m_kind.clear(); m_spaceId.clear(); m_targetId.clear(); m_name.clear();
    m_errorCode.clear(); m_notice.clear();
    m_grants = m_inherited = {};
    m_summary = {};
    emit changed();
}

// A tag lists its grants; a space, folder, or document lists its effective
// access, its own grants marked not inherited.
void AccessGrants::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_pending = 1;
    m_checking = 0;
    m_principalRoles.clear();
    m_tagGrants.clear();
    m_errorCode.clear();
    emit changed();
    if (m_kind == QLatin1String("document")) readTags(generation);
    const bool tag = m_kind == QLatin1String("tag");
    const QString key = tag ? QStringLiteral("grants") : QStringLiteral("access");
    m_backend.list(path(key), key, [this, generation] { return live(generation); },
                   [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_grants = m_inherited = {};
        m_summary = reply.json.value(QStringLiteral("summary")).toObject();
        for (const QString &end : {QStringLiteral("break"), QStringLiteral("open_source")}) {
            const auto place = m_summary.value(end).toObject();
            m_places.want(place.value(QStringLiteral("kind")).toString(), m_spaceId, jsonId(place.value(QStringLiteral("id"))));
        }
        for (const auto &value : rows) {
            const auto grant = value.toObject();
            if (!grant.value(QStringLiteral("inherited")).toBool()) {
                m_grants.append(grant);
                continue;
            }
            m_inherited.append(grant);
            const auto source = grant.value(QStringLiteral("source")).toObject();
            m_places.want(source.value(QStringLiteral("kind")).toString(), m_spaceId, jsonId(source.value(QStringLiteral("id"))));
        }
        if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
        --m_pending;
        emit changed();
    });
}

// The tags on the open document, each with its grants: a restricted one
// hides the document from whoever none of them reaches.
void AccessGrants::readTags(int generation)
{
    ++m_pending;
    m_backend.request("GET", contentPath(m_orgId, m_spaceId, QStringLiteral("documents/") + m_targetId), {}, {}, [this, generation](const Client::Reply &reply) {
        if (!live(generation)) return;
        for (const auto &value : reply.json.value(QStringLiteral("document")).toObject().value(QStringLiteral("tag_assignments")).toArray()) {
            const QString tag = jsonId(value.toObject().value(QStringLiteral("tag_id")));
            if (tag.isEmpty() || m_tagGrants.contains(tag)) continue;
            m_tagGrants.insert(tag, {});
            ++m_pending;
            m_backend.list(AccessDirectory::resourcePath(m_orgId, QStringLiteral("tag"), {}, tag, QStringLiteral("grants")),
                           QStringLiteral("grants"), [this, generation] { return live(generation); },
                           [this, tag](const Client::Reply &reply, const QJsonArray &rows) {
                m_tagGrants.insert(tag, rows);
                if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
                --m_pending;
                emit changed();
            });
        }
        if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
        --m_pending;
        emit changed();
    });
}

// Core answers each principal's grants here; they take the place of the
// principal's rows, and a refusal changed nothing for that principal.
void AccessGrants::write(const QList<std::pair<QString, QStringList>> &roles, const QString &notice)
{
    if (roles.isEmpty())
        return;
    const int generation = m_generation;
    QList<AddOnBackend::Step> steps;
    for (const auto &[principal, roleIds] : roles) steps.append(replacement(path(QStringLiteral("grants")), principal, roleIds));
    m_pending = int(steps.size());
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.requestAll(steps, [this, generation] { return live(generation); },
                         [this, roles](qsizetype step, const Client::Reply &reply) {
        --m_pending;
        if (!reply.ok)
            return;
        const QString principal = roles.at(step).first;
        QJsonArray kept;
        qsizetype at = -1;
        for (const auto &value : std::as_const(m_grants)) {
            if (principalOf(value.toObject()) != principal) kept.append(value);
            else if (at < 0) at = kept.size();
        }
        if (at < 0) at = kept.size();
        for (const auto &value : reply.json.value(QStringLiteral("grants")).toArray()) kept.insert(at++, value);
        m_grants = kept;
        emit changed();
    }, [this, notice](const QString &failure) {
        m_errorCode = failure;
        m_notice = failure.isEmpty() ? notice : QString();
        emit changed();
    });
}

bool AccessGrants::grantable(const QString &principal) const
{
    const QString kind = principal.section(QLatin1Char(':'), 0, 0);
    return !principal.section(QLatin1Char(':'), 1).isEmpty()
           && (kind == QLatin1String("user") || kind == QLatin1String("group")
               || (kind == QLatin1String("role") && m_kind == QLatin1String("tag")));
}

void AccessGrants::setRoles(const QString &principal, const QStringList &roleIds)
{
    if (!active() || busy() || !grantable(principal))
        return;
    QStringList held = heldRoles(principal), wanted;
    for (const QString &role : roleIds)
        if (!m_directory.role(role).isEmpty() && !wanted.contains(role)) wanted.append(role);
    QStringList sorted = wanted;
    held.sort();
    sorted.sort();
    if (held != sorted)
        write({{principal, wanted}}, wanted.isEmpty() ? QStringLiteral("access_removed") : QStringLiteral("access_saved"));
}

void AccessGrants::remove(const QStringList &principals)
{
    if (!active() || busy())
        return;
    QList<std::pair<QString, QStringList>> roles;
    for (const QString &principal : principals)
        if (grantable(principal) && !heldRoles(principal).isEmpty()) roles.append({principal, {}});
    write(roles, QStringLiteral("access_removed"));
}

void AccessGrants::add(const QStringList &principals, const QStringList &roleIds)
{
    if (!active() || busy())
        return;
    QList<std::pair<QString, QStringList>> roles;
    for (const QString &principal : principals) {
        if (!grantable(principal))
            continue;
        QStringList held = heldRoles(principal);
        const qsizetype before = held.size();
        for (const QString &role : roleIds)
            if (!m_directory.role(role).isEmpty() && !held.contains(role)) held.append(role);
        if (held.size() > before) roles.append({principal, held});
    }
    write(roles, QStringLiteral("access_added"));
}

void AccessGrants::setInheritance(const QString &inheritance)
{
    static const QStringList values{QStringLiteral("inherit"), QStringLiteral("restricted"), QStringLiteral("open")};
    if (!active() || busy() || !values.contains(inheritance)
        || (m_kind != QLatin1String("folder") && m_kind != QLatin1String("document")))
        return;
    const int generation = m_generation;
    // Stopped already, it switches between restricted and open.
    const bool stopped = !m_summary.value(QStringLiteral("inheritance")).toString().isEmpty();
    m_pending = 1;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request("PUT", path(QStringLiteral("access")), {{QStringLiteral("inheritance"), inheritance}},
                      idempotencyHeader(), [this, generation, inheritance, stopped](const Client::Reply &reply) {
        if (!live(generation)) return;
        --m_pending;
        if (!reply.ok) {
            m_errorCode = failCode(reply);
            emit changed();
            return;
        }
        m_notice = inheritance == QLatin1String("inherit") ? QStringLiteral("inheritance_restored")
                 : !stopped ? QStringLiteral("inheritance_stopped")
                 : inheritance == QLatin1String("open") ? QStringLiteral("inheritance_opened")
                                                        : QStringLiteral("inheritance_restricted");
        refresh();
    });
}

// Grants reach the member when they name them or a group they belong to; a
// grant above a break gives only its access-management actions. Owners and
// administrators manage access everywhere; a space they also run, and an
// open place lets every member except guests read.
// The groups of the member `membershipId`, by id.
static QStringList groupsOf(const AccessDirectory &directory, const QString &membershipId)
{
    QStringList groups;
    for (const QVariant &value : directory.groups()) {
        const auto group = value.toMap();
        for (const QVariant &member : group.value(QStringLiteral("members")).toList())
            if (member.toMap().value(QStringLiteral("id")).toString() == membershipId)
                groups.append(group.value(QStringLiteral("id")).toString());
    }
    return groups;
}

void AccessGrants::check(const QString &membershipId)
{
    if (!active() || m_kind == QLatin1String("tag"))
        return;
    const int generation = m_generation;
    QStringList principals;
    for (const QString &group : groupsOf(m_directory, membershipId)) principals.append(QStringLiteral("group:") + group);
    // A role a tag grant names reaches a member given it directly too.
    if (!m_tagGrants.isEmpty()) principals.append(QStringLiteral("user:") + membershipId);
    for (const QString &principal : std::as_const(principals)) {
        if (m_principalRoles.contains(principal))
            continue;
        m_principalRoles.insert(principal, {});
        ++m_checking;
        const QString field = principal.startsWith(QLatin1String("group:")) ? QStringLiteral("group_id")
                                                                           : QStringLiteral("organization_membership_id");
        m_backend.list(orgPath(m_orgId, QStringLiteral("principal-roles?%1=%2").arg(field, principal.section(QLatin1Char(':'), 1))),
                       QStringLiteral("principal_roles"), [this, generation] { return live(generation); },
                       [this, principal](const Client::Reply &reply, const QJsonArray &rows) {
            QStringList roles;
            for (const auto &row : rows) roles.append(jsonId(row.toObject().value(QStringLiteral("role_id"))));
            m_principalRoles.insert(principal, roles);
            if (!reply.ok && m_errorCode.isEmpty()) m_errorCode = failCode(reply);
            --m_checking;
            emit changed();
        });
    }
    emit changed();
}

QVariantMap AccessGrants::explain(const QString &membershipId) const
{
    if (!active() || m_kind == QLatin1String("tag") || membershipId.isEmpty())
        return {};
    const auto roleByKey = [this](const QString &key) {
        for (const QVariant &value : m_directory.roles())
            if (value.toMap().value(QStringLiteral("key")).toString() == key) return value.toMap();
        return QVariantMap();
    };
    const QStringList groups = groupsOf(m_directory, membershipId);
    QStringList held;
    for (const QVariant &value : m_directory.members())
        if (value.toMap().value(QStringLiteral("id")).toString() == membershipId)
            held = value.toMap().value(QStringLiteral("roles")).toStringList();
    // The built-in organization roles held through a group, by key: the
    // first group that holds each.
    QHash<QString, QString> through;
    for (const QString &group : groups) {
        for (const QString &roleId : m_principalRoles.value(QStringLiteral("group:") + group)) {
            const QString key = m_directory.role(roleId).value(QStringLiteral("key")).toString();
            if (!key.isEmpty() && !held.contains(key) && !through.contains(key))
                through.insert(key, m_directory.principalName(QStringLiteral("group:") + group));
        }
    }
    QStringList actions;
    QVariantList reasons;
    const auto give = [&actions](const QStringList &more) {
        for (const QString &action : more)
            if (!actions.contains(action)) actions.append(action);
    };
    const auto consider = [&](const QJsonObject &grant, const QString &sourceKind, const QString &sourceName) {
        const QString principal = principalOf(grant);
        const QString kind = principal.section(QLatin1Char(':'), 0, 0), id = principal.section(QLatin1Char(':'), 1);
        if (!(kind == QLatin1String("user") && id == membershipId) && !(kind == QLatin1String("group") && groups.contains(id)))
            return;
        const auto role = m_directory.role(jsonId(grant.value(QStringLiteral("role_id"))));
        if (role.isEmpty())
            return;
        const QString scope = grant.value(QStringLiteral("scope")).toString(QStringLiteral("full"));
        QStringList given;
        for (const auto &action : role.value(QStringLiteral("actions")).toArray())
            if (scope == QLatin1String("full") || accessActions().contains(action.toString())) given.append(action.toString());
        give(given);
        reasons.append(QVariantMap{{QStringLiteral("kind"), QStringLiteral("grant")},
                                   {QStringLiteral("roleKey"), role.value(QStringLiteral("key")).toString()},
                                   {QStringLiteral("roleName"), role.value(QStringLiteral("name")).toString()},
                                   {QStringLiteral("via"), kind == QLatin1String("group") ? m_directory.principalName(principal) : QString()},
                                   {QStringLiteral("sourceKind"), sourceKind},
                                   {QStringLiteral("sourceName"), sourceName},
                                   {QStringLiteral("scope"), scope}});
    };
    for (const auto &value : m_grants) consider(value.toObject(), m_kind, m_name);
    for (const auto &value : m_inherited) {
        const auto source = value.toObject().value(QStringLiteral("source")).toObject();
        const QString kind = source.value(QStringLiteral("kind")).toString();
        consider(value.toObject(), kind, m_places.name(kind, m_spaceId, jsonId(source.value(QStringLiteral("id")))));
    }
    const QVariantMap reach = summary();
    const QStringList all = held + through.keys();
    const bool member = std::any_of(all.cbegin(), all.cend(), [](const QString &key) { return key != QLatin1String("guest"); });
    if (member && reach.value(QStringLiteral("openToMembers")).toBool()) {
        give(roleByKey(QStringLiteral("content_reader")).value(QStringLiteral("actions")).toStringList());
        reasons.append(QVariantMap{{QStringLiteral("kind"), QStringLiteral("open")},
                                   {QStringLiteral("sourceKind"), reach.value(QStringLiteral("openKind"))},
                                   {QStringLiteral("sourceName"), reach.value(QStringLiteral("openName"))}});
    }
    for (const QString &key : {QStringLiteral("owner"), QStringLiteral("admin")}) {
        if (!all.contains(key))
            continue;
        const QStringList operating = roleByKey(QStringLiteral("space_operator")).value(QStringLiteral("actions")).toStringList();
        if (m_kind == QLatin1String("space")) give(operating);
        else give(accessActions());
        reasons.append(QVariantMap{{QStringLiteral("kind"), QStringLiteral("organization")}, {QStringLiteral("roleKey"), key},
                                   {QStringLiteral("via"), through.value(key)}});
        break;
    }
    // A restricted tag on a document hides it, with every action on it, from
    // whoever no grant on the tag reaches: given to them, a group of theirs,
    // or a role they hold.
    QStringList roleIds;
    for (const QString &key : all) roleIds.append(roleByKey(key).value(QStringLiteral("id")).toString());
    roleIds += m_principalRoles.value(QStringLiteral("user:") + membershipId);
    for (const QString &group : groups) roleIds += m_principalRoles.value(QStringLiteral("group:") + group);
    bool hidden = false;
    for (const QVariant &value : m_directory.tags()) {
        const QVariantMap tag = value.toMap();
        const QString id = tag.value(QStringLiteral("id")).toString();
        if (!m_tagGrants.contains(id) || !tag.value(QStringLiteral("access_controlled")).toBool())
            continue;
        const QJsonArray grants = m_tagGrants.value(id);
        const bool reached = std::any_of(grants.begin(), grants.end(), [&](const QJsonValue &grant) {
            const QString principal = principalOf(grant.toObject());
            const QString kind = principal.section(QLatin1Char(':'), 0, 0), principalId = principal.section(QLatin1Char(':'), 1);
            return (kind == QLatin1String("user") && principalId == membershipId)
                   || (kind == QLatin1String("group") && groups.contains(principalId))
                   || (kind == QLatin1String("role") && roleIds.contains(principalId));
        });
        hidden = hidden || !reached;
        reasons.append(QVariantMap{{QStringLiteral("kind"), QStringLiteral("tag")},
                                   {QStringLiteral("sourceName"), tag.value(QStringLiteral("name")).toString()},
                                   {QStringLiteral("held"), reached}});
    }
    if (hidden) actions.clear();
    return {{QStringLiteral("actions"), actions}, {QStringLiteral("reasons"), reasons}};
}
}
