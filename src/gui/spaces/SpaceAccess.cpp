#include "SpaceAccess.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonObject>

namespace matome {

namespace {

bool organizationRole(const QString &key)
{
    static const QStringList keys{QStringLiteral("owner"), QStringLiteral("admin"), QStringLiteral("member"),
                                  QStringLiteral("billing"), QStringLiteral("guest")};
    return keys.contains(key);
}

QJsonObject byId(const QJsonArray &rows, const QJsonValue &id)
{
    for (const auto &row : rows)
        if (jsonId(row.toObject().value(QStringLiteral("id"))) == jsonId(id)) return row.toObject();
    return {};
}

} // namespace

SpaceAccess::SpaceAccess(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, [this] {
        if (active() && (!m_session.signedIn() || m_orgId != m_session.currentOrgId())) close();
    });
}

QVariantList SpaceAccess::grants() const
{
    QVariantList list;
    for (const auto &value : m_grants) {
        auto grant = value.toObject();
        const auto role = byId(m_roles, grant.value(QStringLiteral("role_id")));
        grant.insert(QStringLiteral("roleName"), role.value(QStringLiteral("name")).toString(grant.value(QStringLiteral("role_key")).toString()));
        grant.insert(QStringLiteral("email"), byId(m_members, grant.value(QStringLiteral("organization_membership_id")))
                                                      .value(QStringLiteral("email")));
        list.append(grant.toVariantMap());
    }
    return list;
}

QVariantList SpaceAccess::roles() const
{
    QVariantList list;
    for (const auto &value : m_roles) {
        const auto role = value.toObject();
        if (!organizationRole(role.value(QStringLiteral("key")).toString()))
            list.append(QVariantMap{{QStringLiteral("value"), jsonId(role.value(QStringLiteral("id")))},
                                    {QStringLiteral("label"), role.value(QStringLiteral("name")).toString()}});
    }
    return list;
}

QVariantList SpaceAccess::members() const
{
    QVariantList list;
    for (const auto &value : m_members) {
        const auto member = value.toObject();
        list.append(QVariantMap{{QStringLiteral("value"), jsonId(member.value(QStringLiteral("id")))},
                                {QStringLiteral("label"), member.value(QStringLiteral("email")).toString()}});
    }
    return list;
}

QVariantList SpaceAccess::spaces() const
{
    QVariantList list;
    const SpaceModel *model = m_session.spaces();
    for (int row = 0; row < model->rowCount(); ++row) {
        const QModelIndex at = model->index(row);
        list.append(QVariantMap{{QStringLiteral("value"), at.data(SpaceModel::SpaceIdRole)},
                                {QStringLiteral("label"), at.data(SpaceModel::NameRole)}});
    }
    return list;
}

void SpaceAccess::open(const QString &spaceId)
{
    if (spaceId == m_spaceId || m_session.currentOrgId().isEmpty())
        return;
    close();
    m_orgId = m_session.currentOrgId();
    m_spaceId = spaceId;
    refresh();
}

void SpaceAccess::close()
{
    if (!active())
        return;
    ++m_generation;
    m_pending = 0;
    m_orgId.clear(); m_spaceId.clear(); m_errorCode.clear(); m_notice.clear();
    m_grants = m_roles = m_members = {};
    emit changed();
}

void SpaceAccess::refresh()
{
    if (!active())
        return;
    const int generation = ++m_generation;
    m_pending = 3;
    m_errorCode.clear();
    emit changed();
    const auto read = [this, generation](const QString &path, const QString &key, QJsonArray &target) {
        m_backend.list(path, key, [this, generation] { return live(generation); },
                       [this, &target](const Client::Reply &reply, const QJsonArray &rows) {
            target = reply.ok ? rows : QJsonArray();
            if (!reply.ok) m_errorCode = failCode(reply);
            --m_pending;
            emit changed();
        });
    };
    read(contentPath(m_orgId, m_spaceId, QStringLiteral("grants")), QStringLiteral("grants"), m_grants);
    read(orgPath(m_orgId, QStringLiteral("roles")), QStringLiteral("roles"), m_roles);
    read(orgPath(m_orgId, QStringLiteral("members")), QStringLiteral("members"), m_members);
}

void SpaceAccess::grant(const QString &membershipId, const QString &roleId)
{
    if (busy() || membershipId.isEmpty() || roleId.isEmpty())
        return;
    change("POST", contentPath(m_orgId, m_spaceId, QStringLiteral("grants")),
           {{QStringLiteral("organization_membership_id"), membershipId}, {QStringLiteral("role_id"), roleId}},
           QStringLiteral("access_saved"));
}

void SpaceAccess::revoke(const QString &grantId)
{
    if (busy() || grantId.isEmpty())
        return;
    change("DELETE", contentPath(m_orgId, m_spaceId, QStringLiteral("grants/%1").arg(grantId)), {},
           QStringLiteral("access_removed"));
}

void SpaceAccess::change(const QByteArray &method, const QString &path, const QJsonObject &body, const QString &notice)
{
    const int generation = m_generation;
    ++m_pending;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    m_backend.request(method, path, body, idempotencyHeader(), [this, generation, notice](const Client::Reply &reply) {
        if (!live(generation)) return;
        --m_pending;
        if (!reply.ok) {
            m_errorCode = failCode(reply);
            emit changed();
            return;
        }
        m_notice = notice;
        refresh();
    });
}
}
