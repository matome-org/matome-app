#pragma once

#include "addons/AddOnManager.h"

#include <QJsonArray>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// The controlled-documents add-on's settings for one space, managed from
/// Settings: the space rule, whether links must pin a version, the review
/// roles the space access can grant, and the explicit grant an organization
/// administrator needs before managing control.
class ControlledRule : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool installed READ installed NOTIFY changed)
    Q_PROPERTY(bool readable READ readable NOTIFY changed)
    Q_PROPERTY(QVariantMap rule READ rule NOTIFY changed)
    Q_PROPERTY(bool rolesMissing READ rolesMissing NOTIFY changed)
    Q_PROPERTY(bool canGrantSelf READ canGrantSelf NOTIFY changed)
    Q_PROPERTY(QString ruleError READ ruleError NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    explicit ControlledRule(Session &session);
    bool active() const { return !m_spaceId.isEmpty(); }
    bool busy() const { return m_pending > 0; }
    /// Whether the add-on is installed for the space, active or paused.
    bool installed() const;
    bool readable() const { return m_ruleError.isEmpty() && m_ruleRead; }
    QVariantMap rule() const { return m_rule.toVariantMap(); }
    bool rolesMissing() const;
    /// The rule is forbidden to this organization administrator, who may
    /// grant themselves management of the space.
    bool canGrantSelf() const;
    QString ruleError() const { return m_ruleError; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }

    Q_INVOKABLE void open(const QString &spaceId);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Saves the rule `active`, keeping or setting whether links must pin a version.
    Q_INVOKABLE void save(bool active, bool requireVersionReferences);
    Q_INVOKABLE void remove(const QString &reason);
    /// Creates the reviewer and management roles the organization lacks.
    Q_INVOKABLE void addRoles();
    Q_INVOKABLE void grantSelf();

signals:
    void changed();
    /// Roles or grants changed: the space access has something new to show.
    void accessChanged();

private:
    enum class Profile { Reviewer, Manager };
    static QJsonArray actions(Profile profile);
    QString roleId(Profile profile) const;
    void createRole(Profile profile, std::function<void(const QString &roleId)> done);
    bool live(int generation) const { return active() && generation == m_generation; }
    void change(const QByteArray &method, const QString &path, const QJsonObject &body,
                const Client::Headers &headers, const QString &notice);
    void finish(const Client::Reply &reply, const QString &notice);

    Session &m_session;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId, m_spaceId, m_membershipId, m_ruleError, m_errorCode, m_notice;
    bool m_ruleRead = false;
    int m_generation = 0, m_pending = 0;
    QJsonObject m_rule;
    QJsonArray m_roles;
};
}
