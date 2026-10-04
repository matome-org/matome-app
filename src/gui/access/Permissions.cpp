#include "Permissions.h"

#include "JsonList.h"
#include "Session.h"

#include <QPointer>

#include <algorithm>

namespace matome {

namespace {

// The actions that manage each Settings section of an organization: the
// section opens for whoever holds one of them there.
const QList<std::pair<QString, QStringList>> &sectionActions()
{
    static const QList<std::pair<QString, QStringList>> sections{
        {QStringLiteral("general"), {QStringLiteral("organization.update_policy")}},
        {QStringLiteral("members"), {QStringLiteral("membership.create"), QStringLiteral("membership.invite"),
                                     QStringLiteral("principal_role.grant")}},
        {QStringLiteral("groups"), {QStringLiteral("group.create"), QStringLiteral("group.update"),
                                    QStringLiteral("group.membership_change")}},
        {QStringLiteral("roles"), {QStringLiteral("role.create"), QStringLiteral("role.update"),
                                   QStringLiteral("principal_role.grant")}},
        {QStringLiteral("spaces"), {QStringLiteral("resource_grant.read")}},
        {QStringLiteral("tags"), {QStringLiteral("tag.create"), QStringLiteral("tag.update")}},
        {QStringLiteral("usage"), {QStringLiteral("usage.read")}},
        {QStringLiteral("billing"), {QStringLiteral("billing.read")}},
        {QStringLiteral("addons"), {QStringLiteral("add_on.read")}}};
    return sections;
}

QSet<QString> allowedOf(const QJsonArray &actions)
{
    QSet<QString> allowed;
    for (const auto &value : actions)
        if (value.toObject().value(QStringLiteral("allowed")).toBool())
            allowed.insert(value.toObject().value(QStringLiteral("key")).toString());
    return allowed;
}

} // namespace

Permissions::Permissions(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, &Permissions::follow);
}

void Permissions::readOrganizations()
{
    for (const QString &org : m_session.organizations()->ids())
        if (!m_organizations.contains(org)) readOrganization(org);
}

void Permissions::bump()
{
    ++m_revision;
    emit changed();
}

void Permissions::follow()
{
    const QString org = m_session.signedIn() ? m_session.currentOrgId() : QString();
    if (!m_session.signedIn() && !m_organizations.isEmpty()) {
        ++m_generation;
        m_asking.clear();
        m_organizations.clear();
        m_catalogs.clear();
    }
    if (org != m_orgId) {
        ++m_spaceGeneration;
        m_orgId = org;
        m_spaces.clear();
        if (!org.isEmpty() && !known(org)) readOrganization(org);
        bump();
    }
    if (!org.isEmpty() && !m_session.currentSpaceId().isEmpty()) watch(m_session.currentSpaceId());
}

bool Permissions::allows(const QString &orgId, const QString &action) const
{
    return m_organizations.value(orgId).contains(action);
}

QStringList Permissions::sections(const QString &orgId) const
{
    QStringList open;
    for (const auto &[section, actions] : sectionActions())
        if (std::any_of(actions.begin(), actions.end(), [&](const QString &action) { return allows(orgId, action); }))
            open.append(section);
    return open;
}

QJsonObject Permissions::descriptor(const QString &action) const
{
    for (const auto &value : catalog())
        if (value.toObject().value(QStringLiteral("key")).toString() == action) return value.toObject();
    return {};
}

void Permissions::readCatalog(AddOnBackend &backend, const QString &orgId, const QString &spaceId,
                              AddOnBackend::Live live, AddOnBackend::ListDone done)
{
    backend.request("GET", orgPath(orgId, QStringLiteral("action-catalog"))
                           + (spaceId.isEmpty() ? QString() : QStringLiteral("?space_id=") + spaceId), {}, {},
                    [live, done](const Client::Reply &reply) {
        if (live()) done(reply, reply.json.value(QStringLiteral("actions")).toArray());
    });
}

void Permissions::readOrganization(const QString &orgId)
{
    if (m_asking.contains(orgId)) return;
    m_asking.insert(orgId);
    const int generation = m_generation;
    const QPointer<Permissions> self(this);
    readCatalog(m_backend, orgId, {}, [self, generation] { return self && generation == self->m_generation; },
                [this, orgId](const Client::Reply &reply, const QJsonArray &actions) {
        m_asking.remove(orgId);
        if (!reply.ok) return;
        m_organizations.insert(orgId, allowedOf(actions));
        m_catalogs.insert(orgId, actions);
        bump();
    });
}

void Permissions::watch(const QString &spaceId)
{
    if (m_orgId.isEmpty() || spaceId.isEmpty() || m_spaces.contains(spaceId)) return;
    m_spaces.insert(spaceId, {});
    readSpace(spaceId);
}

void Permissions::reload()
{
    ++m_generation;
    ++m_spaceGeneration;
    m_asking.clear();
    for (const QString &org : m_session.organizations()->ids()) readOrganization(org);
    if (!m_orgId.isEmpty() && !m_organizations.contains(m_orgId)) readOrganization(m_orgId);
    for (auto it = m_spaces.begin(); it != m_spaces.end(); ++it) readSpace(it.key());
}

// The space's catalog, then its add-ons where the person may turn them on.
void Permissions::readSpace(const QString &spaceId)
{
    const int generation = m_spaceGeneration;
    const QPointer<Permissions> self(this);
    const auto live = [self, generation] { return self && generation == self->m_spaceGeneration; };
    readCatalog(m_backend, m_orgId, spaceId, live, [this, spaceId, live](const Client::Reply &reply, const QJsonArray &actions) {
        if (!reply.ok || !m_spaces.contains(spaceId)) return;
        Space &space = m_spaces[spaceId];
        space.allowed = allowedOf(actions);
        space.read = true;
        if (!space.allowed.contains(QStringLiteral("add_on.space_activate"))) {
            space.addOns.clear();
            space.addOnsRead = false;
            bump();
            return;
        }
        bump();
        m_backend.list(contentPath(m_orgId, spaceId, QStringLiteral("add-ons")), QStringLiteral("add_ons"), live,
                       [this, spaceId](const Client::Reply &reply, const QJsonArray &rows) {
            if (!reply.ok || !m_spaces.contains(spaceId)) return;
            Space &space = m_spaces[spaceId];
            space.addOns.clear();
            for (const auto &row : rows)
                space.addOns.insert(row.toObject().value(QStringLiteral("product_key")).toString(), row.toObject());
            space.addOnsRead = true;
            bump();
        });
    });
}

bool Permissions::spaceAllows(const QString &spaceId, const QString &action) const
{
    const Space space = m_spaces.value(spaceId);
    return !space.allowed.contains(QStringLiteral("content.list")) || space.allowed.contains(action);
}

bool Permissions::spaceGrants(const QString &spaceId, const QString &action) const
{
    const Space space = m_spaces.value(spaceId);
    return space.allowed.contains(QStringLiteral("content.list")) && space.allowed.contains(action);
}

QVariantMap Permissions::explain(const QString &action, const QString &spaceId) const
{
    const bool inSpace = !spaceId.isEmpty();
    const Space space = m_spaces.value(spaceId);
    const bool read = inSpace ? space.read : known(m_orgId);
    QVariantMap answer{{QStringLiteral("known"), read}, {QStringLiteral("spaceId"), spaceId},
                       {QStringLiteral("spaceName"), inSpace ? m_session.spaces()->nameOf(spaceId) : QString()}};
    if (!read) return answer;
    const bool allowed = inSpace ? space.allowed.contains(action) : allows(m_orgId, action);
    const QJsonObject described = descriptor(action);
    answer.insert(QStringLiteral("allowed"), allowed);
    answer.insert(QStringLiteral("listed"), !described.isEmpty());
    if (allowed) return answer;
    const QString product = described.value(QStringLiteral("product_key")).toString();
    // A fix opens a Settings section, which the person must be able to open.
    const QStringList opens = sections(m_orgId);
    const bool managesSpaces = opens.contains(QStringLiteral("spaces"));
    const auto refuse = [&](const char *reason, const char *fix, bool canFix) {
        answer.insert(QStringLiteral("reason"), QString::fromLatin1(reason));
        answer.insert(QStringLiteral("fix"), QString::fromLatin1(fix));
        answer.insert(QStringLiteral("canFix"), canFix);
        return answer;
    };
    if (!product.isEmpty()) {
        answer.insert(QStringLiteral("product"), product);
        answer.insert(QStringLiteral("productName"), m_session.addOns()->product(product).value(QStringLiteral("name")).toString());
        const QVariantMap state = m_session.addOns()->state(product);
        const QString status = state.value(QStringLiteral("status")).toString();
        const bool installing = allows(m_orgId, QStringLiteral("add_on.install")) && opens.contains(QStringLiteral("addons"));
        if (state.value(QStringLiteral("known")).toBool()) {
            if (!state.value(QStringLiteral("entitled")).toBool())
                return refuse("plan", "plan", allows(m_orgId, QStringLiteral("billing.manage")) && opens.contains(QStringLiteral("billing")));
            if (status.isEmpty()) return refuse("uninstalled", "install", installing);
            if (status == QLatin1String("paused")) return refuse("paused", "resume", installing);
        }
        if (inSpace && described.value(QStringLiteral("axis")).toString() == QLatin1String("space")) {
            if (space.addOnsRead && space.addOns.value(product).value(QStringLiteral("status")).toString() != QLatin1String("active"))
                return refuse("inactive", "activate", space.allowed.contains(QStringLiteral("add_on.space_activate")) && managesSpaces);
            answer.insert(QStringLiteral("unsure"), !space.addOnsRead);
        }
    }
    // The roles that hold it where it is asked for: those a grant on the
    // space may carry, or those given across the organization.
    AccessDirectory *directory = m_session.accessDirectory();
    QList<QVariantMap> holding;
    for (const QVariant &value : inSpace ? directory->grantableRoles() : directory->assignableRoles())
        if (value.toMap().value(QStringLiteral("actions")).toStringList().contains(action)) holding.append(value.toMap());
    std::stable_sort(holding.begin(), holding.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value(QStringLiteral("actions")).toList().size() < b.value(QStringLiteral("actions")).toList().size();
    });
    QVariantList roles;
    for (const QVariantMap &role : std::as_const(holding).mid(0, 2))
        roles.append(QVariantMap{{QStringLiteral("id"), role.value(QStringLiteral("id"))},
                                 {QStringLiteral("key"), role.value(QStringLiteral("key"))},
                                 {QStringLiteral("name"), role.value(QStringLiteral("name"))}});
    answer.insert(QStringLiteral("roles"), roles);
    return inSpace ? refuse("grant", "grant", space.allowed.contains(QStringLiteral("resource_grant.create")) && managesSpaces)
                   : refuse("grant", "", false);
}
}
