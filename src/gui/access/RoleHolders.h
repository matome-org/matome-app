#pragma once

#include "access/AccessDirectory.h"
#include "access/PlaceNames.h"

#include <QJsonArray>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// Who holds one role of the current organization, for its page in
/// Settings: the people and groups it is given to across the organization,
/// and the grants of it on spaces, folders, documents, and tags whose access
/// the signed-in person may read. It gives the role to more people and
/// groups, across the organization or in a space, and takes it back.
class RoleHolders : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString roleId READ roleId NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QVariantList holders READ holders NOTIFY listsChanged)
    Q_PROPERTY(QStringList assigned READ assigned NOTIFY listsChanged)

public:
    RoleHolders(Session &session, AccessDirectory &directory, PlaceNames &places, AddOnBackend &backend);
    bool active() const { return !m_roleId.isEmpty(); }
    bool busy() const { return m_reading > 0 || m_writing > 0; }
    /// The role open; empty while closed.
    QString roleId() const { return m_roleId; }
    QString errorCode() const { return m_errorCode; }
    QString notice() const { return m_notice; }
    /// One row per holding, in Core's order: `{key, id, kind, principal,
    /// principalKind, principalName, principalKey, idle}`, `kind` being
    /// "assignment" or "grant", `idle` for an assignment of a place-only
    /// role, which does nothing across the organization, `id` the assignment's or the grant's, `key`
    /// both, and `principal` "user:<membership>", "group:<id>", or, on a
    /// tag, "role:<id>" whose key is `principalKey`.
    /// A grant also carries its place: `{resourceKind, resourceId, spaceId,
    /// name, spaceName}`, `resourceKind` one of "space", "folder",
    /// "document", and "tag".
    QVariantList holders() const;
    /// The principals the role is given to across the organization.
    QStringList assigned() const;

    /// Reads who holds `roleId`; again when it is already open.
    Q_INVOKABLE void open(const QString &roleId);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    /// Gives the role across the organization to each of `principals`
    /// ("user:<membership>" or "group:<id>") not holding it yet, then reads
    /// the holders again.
    Q_INVOKABLE void add(const QStringList &principals);
    /// Grants the role in the space `spaceId` to each of `principals` not
    /// holding it there yet, then reads the holders again.
    Q_INVOKABLE void grant(const QStringList &principals, const QString &spaceId);
    /// Takes back the holdings `keys` name: an assignment across the
    /// organization or a grant on its place.
    Q_INVOKABLE void remove(const QStringList &keys);

signals:
    void changed();
    /// The holders or assigned principals differ from before.
    void listsChanged();
    /// A change gave or took back the role, in part or in full.
    void rolesChanged();

private:
    bool live(int generation) const { return active() && generation == m_generation; }
    bool stillOpen(int opened) const { return active() && opened == m_opened; }
    /// Sends `steps` at once, reads the holders again, and says `notice`
    /// when all landed.
    void write(const QList<AddOnBackend::Step> &steps, const QString &notice);

    Session &m_session;
    AccessDirectory &m_directory;
    PlaceNames &m_places;
    AddOnBackend &m_backend;
    QString m_orgId, m_roleId, m_errorCode, m_notice;
    /// `m_generation` counts reads, `m_opened` the roles opened.
    int m_generation = 0, m_opened = 0, m_reading = 0, m_writing = 0;
    QJsonArray m_rows;
    /// The lists last notified, as compact JSON.
    QByteArray m_listed;
};
}
