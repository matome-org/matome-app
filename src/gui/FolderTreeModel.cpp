#include "FolderTreeModel.h"

#include "Session.h"

namespace matome {

FolderTreeModel::FolderTreeModel(Session &session)
    : ViewModel(QMetaEnum::fromType<Role>(), 1, &session)
    , m_session(session)
{
}

void FolderTreeModel::toggle(const QString &folderId)
{
    if (!m_expanded.remove(folderId))
        m_expanded.insert(folderId);
    refresh();
}

bool FolderTreeModel::hasSubfolders(const QString &folderId) const
{
    for (const FolderRow &row : m_session.folders()->all()) {
        if (row.parentId == folderId)
            return true;
    }
    return false;
}

void FolderTreeModel::addChildren(QList<QVariantList> &rows, const QString &parentId,
                                  int depth) const
{
    for (const FolderRow &row : m_session.folders()->all()) {
        if (row.parentId != parentId)
            continue;
        const bool expanded = m_expanded.contains(row.id);
        rows.append({row.id, row.name, depth, hasSubfolders(row.id), expanded, row.id == m_folderId});
        if (expanded)
            addChildren(rows, row.id, depth + 1);
    }
}

void FolderTreeModel::refresh()
{
    const QString spaceId = m_session.currentSpaceId();
    if (spaceId != m_spaceId) {
        m_spaceId = spaceId;
        m_folderId.clear();
        m_expanded.clear();
    }
    const QString folderId = m_session.currentFolderId();
    if (folderId != m_folderId) {
        const QVector<FolderRow> path = m_session.folders()->path();
        for (const FolderRow &row : path)
            m_expanded.insert(row.id);
        // A folder restored before its space loaded opens once the list arrives.
        if (folderId.isEmpty() || !path.isEmpty())
            m_folderId = folderId;
    }

    QList<QVariantList> rows;
    if (!spaceId.isEmpty()) {
        rows.append({QString(), m_session.spaces()->nameOf(spaceId), 0, hasSubfolders(QString()), true,
                     m_folderId.isEmpty()});
        addChildren(rows, QString(), 1);
    }
    apply(spaceId, rows);
}

} // namespace matome
