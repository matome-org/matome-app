#pragma once

#include "addons/AddOnBackend.h"

#include <QHash>
#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// The current organization's access directory: its people, groups and their
/// members, roles with the action catalog they pick from, and tags; it also
/// renames and archives spaces. Settings manages it; resource grants read
/// names and roles from it.
class AccessDirectory : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QVariantList members READ members NOTIFY listsChanged)
    Q_PROPERTY(QVariantList groups READ groups NOTIFY listsChanged)
    Q_PROPERTY(QVariantList roles READ roles NOTIFY listsChanged)
    Q_PROPERTY(QVariantList catalog READ catalog NOTIFY listsChanged)
    Q_PROPERTY(QVariantList tags READ tags NOTIFY listsChanged)
    Q_PROPERTY(QVariantList assignableRoles READ assignableRoles NOTIFY listsChanged)
    Q_PROPERTY(QVariantList grantableRoles READ grantableRoles NOTIFY listsChanged)

public:
    AccessDirectory(Session &session, AddOnBackend &backend);
    bool active() const { return !m_orgId.isEmpty(); }
    bool busy() const { return m_reading > 0 || m_writing > 0; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    /// Active members: `{id, label, email, username, name, managed, roles}`,
    /// `id` being the membership, `label` as `memberLabel` names them,
    /// `managed` whether the organization manages the account, and `roles`
    /// the built-in organization roles they hold directly.
    QVariantList members() const;
    /// `{id, name, revision, members}`, each member `{id, label}`.
    QVariantList groups() const;
    /// Every active role: `{id, key, name, origin, custom, actions,
    /// assignable, placeOnly, appliesTo}`. `placeOnly` roles work only
    /// granted on a space, folder, document, or tag: no built-in
    /// organization role, they hold an action Core reads only from a grant on
    /// the place (the catalog's `resource_grant`) and no organization action.
    /// `assignable` roles may be given to a person or group across the
    /// organization: the built-in organization roles, and the custom and
    /// add-on roles but the place-only ones. `appliesTo` is "organization"
    /// for the built-in organization roles and for others holding an
    /// organization action by the catalog's axes, else "space".
    QVariantList roles() const;
    /// The actions a custom role may carry: `{key, axis, area}`, from the
    /// organization's catalog as `Permissions` read it.
    QVariantList catalog() const;
    /// The editor area of a catalog action: an add-on's actions
    /// (`addon.<product>.<verb>`) form one area per product.
    static QString actionArea(const QJsonObject &action);
    /// `{id, name, access_controlled, revision}`.
    QVariantList tags() const;
    /// The `assignable` roles, as `roles` rows: the built-in organization
    /// roles in Core's order of reach, then the custom and add-on roles.
    QVariantList assignableRoles() const;
    /// The roles a grant on a space, folder, document, or tag may carry, as
    /// `roles` rows: the built-in space roles, atomic then broad, then the
    /// add-on roles, then the custom roles.
    QVariantList grantableRoles() const;

    /// "user:<membership>", "group:<id>" or "role:<id>" as people read it.
    QString principalName(const QString &principal) const;
    QString tagName(const QString &tagId) const;
    QJsonObject role(const QString &roleId) const;
    /// Whether the active role `roleId` is place-only, as `roles` says.
    bool placeOnly(const QString &roleId) const;
    /// People and groups, and roles when `withRoles`, as
    /// `{value, label, kind}` with `value` a principal.
    QVariantList principals(bool withRoles) const;

    /// The roles one holder's `grants` on one resource carry: `{roles,
    /// roleIds, archived}`, `roles` being `{id, key, name}` of each active
    /// role in grant order. `archived` holds the keys of archived roles,
    /// which Core lists only on tags, where they still grant.
    QVariantMap holding(const QJsonArray &grants) const;
    /// The path of `leaf` below the space, folder, document, or tag `kind`
    /// `id` of `orgId`, in `spaceId` unless a tag.
    static QString resourcePath(const QString &orgId, const QString &kind, const QString &spaceId, const QString &id,
                                const QString &leaf);
    /// The field that names a principal of `kind` ("user", "group", or
    /// "role") in a grant or a principal role.
    static QString principalFieldName(const QString &kind);
    /// That field for `principal` ("user:…", "group:…", or "role:…"), with
    /// its id.
    static QJsonObject principalField(const QString &principal);
    /// The request that grants `roleId` to `principal` on `kind` `id`.
    static AddOnBackend::Step grantStep(const QString &orgId, const QString &kind, const QString &spaceId, const QString &id,
                                        const QString &principal, const QString &roleId);
    /// Loads the directory of the current organization, again when open,
    /// with every catalog `Permissions` reads.
    Q_INVOKABLE void open();
    Q_INVOKABLE void close();
    Q_INVOKABLE void createRole(const QString &name, const QStringList &actions);
    Q_INVOKABLE void updateRole(const QString &roleId, const QString &name, const QStringList &actions);
    Q_INVOKABLE void archiveRole(const QString &roleId);
    Q_INVOKABLE void createGroup(const QString &name);
    Q_INVOKABLE void renameGroup(const QString &groupId, const QString &name);
    Q_INVOKABLE void archiveGroup(const QString &groupId);
    /// Leaves group `groupId` with exactly the members `membershipIds`.
    Q_INVOKABLE void setGroupMembers(const QString &groupId, const QStringList &membershipIds);
    /// Leaves member `membershipId` in exactly the groups `groupIds`.
    Q_INVOKABLE void setMemberGroups(const QString &membershipId, const QStringList &groupIds);
    Q_INVOKABLE void createTag(const QString &name, bool controlled);
    Q_INVOKABLE void updateTag(const QString &tagId, const QString &name, bool controlled);
    Q_INVOKABLE void archiveTag(const QString &tagId);
    /// Renames the space `spaceId`; Session reads its spaces again once it
    /// lands.
    Q_INVOKABLE void renameSpace(const QString &spaceId, const QString &name);
    /// Archives the space `spaceId`, which stays listed, read only.
    Q_INVOKABLE void archiveSpace(const QString &spaceId);

signals:
    void changed();
    /// The lists changed: once a load ends with other rows than before, so
    /// a reload with nothing new leaves the rows shown as they are.
    void listsChanged();
    /// A change landed; `id` names what it created, when it created one.
    void saved(const QString &notice, const QString &id);

private:
    bool live(int generation) const { return active() && generation == m_generation; }
    /// The catalog's rows by action key.
    QHash<QString, QJsonObject> described() const;
    static bool placeOnly(const QJsonObject &role, const QHash<QString, QJsonObject> &described);
    /// Whether the organization a change began in is still open.
    bool stillOpen(int opened) const { return active() && opened == m_opened; }
    void load();
    /// Says the lists changed when what the load read differs.
    void publish();
    QStringList groupMembers(const QString &groupId) const;
    void finished(const Client::Reply &reply);
    /// Sends `steps`, whose paths are below the organization, at once; once
    /// all have answered, reads the directory again, and says `notice` when
    /// all landed. `createdKey` names the object the first step created.
    void change(QList<AddOnBackend::Step> steps, const QString &notice, const QString &createdKey = {});

    Session &m_session;
    AddOnBackend &m_backend;
    QString m_orgId, m_errorCode, m_notice;
    /// `m_generation` counts loads, `m_opened` the organizations opened.
    int m_generation = 0, m_opened = 0, m_reading = 0, m_writing = 0;
    QJsonArray m_members, m_groups, m_roles, m_tags;
    QHash<QString, QJsonArray> m_groupMembers;
    /// The lists last published, as compact JSON.
    QByteArray m_listed;
};
}
