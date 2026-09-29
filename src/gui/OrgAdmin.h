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
    enum Role { PersonIdRole = Qt::UserRole + 1, EmailRole, RoleNameRole, StatusRole, ExpiresAtRole };
    Q_ENUM(Role)

    explicit OrgPeopleModel(QObject *parent);
    void replace(const QString &orgId, const QJsonArray &rows, bool invitations);
};

class OrgAdmin : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QString generalError READ generalError NOTIFY changed)
    Q_PROPERTY(QString membersError READ membersError NOTIFY changed)
    Q_PROPERTY(QString invitationsError READ invitationsError NOTIFY changed)
    Q_PROPERTY(QString usageError READ usageError NOTIFY changed)
    Q_PROPERTY(QAbstractListModel *members READ members CONSTANT)
    Q_PROPERTY(QAbstractListModel *invitations READ invitations CONSTANT)
    Q_PROPERTY(QVariantList roles READ roles NOTIFY rolesChanged)
    Q_PROPERTY(QVariantList usage READ usage NOTIFY changed)
    Q_PROPERTY(QString plan READ plan NOTIFY changed)

public:
    explicit OrgAdmin(Session &session);
    bool available() const;
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0 || m_saving; }
    QString name() const { return m_organization.value(QStringLiteral("name")).toString(); }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    QString generalError() const { return m_generalError; }
    QString membersError() const { return m_membersError; }
    QString invitationsError() const { return m_invitationsError; }
    QString usageError() const { return m_usageError; }
    QString plan() const;
    QAbstractListModel *members() { return &m_members; }
    QAbstractListModel *invitations() { return &m_invitations; }
    QVariantList roles() const;
    QVariantList usage() const;

    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void rename(const QString &name);
    Q_INVOKABLE void invite(const QString &email, const QString &role);
    Q_INVOKABLE void changeRole(const QString &memberId, const QString &role);
    Q_INVOKABLE void removeMember(const QString &memberId);
    Q_INVOKABLE void cancelInvitation(const QString &invitationId);

signals:
    void changed();
    void rolesChanged();
    void invitationSent();

private:
    void sync();
    void load();
    void finished();
    bool live(int generation) const;
    bool canSave() const;
    Client::Done saved(const QString &notice);
    bool hasRow(const QJsonArray &rows, const QString &id) const;

    Session &m_session;
    OrgPeopleModel m_members;
    OrgPeopleModel m_invitations;
    QJsonArray m_memberRows;
    QJsonArray m_invitationRows;
    QJsonObject m_organization;
    QJsonObject m_usage;
    QJsonObject m_entitlements;
    QVariantList m_lastRoles;
    QString m_orgId;
    QString m_errorCode;
    QString m_notice;
    QString m_generalError;
    QString m_membersError;
    QString m_invitationsError;
    QString m_usageError;
    bool m_active = false;
    bool m_saving = false;
    int m_generation = 0;
    int m_pending = 0;
};

} // namespace matome
