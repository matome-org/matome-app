#include "OrgAdmin.h"

#include "JsonList.h"
#include "Session.h"

#include <QDateTime>
#include <QLocale>
#include <QRegularExpression>

#include <algorithm>

namespace matome {

OrgPeopleModel::OrgPeopleModel(QObject *parent)
    : ViewModel(QMetaEnum::fromType<Role>(), 1, parent)
{
}

namespace {

bool stamped(const QJsonObject &row, const char *field)
{
    const QJsonValue value = row.value(QLatin1String(field));
    return !value.isNull() && !value.isUndefined();
}

// "pending", "accepted", "canceled", or "expired".
QString invitationState(const QJsonObject &row, const QDateTime &expires)
{
    return stamped(row, "accepted_at") ? QStringLiteral("accepted")
         : stamped(row, "canceled_at") ? QStringLiteral("canceled")
         : expires.isValid() && expires <= QDateTime::currentDateTimeUtc() ? QStringLiteral("expired")
                                                                          : QStringLiteral("pending");
}

QString shortDate(const QDateTime &at)
{
    return at.isValid() ? QLocale().toString(at.toLocalTime(), QLocale::ShortFormat) : QString();
}

} // namespace

void OrgPeopleModel::replace(const QString &orgId, const QJsonArray &rows, bool invitations,
                             const std::function<QString(const QString &)> &spaceName)
{
    QList<QVariantList> values;
    for (const QJsonValue &value : rows) {
        const QJsonObject row = value.toObject();
        const QDateTime expires = QDateTime::fromString(row.value(QStringLiteral("expires_at")).toString(), Qt::ISODate);
        QStringList spaces;
        for (const QJsonValue &grant : row.value(QStringLiteral("grants")).toArray())
            spaces.append(spaceName ? spaceName(jsonId(grant.toObject().value(QStringLiteral("space_id")))) : QString());
        QStringList roles;
        for (const QJsonValue &role : row.value(QStringLiteral("roles")).toArray())
            roles.append(role.toString());
        values.append({jsonId(row.value(QStringLiteral("id"))), memberLabel(row), roles,
                       invitations ? invitationState(row, expires) : row.value(QStringLiteral("status")).toString(),
                       shortDate(expires), spaces});
    }
    apply(orgId, values);
}

OrgAdmin::OrgAdmin(Session &session)
    : QObject(&session), m_session(session), m_members(this), m_invitations(this)
{
    connect(&session, &Session::changed, this, &OrgAdmin::sync);
    connect(session.permissions(), &Permissions::changed, this, &OrgAdmin::sync);
}

// Any section of Settings but billing's, by the organization's catalog.
bool OrgAdmin::available() const
{
    if (!m_session.signedIn())
        return false;
    const QStringList open = m_session.permissions()->sections(m_session.currentOrgId());
    return std::any_of(open.begin(), open.end(), [](const QString &section) {
        return section != QLatin1String("usage") && section != QLatin1String("billing") && section != QLatin1String("addons");
    });
}

// Invitations name spaces as the space list does.
void OrgAdmin::sync()
{
    replaceInvitations();
    if (m_active && (!available() || m_orgId != m_session.currentOrgId()))
        close();
    else
        emit changed();
}

void OrgAdmin::open()
{
    if (!available() || m_active)
        return;
    m_active = true;
    m_orgId = m_session.currentOrgId();
    m_errorCode.clear();
    m_notice.clear();
    load();
}

void OrgAdmin::close()
{
    ++m_generation;
    m_active = false;
    m_saving = false;
    m_pending = 0;
    m_orgId.clear();
    m_organization = {};
    m_memberRows = {};
    m_invitationRows = {};
    m_members.replace({}, {}, false);
    m_invitations.replace({}, {}, true);
    m_errorCode.clear();
    m_notice.clear();
    m_generalError.clear();
    m_membersError.clear();
    m_invitationsError.clear();
    m_setup = {};
    emit changed();
}

bool OrgAdmin::live(int generation) const
{
    return generation == m_generation && m_active && available()
            && m_orgId == m_session.currentOrgId();
}

void OrgAdmin::refresh()
{
    if (!m_active || !available() || busy())
        return;
    m_errorCode.clear();
    m_notice.clear();
    load();
    m_session.refreshOrganizations();
}

void OrgAdmin::finished()
{
    --m_pending;
    emit changed();
}

void OrgAdmin::load()
{
    const int generation = ++m_generation;
    m_pending = 3;
    m_generalError.clear();
    m_membersError.clear();
    m_invitationsError.clear();
    emit changed();
    m_session.authedGet(orgsPath() + QLatin1Char('/') + m_orgId,
                        [this, generation](const Client::Reply &reply) {
        if (!live(generation))
            return;
        m_organization = reply.ok ? reply.json.value(QStringLiteral("organization")).toObject()
                                  : QJsonObject();
        m_generalError = reply.ok ? QString() : failCode(reply);
        finished();
    });
    const auto list = [this, generation](const QString &key, QJsonArray &rows,
                                       OrgPeopleModel &model, QString &error, bool invitations) {
        m_session.authedList(orgPath(m_orgId, key), key,
                             [this, generation] { return live(generation); },
                             [this, generation, &rows, &model, &error, invitations](
                                     const Client::Reply &reply, const QJsonArray &result) {
            if (!live(generation))
                return;
            rows = reply.ok ? result : QJsonArray();
            error = reply.ok ? QString() : failCode(reply);
            if (invitations) replaceInvitations();
            else model.replace(m_orgId, rows, false);
            finished();
        });
    };
    list(QStringLiteral("members"), m_memberRows, m_members, m_membersError, false);
    list(QStringLiteral("invitations"), m_invitationRows, m_invitations, m_invitationsError, true);
}

bool OrgAdmin::canSave() const
{
    return m_active && available() && !busy() && m_orgId == m_session.currentOrgId();
}

Client::Done OrgAdmin::saved(const QString &notice)
{
    m_saving = true;
    m_errorCode.clear();
    m_notice.clear();
    emit changed();
    const int generation = m_generation;
    return [this, generation, notice](const Client::Reply &reply) {
        if (!live(generation))
            return;
        m_saving = false;
        m_errorCode = reply.ok ? QString() : failCode(reply);
        if (reply.ok) {
            m_notice = notice;
            emit changeSaved(notice);
        }
        if (reply.ok || reply.code == QLatin1String("revision_conflict")) {
            load();
            m_session.refreshOrganizations();
        } else {
            emit changed();
        }
    };
}

bool OrgAdmin::hasRow(const QJsonArray &rows, const QString &id) const
{
    for (const QJsonValue &row : rows) {
        if (jsonId(row.toObject().value(QStringLiteral("id"))) == id)
            return true;
    }
    return false;
}

void OrgAdmin::rename(const QString &name)
{
    if (!canSave() || !m_generalError.isEmpty())
        return;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        m_errorCode = QStringLiteral("invalid_request");
        emit changed();
        return;
    }
    const QString path = orgsPath() + QLatin1Char('/') + m_orgId;
    m_session.authedPatch(path, {{QStringLiteral("name"), trimmed}},
                         idempotentMatchHeader(m_organization.value(QStringLiteral("revision")).toInt()),
                         saved(QStringLiteral("renamed")));
}

void OrgAdmin::replaceInvitations()
{
    m_invitations.replace(m_orgId, m_invitationRows, true,
                          [this](const QString &spaceId) { return m_session.spaces()->nameOf(spaceId); });
}

void OrgAdmin::invite(const QString &email, const QStringList &roles, const QVariantList &grants)
{
    if (!canSave() || !m_invitationsError.isEmpty())
        return;
    const QString trimmed = email.trimmed();
    static const QRegularExpression pattern(QStringLiteral("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"));
    if (!pattern.match(trimmed).hasMatch()) {
        m_errorCode = QStringLiteral("invalid_email");
        emit changed();
        return;
    }
    QJsonObject body{{QStringLiteral("email"), trimmed}, {QStringLiteral("roles"), QJsonArray::fromStringList(roles)}};
    if (!grants.isEmpty()) body.insert(QStringLiteral("grants"), QJsonArray::fromVariantList(grants));
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("invitations")), body,
                        idempotencyHeader(), saved(QStringLiteral("invited")));
}

QVariantMap OrgAdmin::invitation(const QString &invitationId) const
{
    for (const QJsonValue &value : m_invitationRows) {
        const QJsonObject row = value.toObject();
        if (jsonId(row.value(QStringLiteral("id"))) != invitationId)
            continue;
        const QDateTime expires = QDateTime::fromString(row.value(QStringLiteral("expires_at")).toString(), Qt::ISODate);
        QVariantList spaces;
        for (const QJsonValue &grant : row.value(QStringLiteral("grants")).toArray()) {
            const QString spaceId = jsonId(grant.toObject().value(QStringLiteral("space_id")));
            QStringList roleIds;
            for (const QJsonValue &role : grant.toObject().value(QStringLiteral("role_ids")).toArray())
                roleIds.append(jsonId(role));
            spaces.append(QVariantMap{{QStringLiteral("spaceId"), spaceId},
                                      {QStringLiteral("name"), m_session.spaces()->nameOf(spaceId)},
                                      {QStringLiteral("roleIds"), roleIds}});
        }
        return {{QStringLiteral("id"), invitationId},
                {QStringLiteral("label"), memberLabel(row)},
                {QStringLiteral("roles"), row.value(QStringLiteral("roles")).toArray().toVariantList()},
                {QStringLiteral("status"), invitationState(row, expires)},
                {QStringLiteral("expiresAt"), shortDate(expires)},
                {QStringLiteral("spaces"), spaces}};
    }
    return {};
}

void OrgAdmin::createMember(const QString &username, const QString &name, const QStringList &roles,
                            const QString &password)
{
    if (!canSave() || !m_membersError.isEmpty())
        return;
    QJsonObject body{{QStringLiteral("username"), username.trimmed()}, {QStringLiteral("roles"), QJsonArray::fromStringList(roles)}};
    if (!name.trimmed().isEmpty()) body.insert(QStringLiteral("name"), name.trimmed());
    if (!password.isEmpty()) body.insert(QStringLiteral("password"), password);
    m_setup = {};
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("members")), body, idempotencyHeader(),
                         keepingSetup(QStringLiteral("member_created")));
}

void OrgAdmin::issueSetupCode(const QString &memberId)
{
    if (!canSave() || !hasRow(m_memberRows, memberId))
        return;
    m_setup = {};
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("members/%1/setup-code").arg(memberId)), {}, idempotencyHeader(),
                         keepingSetup(QStringLiteral("setup_code_issued")));
}

void OrgAdmin::clearSetupCode()
{
    if (m_setup.isEmpty())
        return;
    m_setup = {};
    emit changed();
}

Client::Done OrgAdmin::keepingSetup(const QString &notice)
{
    const Client::Done done = saved(notice);
    const int generation = m_generation;
    return [this, generation, done](const Client::Reply &reply) {
        const QString code = reply.json.value(QStringLiteral("setup_code")).toString();
        if (reply.ok && live(generation) && !code.isEmpty())
            m_setup = {{QStringLiteral("code"), code},
                       {QStringLiteral("expiresAt"), shortDate(QDateTime::fromString(
                               reply.json.value(QStringLiteral("setup_code_expires_at")).toString(), Qt::ISODate))}};
        done(reply);
    };
}

void OrgAdmin::removeMember(const QString &memberId)
{
    if (!canSave() || !hasRow(m_memberRows, memberId))
        return;
    m_session.authedDelete(orgPath(m_orgId, QStringLiteral("members/%1").arg(memberId)),
                          idempotencyHeader(), saved(QStringLiteral("removed")));
}

void OrgAdmin::cancelInvitation(const QString &invitationId)
{
    if (!canSave() || !hasRow(m_invitationRows, invitationId))
        return;
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("invitations/%1/cancel").arg(invitationId)),
                        {}, idempotencyHeader(), saved(QStringLiteral("canceled")));
}

} // namespace matome
