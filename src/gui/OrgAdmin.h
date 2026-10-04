#pragma once

#include "Client.h"
#include "ViewModel.h"

#include <QJsonObject>
#include <QJsonArray>
#include <QObject>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {

class Session;

class OrgPeopleModel : public ViewModel
{
    Q_OBJECT

public:
    /// `LabelRole`: a member's email, else their name or username; an
    /// invitation's email. `RolesRole`: the built-in organization roles held
    /// or offered. `SpacesRole`: the names of the spaces an invitation offers
    /// access to, empty where the space list does not name one.
    enum Role { PersonIdRole = Qt::UserRole + 1, LabelRole, RolesRole, StatusRole, ExpiresAtRole, SpacesRole };
    Q_ENUM(Role)

    explicit OrgPeopleModel(QObject *parent);
    void replace(const QString &orgId, const QJsonArray &rows, bool invitations,
                 const std::function<QString(const QString &)> &spaceName = {});
};

class OrgAdmin : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString slug READ slug NOTIFY changed)
    Q_PROPERTY(QVariantMap setupCode READ setupCode NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QString generalError READ generalError NOTIFY changed)
    Q_PROPERTY(QString membersError READ membersError NOTIFY changed)
    Q_PROPERTY(QString invitationsError READ invitationsError NOTIFY changed)
    Q_PROPERTY(QAbstractListModel *members READ members CONSTANT)
    Q_PROPERTY(QAbstractListModel *invitations READ invitations CONSTANT)

public:
    explicit OrgAdmin(Session &session);
    bool available() const;
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0 || m_saving; }
    QString name() const { return m_organization.value(QStringLiteral("name")).toString(); }
    /// What prefixes the sign-in identifier `org-slug/username` of the
    /// accounts the organization manages.
    QString slug() const { return m_organization.value(QStringLiteral("slug")).toString(); }
    /// The one-time setup code the last `createMember` or `issueSetupCode`
    /// answered, `{code, expiresAt}`, until `clearSetupCode`; empty without.
    QVariantMap setupCode() const { return m_setup; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    QString generalError() const { return m_generalError; }
    QString membersError() const { return m_membersError; }
    QString invitationsError() const { return m_invitationsError; }
    QAbstractListModel *members() { return &m_members; }
    QAbstractListModel *invitations() { return &m_invitations; }

    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void rename(const QString &name);
    /// Invites `email` with the built-in organization `roles`, offering
    /// `grants` (`{space_id, role_ids}` each) that Core gives the new member
    /// on acceptance.
    Q_INVOKABLE void invite(const QString &email, const QStringList &roles, const QVariantList &grants = {});
    /// Invitation `invitationId` as `{id, label, roles, status, expiresAt,
    /// spaces}`, each space `{spaceId, name, roleIds}` it offers; empty when
    /// not listed.
    Q_INVOKABLE QVariantMap invitation(const QString &invitationId) const;
    /// Creates an account the organization manages, signing in as
    /// `org-slug/username`, holding the built-in organization `roles`.
    /// Without `password`, Core answers a one-time setup code (`setupCode`).
    Q_INVOKABLE void createMember(const QString &username, const QString &name, const QStringList &roles,
                                  const QString &password);
    /// Gives member `memberId`'s managed account a new setup code (`setupCode`),
    /// revoking the previous one.
    Q_INVOKABLE void issueSetupCode(const QString &memberId);
    Q_INVOKABLE void clearSetupCode();
    Q_INVOKABLE void removeMember(const QString &memberId);
    Q_INVOKABLE void cancelInvitation(const QString &invitationId);

signals:
    void changed();
    /// A change landed; `notice` names it.
    void changeSaved(const QString &notice);

private:
    void sync();
    void load();
    void finished();
    void replaceInvitations();
    bool live(int generation) const;
    bool canSave() const;
    Client::Done saved(const QString &notice);
    /// `saved`, keeping the setup code the answer carries.
    Client::Done keepingSetup(const QString &notice);
    bool hasRow(const QJsonArray &rows, const QString &id) const;

    Session &m_session;
    OrgPeopleModel m_members;
    OrgPeopleModel m_invitations;
    QJsonArray m_memberRows;
    QJsonArray m_invitationRows;
    QJsonObject m_organization;
    QVariantMap m_setup;
    QString m_orgId;
    QString m_errorCode;
    QString m_notice;
    QString m_generalError;
    QString m_membersError;
    QString m_invitationsError;
    bool m_active = false;
    bool m_saving = false;
    int m_generation = 0;
    int m_pending = 0;
};

} // namespace matome
