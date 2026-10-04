#pragma once

#include "access/AccessDirectory.h"
#include "access/PlaceNames.h"

#include <QHash>
#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// Who has access to one resource of the current organization: a space, a
/// folder, a document, or a tag. Access is read and set as the roles each
/// person or group holds there, a holder's roles replaced in one request. A
/// folder or document also shows the access it inherits from its space and
/// the folders above it, and may stop inheriting it. A tag grant lets its
/// holders see documents with that tag.
class AccessGrants : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString kind READ kind NOTIFY changed)
    Q_PROPERTY(QString spaceId READ spaceId NOTIFY changed)
    Q_PROPERTY(QString targetId READ targetId NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QVariantList holders READ holders NOTIFY listsChanged)
    Q_PROPERTY(QVariantList inherited READ inherited NOTIFY listsChanged)
    Q_PROPERTY(QVariantList principals READ principals NOTIFY listsChanged)
    Q_PROPERTY(QVariantMap summary READ summary NOTIFY listsChanged)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    AccessGrants(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend);
    bool active() const { return !m_kind.isEmpty(); }
    bool busy() const { return m_pending > 0 || m_checking > 0 || m_directory.busy(); }
    /// "space", "folder", "document", or "tag".
    QString kind() const { return m_kind; }
    /// The space of what is open; empty for a tag.
    QString spaceId() const { return m_spaceId; }
    QString targetId() const { return m_targetId; }
    QString name() const { return m_name; }
    /// One row per person, group, or role principal holding a grant here:
    /// `{principal, principalKind, principalName, principalKey}` and the
    /// roles they hold, as `AccessDirectory::holding`.
    QVariantList holders() const;
    /// The access a folder or document inherits, one row per holder and
    /// place it comes from, the space first, then the folders outermost
    /// first: a `holders` row with `{sourceKind, sourceId, sourceName,
    /// scope}`, `scope` "manage" for a grant above a break in inheritance,
    /// which only manages access here, else "full".
    QVariantList inherited() const;
    /// How a space, folder, or document is reached, from Core's access
    /// summary: `{visibility, inheritance, breakKind, breakName,
    /// openToMembers, openKind, openName}`. `inheritance` is the resource's
    /// own ("open", "restricted", or empty while it inherits); `break*` names
    /// the deepest folder or document that stops inheriting, and `open*`
    /// where every member except guests reads it from, while
    /// `openToMembers`. Empty for a tag.
    QVariantMap summary() const;
    /// Who a grant here may name: people and groups, and roles on a tag.
    QVariantList principals() const { return m_directory.principals(m_kind == QLatin1String("tag")); }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    /// "user:…", "group:…", or "role:…": who holds `grant`.
    static QString principalOf(const QJsonObject &grant);

    /// Opens the grants of `kind` `targetId` (in `spaceId` unless a tag),
    /// shown as `name`, with the directory that names their holders.
    Q_INVOKABLE void open(const QString &kind, const QString &spaceId, const QString &targetId, const QString &name);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Leaves exactly the active roles `roleIds` granted to `principal`
    /// ("user:…", "group:…", or "role:…" on a tag) here; none removes its
    /// access here.
    Q_INVOKABLE void setRoles(const QString &principal, const QStringList &roleIds);
    /// Removes every active role granted here to each of `principals`.
    Q_INVOKABLE void remove(const QStringList &principals);
    /// Gives each of `principals` the roles `roleIds` here beside those it
    /// holds, one request per principal that lacks one of them.
    Q_INVOKABLE void add(const QStringList &principals, const QStringList &roleIds);
    /// Sets how the open folder or document inherits access: "inherit",
    /// "restricted" (only access given here and below), or "open" (every
    /// member except guests also reads it), from inheriting or between
    /// restricted and open. Core copies no grant.
    Q_INVOKABLE void setInheritance(const QString &inheritance);
    /// Reads the organization roles of the groups the member `membershipId`
    /// is in and, on a document with tags, their own, which `explain` counts
    /// once they land.
    Q_INVOKABLE void check(const QString &membershipId);
    /// What the member `membershipId` may do here and why, from the access
    /// listed here, their groups, and their built-in organization roles,
    /// held directly or, once `check` read them, through a group:
    /// `{actions, reasons}`. `actions` are the action keys they hold here;
    /// each reason is `{kind, roleKey, roleName, via, sourceKind,
    /// sourceName, scope}`, `kind` being "grant" (a role given to them or,
    /// with `via`, to a group of theirs), "open" (every member except guests
    /// reads it), or "organization" (owners and administrators manage
    /// access everywhere; `via` the group that makes them one), or "tag" (a
    /// restricted tag on the document, its name as `sourceName`, `held`
    /// when a grant on it reaches them). A restricted tag no grant of theirs
    /// reaches hides the document, and every action on it, from them.
    Q_INVOKABLE QVariantMap explain(const QString &membershipId) const;

signals:
    void changed();
    /// The holders, inherited access, principals, or summary differ from before.
    void listsChanged();

private:
    QString path(const QString &leaf) const;
    void readTags(int generation);
    QVariantMap holder(const QString &principal, const QJsonArray &grants) const;
    QStringList heldRoles(const QString &principal) const;
    bool grantable(const QString &principal) const;
    bool live(int generation) const { return active() && generation == m_generation; }
    /// Replaces the roles of each principal named in `roles` at once, and
    /// says `notice` once every request landed.
    void write(const QList<std::pair<QString, QStringList>> &roles, const QString &notice);

    Session &m_session;
    AccessDirectory &m_directory;
    PlaceNames &m_places;
    AddOnBackend &m_backend;
    QString m_orgId, m_kind, m_spaceId, m_targetId, m_name, m_errorCode, m_notice;
    int m_generation = 0, m_pending = 0, m_checking = 0;
    /// The role ids each person or group holds across the organization, by
    /// principal, as `check` read them.
    QHash<QString, QStringList> m_principalRoles;
    /// The grants on each tag on the open document, by tag id.
    QHash<QString, QJsonArray> m_tagGrants;
    /// The grants on the resource itself, and those it inherits.
    QJsonArray m_grants, m_inherited;
    /// Core's access summary of the resource.
    QJsonObject m_summary;
    /// The lists last notified, as compact JSON.
    QByteArray m_listed;
};
}
