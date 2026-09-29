#include "OrgAdmin.h"

#include "JsonList.h"
#include "Session.h"

#include <QDateTime>
#include <QLocale>
#include <QRegularExpression>

namespace matome {

OrgPeopleModel::OrgPeopleModel(QObject *parent)
    : ViewModel(QMetaEnum::fromType<Role>(), 1, parent)
{
}

void OrgPeopleModel::replace(const QString &orgId, const QJsonArray &rows, bool invitations)
{
    QList<QVariantList> values;
    for (const QJsonValue &value : rows) {
        const QJsonObject row = value.toObject();
        QString state = row.value(QStringLiteral("status")).toString();
        const QDateTime expires = QDateTime::fromString(
                row.value(QStringLiteral("expires_at")).toString(), Qt::ISODate);
        if (invitations) {
            state = !row.value(QStringLiteral("accepted_at")).isNull()
                            && !row.value(QStringLiteral("accepted_at")).isUndefined()
                    ? QStringLiteral("accepted")
                    : !row.value(QStringLiteral("canceled_at")).isNull()
                                    && !row.value(QStringLiteral("canceled_at")).isUndefined()
                    ? QStringLiteral("canceled")
                    : expires.isValid() && expires <= QDateTime::currentDateTimeUtc()
                    ? QStringLiteral("expired") : QStringLiteral("pending");
        }
        values.append({jsonId(row.value(QStringLiteral("id"))),
                       row.value(QStringLiteral("email")).toString(),
                       row.value(QStringLiteral("role")).toString(), state,
                       expires.isValid() ? QLocale().toString(expires.toLocalTime(), QLocale::ShortFormat)
                                         : QString()});
    }
    apply(orgId, values);
}

OrgAdmin::OrgAdmin(Session &session)
    : QObject(&session), m_session(session), m_members(this), m_invitations(this)
{
    m_lastRoles = roles();
    connect(&session, &Session::changed, this, &OrgAdmin::sync);
}

bool OrgAdmin::available() const
{
    const QString role = m_session.organizations()->roleOf(m_session.currentOrgId());
    return m_session.signedIn() && (role == QLatin1String("owner") || role == QLatin1String("admin"));
}

void OrgAdmin::sync()
{
    const QVariantList choices = roles();
    if (choices != m_lastRoles) {
        m_lastRoles = choices;
        emit rolesChanged();
        m_members.replace(m_orgId, m_memberRows, false);
        m_invitations.replace(m_orgId, m_invitationRows, true);
    }
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
    m_usage = {};
    m_entitlements = {};
    m_memberRows = {};
    m_invitationRows = {};
    m_members.replace({}, {}, false);
    m_invitations.replace({}, {}, true);
    m_errorCode.clear();
    m_notice.clear();
    m_generalError.clear();
    m_membersError.clear();
    m_invitationsError.clear();
    m_usageError.clear();
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
    m_pending = 5;
    m_generalError.clear();
    m_membersError.clear();
    m_invitationsError.clear();
    m_usageError.clear();
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
            model.replace(m_orgId, rows, invitations);
            finished();
        });
    };
    list(QStringLiteral("members"), m_memberRows, m_members, m_membersError, false);
    list(QStringLiteral("invitations"), m_invitationRows, m_invitations, m_invitationsError, true);
    const auto get = [this, generation](const QString &key, QJsonObject &target) {
        m_session.authedGet(orgPath(m_orgId, key), [this, generation, key, &target](const Client::Reply &reply) {
            if (!live(generation))
                return;
            target = reply.ok ? reply.json.value(key).toObject() : QJsonObject();
            if (!reply.ok)
                m_usageError = failCode(reply);
            finished();
        });
    };
    get(QStringLiteral("usage"), m_usage);
    get(QStringLiteral("entitlements"), m_entitlements);
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
            if (notice == QLatin1String("invited"))
                emit invitationSent();
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

void OrgAdmin::invite(const QString &email, const QString &role)
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
    m_session.authedPost(orgPath(m_orgId, QStringLiteral("invitations")),
                        {{QStringLiteral("email"), trimmed}, {QStringLiteral("role"), role}},
                        idempotencyHeader(), saved(QStringLiteral("invited")));
}

void OrgAdmin::changeRole(const QString &memberId, const QString &role)
{
    if (!canSave() || !hasRow(m_memberRows, memberId))
        return;
    m_session.authedPatch(orgPath(m_orgId, QStringLiteral("members/%1").arg(memberId)),
                         {{QStringLiteral("role"), role}}, idempotencyHeader(),
                         saved(QStringLiteral("role_changed")));
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

QVariantList OrgAdmin::roles() const
{
    QVariantList values;
    for (const char *role : {"member", "admin", "owner", "billing", "guest"}) {
        values.append(QVariantMap{{QStringLiteral("value"), QString::fromLatin1(role)},
                                  {QStringLiteral("label"), EntryModel::detailWord(QString::fromLatin1(role))}});
    }
    return values;
}

QString OrgAdmin::plan() const
{
    return m_entitlements.value(QStringLiteral("plan")).toObject().value(QStringLiteral("name")).toString();
}

QVariantList OrgAdmin::usage() const
{
    QVariantList values;
    const QJsonObject dimensions = m_usage.value(QStringLiteral("dimensions")).toObject();
    const QJsonObject limits = m_usage.value(QStringLiteral("limits")).toObject();
    for (const char *key : {"storage_bytes", "members", "guests", "spaces"}) {
        const QString dimension = QString::fromLatin1(key);
        if (!dimensions.contains(dimension))
            continue;
        const QJsonObject amount = dimensions.value(dimension).toObject();
        values.append(QVariantMap{{QStringLiteral("dimension"), dimension},
                                  {QStringLiteral("used"), amount.value(QStringLiteral("confirmed")).toVariant()},
                                  {QStringLiteral("reserved"), amount.value(QStringLiteral("reserved")).toVariant()},
                                  {QStringLiteral("limit"), limits.value(dimension).toVariant()}});
    }
    return values;
}

} // namespace matome
