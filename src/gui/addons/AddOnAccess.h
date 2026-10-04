#pragma once

#include "addons/AddOnManager.h"

#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// The roles an add-on brings, for the current organization: before a pause
/// or an uninstall, who holds them is counted from the grants on the
/// organization's spaces, where an installed add-on is available.
class AddOnAccess : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QVariantMap impact READ impact NOTIFY changed)

public:
    AddOnAccess(Session &session, AddOnManager &addOns);
    bool busy() const { return m_pending > 0; }
    /// What `measure` counted: `{key, known, holders, spaces, roles}`.
    /// `holders` counts people and groups holding a role of the add-on,
    /// `spaces` the spaces where one is held, and `roles` maps each role
    /// key held to its holders; `known` is false until the count is complete.
    QVariantMap impact() const { return m_impact; }

    /// Counts who holds the roles `key` adds in the organization's spaces.
    Q_INVOKABLE void measure(const QString &key);

signals:
    void changed();

private:
    bool live(int generation) const { return generation == m_generation; }

    Session &m_session;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId;
    int m_generation = 0, m_pending = 0;
    QVariantMap m_impact;
};
}
