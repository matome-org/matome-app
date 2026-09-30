#pragma once

#include "addons/AddOnBackend.h"

#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// Who may do what in one space of the current organization, for Settings:
/// the space's role grants, the roles that can be granted in a space, and
/// the members to grant them to.
class SpaceAccess : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString spaceId READ spaceId NOTIFY changed)
    Q_PROPERTY(QVariantList grants READ grants NOTIFY changed)
    Q_PROPERTY(QVariantList roles READ roles NOTIFY changed)
    Q_PROPERTY(QVariantList members READ members NOTIFY changed)
    Q_PROPERTY(QVariantList spaces READ spaces NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    SpaceAccess(Session &session, AddOnBackend &backend);
    bool active() const { return !m_spaceId.isEmpty(); }
    bool busy() const { return m_pending > 0; }
    QString spaceId() const { return m_spaceId; }
    /// Each grant with its member's `email` and its role's `roleName`.
    QVariantList grants() const;
    /// The roles a space grant may carry: every role but the organization's
    /// own (owner, admin, member, billing, guest), as `{value, label}`.
    QVariantList roles() const;
    /// The organization's members as `{value, label}`.
    QVariantList members() const;
    /// The current organization's spaces as `{value, label}`, to pick one.
    QVariantList spaces() const;
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }

    Q_INVOKABLE void open(const QString &spaceId);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void grant(const QString &membershipId, const QString &roleId);
    Q_INVOKABLE void revoke(const QString &grantId);

signals:
    void changed();

private:
    bool live(int generation) const { return active() && generation == m_generation; }
    void change(const QByteArray &method, const QString &path, const QJsonObject &body, const QString &notice);

    Session &m_session;
    AddOnBackend &m_backend;
    QString m_orgId, m_spaceId, m_errorCode, m_notice;
    int m_generation = 0, m_pending = 0;
    QJsonArray m_grants, m_roles, m_members;
};
}
