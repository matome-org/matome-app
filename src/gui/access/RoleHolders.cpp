#include "RoleHolders.h"

#include "JsonList.h"
#include "Session.h"

namespace matome {

RoleHolders::RoleHolders(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_directory(directory), m_places(places), m_backend(backend)
{
    connect(this, &RoleHolders::changed, this, [this] {
        if (changedSince(m_listed, QJsonArray{QJsonArray::fromVariantList(holders()), QJsonArray::fromStringList(assigned())}))
            emit listsChanged();
    });
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
    connect(&directory, &AccessDirectory::listsChanged, this, &RoleHolders::changed);
    // Groups archived and roles given elsewhere reach who holds the role.
    connect(&directory, &AccessDirectory::saved, this, &RoleHolders::refresh);
    connect(&places, &PlaceNames::changed, this, &RoleHolders::changed);
}

namespace {

QString principalOf(const QJsonObject &row)
{
    const auto principal = row.value(QStringLiteral("principal")).toObject();
    return principal.value(QStringLiteral("kind")).toString() + QLatin1Char(':') + jsonId(principal.value(QStringLiteral("id")));
}

} // namespace

QVariantList RoleHolders::holders() const
{
    QVariantList list;
    const bool placeOnly = m_directory.placeOnly(m_roleId);
    for (const auto &value : m_rows) {
        const auto row = value.toObject();
        const QString principal = principalOf(row);
        const QString principalKind = principal.section(QLatin1Char(':'), 0, 0);
        const QString kind = row.value(QStringLiteral("kind")).toString();
        const QString id = jsonId(row.value(QStringLiteral("id")));
        QVariantMap holder{{QStringLiteral("key"), kind + QLatin1Char(':') + id},
                           {QStringLiteral("id"), id},
                           {QStringLiteral("kind"), kind},
                           {QStringLiteral("principal"), principal},
                           {QStringLiteral("principalKind"), principalKind},
                           {QStringLiteral("principalName"), m_directory.principalName(principal)},
                           {QStringLiteral("principalKey"), principalKind == QLatin1String("role")
                                ? m_directory.role(principal.section(QLatin1Char(':'), 1)).value(QStringLiteral("key")).toString()
                                : QString()},
                           {QStringLiteral("idle"), placeOnly && kind == QLatin1String("assignment")}};
        const auto resource = row.value(QStringLiteral("resource")).toObject();
        if (!resource.isEmpty()) {
            const QString resourceKind = resource.value(QStringLiteral("kind")).toString();
            const QString resourceId = jsonId(resource.value(QStringLiteral("id")));
            const QString spaceId = jsonId(resource.value(QStringLiteral("space_id")));
            holder.insert(QStringLiteral("resourceKind"), resourceKind);
            holder.insert(QStringLiteral("resourceId"), resourceId);
            holder.insert(QStringLiteral("spaceId"), spaceId);
            holder.insert(QStringLiteral("name"), m_places.name(resourceKind, spaceId, resourceId));
            holder.insert(QStringLiteral("spaceName"), spaceId.isEmpty() ? QString()
                                                                          : m_places.name(QStringLiteral("space"), spaceId, spaceId));
        }
        list.append(holder);
    }
    return list;
}

QStringList RoleHolders::assigned() const
{
    QStringList principals;
    for (const auto &value : m_rows)
        if (value.toObject().value(QStringLiteral("kind")).toString() == QLatin1String("assignment"))
            principals.append(principalOf(value.toObject()));
    return principals;
}

void RoleHolders::open(const QString &roleId)
{
    if (roleId.isEmpty() || m_session.currentOrgId().isEmpty())
        return;
    if (roleId != m_roleId) close();
    m_orgId = m_session.currentOrgId();
    m_roleId = roleId;
    m_notice.clear();
    refresh();
}

void RoleHolders::close()
{
    if (!active())
        return;
    ++m_generation;
    ++m_opened;
    m_reading = m_writing = 0;
    m_orgId.clear();
    m_roleId.clear();
    m_errorCode.clear();
    m_notice.clear();
    m_rows = {};
    emit changed();
}

void RoleHolders::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_reading = 1;
    m_errorCode.clear();
    emit changed();
    m_backend.list(orgPath(m_orgId, QStringLiteral("roles/%1/holders").arg(m_roleId)), QStringLiteral("holders"),
                   [this, generation] { return live(generation); }, [this](const Client::Reply &reply, const QJsonArray &rows) {
        m_rows = reply.ok ? rows : QJsonArray();
        for (const auto &value : rows) {
            const auto resource = value.toObject().value(QStringLiteral("resource")).toObject();
            if (!resource.isEmpty())
                m_places.want(resource.value(QStringLiteral("kind")).toString(), jsonId(resource.value(QStringLiteral("space_id"))),
                              jsonId(resource.value(QStringLiteral("id"))));
        }
        if (!reply.ok) m_errorCode = failCode(reply);
        m_reading = 0;
        emit changed();
    });
}

void RoleHolders::add(const QStringList &principals)
{
    if (!active() || busy())
        return;
    const QStringList held = assigned();
    QList<AddOnBackend::Step> steps;
    for (const QString &principal : principals) {
        const QString kind = principal.section(QLatin1Char(':'), 0, 0);
        if (held.contains(principal) || (kind != QLatin1String("user") && kind != QLatin1String("group"))
            || m_directory.principalName(principal).isEmpty())
            continue;
        QJsonObject body = AccessDirectory::principalField(principal);
        body.insert(QStringLiteral("role_id"), m_roleId);
        steps.append({"POST", orgPath(m_orgId, QStringLiteral("principal-roles")), body});
    }
    write(steps, QStringLiteral("holders_added"));
}

void RoleHolders::grant(const QStringList &principals, const QString &spaceId)
{
    if (!active() || busy() || spaceId.isEmpty())
        return;
    QStringList held;
    for (const auto &value : std::as_const(m_rows)) {
        const auto row = value.toObject();
        const auto resource = row.value(QStringLiteral("resource")).toObject();
        if (resource.value(QStringLiteral("kind")).toString() == QLatin1String("space")
            && jsonId(resource.value(QStringLiteral("id"))) == spaceId)
            held.append(principalOf(row));
    }
    QList<AddOnBackend::Step> steps;
    for (const QString &principal : principals) {
        const QString kind = principal.section(QLatin1Char(':'), 0, 0);
        if (!held.contains(principal) && (kind == QLatin1String("user") || kind == QLatin1String("group"))
            && !m_directory.principalName(principal).isEmpty())
            steps.append(AccessDirectory::grantStep(m_orgId, QStringLiteral("space"), spaceId, spaceId, principal, m_roleId));
    }
    write(steps, QStringLiteral("holders_added"));
}

void RoleHolders::remove(const QStringList &keys)
{
    if (!active() || busy())
        return;
    QList<AddOnBackend::Step> steps;
    for (const auto &value : std::as_const(m_rows)) {
        const auto row = value.toObject();
        const QString kind = row.value(QStringLiteral("kind")).toString();
        const QString id = jsonId(row.value(QStringLiteral("id")));
        if (!keys.contains(kind + QLatin1Char(':') + id))
            continue;
        const auto resource = row.value(QStringLiteral("resource")).toObject();
        steps.append({"DELETE", kind == QLatin1String("assignment")
                         ? orgPath(m_orgId, QStringLiteral("principal-roles/%1").arg(id))
                         : AccessDirectory::resourcePath(m_orgId, resource.value(QStringLiteral("kind")).toString(),
                                                         jsonId(resource.value(QStringLiteral("space_id"))),
                                                         jsonId(resource.value(QStringLiteral("id"))), QStringLiteral("grants/%1").arg(id)),
                      {}});
    }
    write(steps, QStringLiteral("holders_removed"));
}

void RoleHolders::write(const QList<AddOnBackend::Step> &steps, const QString &notice)
{
    if (steps.isEmpty())
        return;
    const int opened = m_opened;
    m_writing = 1;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.requestAll(steps, [this, opened] { return stillOpen(opened); }, [this, notice](const QString &failure, bool landed) {
        // Whatever landed shows; a refusal says why and names no notice.
        m_writing = 0;
        refresh();
        m_errorCode = failure;
        m_notice = failure.isEmpty() ? notice : QString();
        emit changed();
        if (landed) emit rolesChanged();
    });
}
}
