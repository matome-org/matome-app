#pragma once

#include "ViewModel.h"

#include <QSet>
#include <QString>

namespace matome {

class Session;

/// The folder tree of the current space, flattened to its visible rows. The
/// first row is the space root. Expanded folders stay open while in the space;
/// the path to the current folder opens as it is navigated.
class FolderTreeModel : public ViewModel
{
    Q_OBJECT

public:
    enum Role {
        FolderIdRole = Qt::UserRole + 1,
        NameRole,
        DepthRole,
        HasChildrenRole,
        ExpandedRole,
        CurrentRole
    };
    Q_ENUM(Role)

    explicit FolderTreeModel(Session &session);

    void toggle(const QString &folderId);
    void refresh();

private:
    void addChildren(QList<QVariantList> &rows, const QString &parentId, int depth) const;
    bool hasSubfolders(const QString &folderId) const;

    Session &m_session;
    QString m_spaceId;
    QString m_folderId;
    QSet<QString> m_expanded;
};

} // namespace matome
