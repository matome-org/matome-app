#pragma once

#include "access/AccessDirectory.h"
#include "access/PlaceNames.h"

#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// What one person or group of the current organization holds, for their
/// page in Settings: the organization roles given to them, the grants that
/// reach them on spaces, folders, documents, and tags whose access the
/// signed-in person may read, and the places a member reads through their
/// organization roles. It sets their organization roles, grants them roles
/// on a place, and takes back what was given to them.
class PrincipalAccess : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString principal READ principal NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QVariantList rows READ rows NOTIFY listsChanged)
    Q_PROPERTY(QVariantList roles READ roles NOTIFY listsChanged)
    Q_PROPERTY(QStringList roleIds READ roleIds NOTIFY listsChanged)

public:
    PrincipalAccess(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend);
    bool active() const { return !m_principal.isEmpty(); }
    bool busy() const { return m_reading > 0 || m_writing > 0; }
    /// "user:<membership>" or "group:<id>"; empty while closed.
    QString principal() const { return m_principal; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    /// Everything the principal holds, one row each: `{key, kind, id,
    /// roleId, roleKey, roleName, origin, placeKind, placeId, spaceId, name,
    /// spaceName, via, viaKind, viaName, viaKey, direct, idle}`. `kind` is
    /// "assignment" (an organization role, `placeKind` "organization",
    /// `idle` when the role is place-only and so does nothing there),
    /// "grant" (a role on a space, folder, document, or tag), or "open" (a
    /// place a member reads through their organization roles, without a
    /// role or `via`); `id` is the assignment's or the grant's. `via` is the
    /// person, group, or role a grant names, `direct` when that is the
    /// principal itself.
    QVariantList rows() const;
    /// Every organization role assignment of the principal, built-in ones
    /// included: `{id, roleId, roleKey, roleName, origin, actions}`, `id`
    /// being the assignment.
    QVariantList roles() const;
    /// The ids of the roles among `roles`: those `setRoles` sets.
    QStringList roleIds() const;

    /// Reads what `principal` holds; again when it is already open.
    Q_INVOKABLE void open(const QString &principal);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Leaves the principal exactly `roleIds` as organization roles: assigns
    /// the missing ones first, so a member never passes through holding none,
    /// then takes back the others, and reads both lists again.
    Q_INVOKABLE void setRoles(const QStringList &roleIds);
    /// Grants the principal `roleIds` on the space, folder, document, or tag
    /// `kind` `id` (in `spaceId` unless a tag), beside what it holds there.
    Q_INVOKABLE void grant(const QString &kind, const QString &spaceId, const QString &id, const QStringList &roleIds);
    /// Takes back the rows `keys` name that were given to the principal
    /// itself: organization roles and grants.
    Q_INVOKABLE void remove(const QStringList &keys);

signals:
    void changed();
    /// The places, roles, or role ids differ from before.
    void listsChanged();
    /// A change gave or took back roles, in part or in full.
    void rolesChanged();

private:
    bool live(int generation) const { return active() && generation == m_generation; }
    /// Whether the principal a write began for is still open.
    bool stillOpen(int opened) const { return active() && opened == m_opened; }
    void finished(const Client::Reply &reply);
    /// Sends `first` at once, then, once all of it landed, `then`; reads the
    /// lists again and says `notice` when every step landed.
    void write(const QList<AddOnBackend::Step> &first, const QList<AddOnBackend::Step> &then, const QString &notice);
    QVariantMap place(const QJsonObject &resource) const;

    Session &m_session;
    AccessDirectory &m_directory;
    PlaceNames &m_places;
    AddOnBackend &m_backend;
    QString m_orgId, m_principal, m_errorCode, m_notice;
    /// `m_generation` counts reads, `m_opened` the principals opened.
    int m_generation = 0, m_opened = 0, m_reading = 0, m_writing = 0;
    /// The grants reaching the principal, its organization roles, and the
    /// places it reads through them.
    QJsonArray m_access, m_roles, m_open;
    /// The lists last notified, as compact JSON.
    QByteArray m_listed;
};
}
