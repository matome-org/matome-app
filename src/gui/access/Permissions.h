#pragma once

#include "addons/AddOnBackend.h"

#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// What the signed-in person may do, as Core's action catalog judges it: in
/// each of their organizations, and in the spaces of the current one that
/// are watched, the explorer's always among them, with the add-ons each of
/// those spaces lists where the person may read them. It explains a
/// refusal there: what is missing, and the command that fixes it.
class Permissions : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    Permissions(Session &session, AddOnBackend &backend);
    /// Counts what changed; a binding that reads it follows every answer.
    int revision() const { return m_revision; }

    /// Whether the catalog of organization `orgId` is read.
    Q_INVOKABLE bool known(const QString &orgId) const { return m_organizations.contains(orgId); }
    /// Whether the person holds the organization action `action` in `orgId`.
    Q_INVOKABLE bool allows(const QString &orgId, const QString &action) const;
    /// The Settings sections of `orgId` the person may open, each named by
    /// the actions that manage it: "general", "members", "groups", "roles",
    /// "spaces", "tags", "usage", "billing", and "addons".
    Q_INVOKABLE QStringList sections(const QString &orgId) const;
    /// Every action of the current organization's catalog, as Core lists it:
    /// `{key, axis, token_scope, resource_grant, product_key, capability,
    /// system_only, allowed}`.
    QJsonArray catalog() const { return m_catalogs.value(m_orgId); }
    /// The catalog row of `action` in the current organization.
    QJsonObject descriptor(const QString &action) const;

    /// Reads the catalog of `spaceId` of the current organization unless it
    /// is read.
    Q_INVOKABLE void watch(const QString &spaceId);
    /// Reads every catalog again, and the add-ons of the spaces watched.
    Q_INVOKABLE void reload();
    /// Reads the catalog of each organization listed that is not read yet.
    void readOrganizations();
    /// False only when the catalog of `spaceId` speaks for the space and
    /// refuses `action`. It speaks once it allows listing content there:
    /// access held only on folders or documents leaves Core to decide.
    bool spaceAllows(const QString &spaceId, const QString &action) const;
    /// True only when the catalog of `spaceId` speaks for the space and
    /// grants `action`.
    bool spaceGrants(const QString &spaceId, const QString &action) const;

    /// Why `action` is refused in `spaceId`, or across the current
    /// organization when it is empty, and what fixes it: `{known, allowed,
    /// listed, reason, unsure, product, productName, roles, fix, canFix,
    /// spaceId, spaceName}`. `listed` is whether the catalog lists `action`. `reason` is "plan" (the plan does not include the
    /// add-on), "uninstalled", "paused" (in the organization), "inactive" (in
    /// the space), or "grant" (no role held there has it); `unsure` when the
    /// add-on's activation in the space is not readable. `roles` are `{id,
    /// key, name}` of at most two roles that hold it, the narrowest first:
    /// roles a grant on the space may carry, or roles given across the
    /// organization. `fix` is "plan", "install", "resume", "activate",
    /// "grant" (on the space), or empty, `canFix` whether the person may
    /// carry it out from the Settings section it opens. `known` is false while the catalog is not read.
    Q_INVOKABLE QVariantMap explain(const QString &action, const QString &spaceId) const;

    /// Reads Core's action catalog of `orgId`, judged in `spaceId` when given.
    static void readCatalog(AddOnBackend &backend, const QString &orgId, const QString &spaceId,
                            AddOnBackend::Live live, AddOnBackend::ListDone done);

signals:
    void changed();

private:
    /// What one space's catalog and add-ons say.
    struct Space {
        QSet<QString> allowed;
        /// The space's add-ons by product key, once read.
        QHash<QString, QJsonObject> addOns;
        bool read = false, addOnsRead = false;
    };
    void follow();
    void readOrganization(const QString &orgId);
    void readSpace(const QString &spaceId);
    void bump();

    Session &m_session;
    AddOnBackend &m_backend;
    /// The organization whose spaces are watched.
    QString m_orgId;
    /// `m_generation` counts the readings of organizations' catalogs,
    /// `m_spaceGeneration` those of the spaces of the current one.
    int m_generation = 0, m_spaceGeneration = 0, m_revision = 0;
    /// Each organization's catalog, and the actions it allows at its own
    /// level, by organization id.
    QHash<QString, QJsonArray> m_catalogs;
    QHash<QString, QSet<QString>> m_organizations;
    /// The organizations whose catalog is on its way.
    QSet<QString> m_asking;
    QHash<QString, Space> m_spaces;
};
}
