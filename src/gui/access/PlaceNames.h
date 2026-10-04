#pragma once

#include "addons/AddOnBackend.h"

#include <QHash>

namespace matome {
class Session;

/// What people call the places access lists point at in the current
/// organization: spaces from the space list, tags from the access
/// directory, folders of the open space from its folder list, and other
/// folders and documents as Core names them, read once each.
class PlaceNames : public QObject
{
    Q_OBJECT

public:
    PlaceNames(Session &session, AddOnBackend &backend);
    /// The name of `kind` ("space", "folder", "document", or "tag") `id`,
    /// in `spaceId` unless a tag; empty while unknown or not readable.
    QString name(const QString &kind, const QString &spaceId, const QString &id) const;
    /// Reads from Core the name of folder or document `id` in `spaceId`
    /// when nothing the app holds names it.
    void want(const QString &kind, const QString &spaceId, const QString &id);

signals:
    void changed();

private:
    Session &m_session;
    AddOnBackend &m_backend;
    QString m_orgId;
    int m_generation = 0;
    /// "folder:<id>" or "document:<id>" to the name Core gave, empty while
    /// read or when Core refused it.
    QHash<QString, QString> m_names;
};
}
