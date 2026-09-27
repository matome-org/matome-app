#include "FolderModel.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonObject>

namespace matome {

FolderModel::FolderModel(Session &session)
    : QAbstractListModel(&session)
    , m_session(session)
{
}

QVector<FolderRow> FolderModel::visible() const
{
    QVector<FolderRow> rows;
    for (const FolderRow &row : m_all) {
        if (row.parentId == m_currentFolderId)
            rows.append(row);
    }
    return rows;
}

const FolderRow *FolderModel::find(const QString &folderId) const
{
    for (const FolderRow &row : m_all) {
        if (row.id == folderId)
            return &row;
    }
    return nullptr;
}

QString FolderModel::parentOf(const QString &folderId) const
{
    const FolderRow *row = find(folderId);
    return row ? row->parentId : QString();
}

QString FolderModel::nameOf(const QString &folderId) const
{
    const FolderRow *row = find(folderId);
    return row ? row->name : QString();
}

QVector<FolderRow> FolderModel::path() const
{
    QVector<FolderRow> rows;
    // Bounded by the folder count, so a corrupt parent cycle cannot spin.
    for (const FolderRow *row = find(m_currentFolderId); row && rows.size() < m_all.size();
         row = find(row->parentId))
        rows.prepend(*row);
    return rows;
}

bool FolderModel::isDescendant(const QString &folderId, const QString &maybeAncestor) const
{
    QString cursor = folderId;
    while (!cursor.isEmpty()) {
        if (cursor == maybeAncestor)
            return true;
        const QString next = parentOf(cursor);
        if (next == cursor)
            break;
        cursor = next;
    }
    return false;
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : visible().size();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    const QVector<FolderRow> rows = visible();
    if (!index.isValid() || index.row() < 0 || index.row() >= rows.size())
        return {};
    const FolderRow &row = rows.at(index.row());
    switch (role) {
    case FolderIdRole:
        return row.id;
    case ParentIdRole:
        return row.parentId;
    case NameRole:
        return row.name;
    case RevisionRole:
        return row.revision;
    default:
        return {};
    }
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {{FolderIdRole, "folderId"},
            {ParentIdRole, "parentId"},
            {NameRole, "name"},
            {RevisionRole, "revision"}};
}

void FolderModel::reload(const QString &settled)
{
    if (!m_session.inSpace()) {
        clear();
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    m_session.authedList(m_session.spacePath(QStringLiteral("folders")), QStringLiteral("folders"),
                         [this, generation] { return generation == m_generation; },
                         [this, settled](const Client::Reply &reply, const QJsonArray &list) {
                             applyList(reply, list, settled);
                         });
}

void FolderModel::create(const QString &name)
{
    if (m_busy || !m_session.inSpace())
        return;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        fail(QStringLiteral("invalid_request"));
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("name"), trimmed);
    if (!m_currentFolderId.isEmpty())
        body.insert(QStringLiteral("parent_id"), m_currentFolderId);
    m_session.authedPost(m_session.spacePath(QStringLiteral("folders")), body, idempotencyHeader(),
                         [this, generation](const Client::Reply &reply) {
                             if (generation != m_generation)
                                 return;
                             if (!reply.ok) {
                                 fail(failCode(reply));
                                 return;
                             }
                             reload();
                         });
}

void FolderModel::open(const QString &folderId)
{
    // An unknown id waits for the load in flight (here or in the space list);
    // applyList drops it if the folder is not there.
    if (!folderId.isEmpty() && !find(folderId) && !m_busy && !m_session.spaces()->busy())
        return;
    if (m_currentFolderId == folderId)
        return;
    m_currentFolderId = folderId;
    // An error belongs to the folder it happened in.
    m_errorCode.clear();
    emit changed();
}

void FolderModel::move(const QString &folderId, const QString &parentId, int revision)
{
    if (m_busy || folderId.isEmpty() || !m_session.inSpace())
        return;
    if (folderId == parentId || isDescendant(parentId, folderId)) {
        fail(QStringLiteral("folder_cycle"));
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    if (parentId.isEmpty())
        body.insert(QStringLiteral("parent_id"), QJsonValue::Null);
    else
        body.insert(QStringLiteral("parent_id"), parentId);
    const QString path = m_session.spacePath(QStringLiteral("folders/%1/move").arg(folderId));
    m_session.authedPost(path, body, idempotentMatchHeader(revision),
                         [this, generation](const Client::Reply &reply) { finish(generation, reply); });
}

void FolderModel::rename(const QString &folderId, const QString &name, int revision)
{
    const QString trimmed = name.trimmed();
    if (m_busy || folderId.isEmpty() || !m_session.inSpace())
        return;
    if (trimmed.isEmpty()) {
        fail(QStringLiteral("invalid_request"));
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("name"), trimmed);
    m_session.authedPatch(m_session.spacePath(QStringLiteral("folders/%1").arg(folderId)), body,
                          matchHeader(revision),
                          [this, generation](const Client::Reply &reply) { finish(generation, reply); });
}

void FolderModel::remove(const QString &folderId, int revision)
{
    if (m_busy || folderId.isEmpty() || !m_session.inSpace())
        return;
    const int generation = ++m_generation;
    setBusy();
    m_session.authedDelete(m_session.spacePath(QStringLiteral("folders/%1").arg(folderId)),
                           matchHeader(revision),
                           [this, generation](const Client::Reply &reply) { finish(generation, reply); });
}

void FolderModel::clear()
{
    ++m_generation;
    if (m_all.isEmpty() && !m_busy && m_errorCode.isEmpty() && m_currentFolderId.isEmpty())
        return;
    beginResetModel();
    m_all.clear();
    endResetModel();
    m_busy = false;
    m_errorCode.clear();
    m_currentFolderId.clear();
    emit changed();
}

void FolderModel::setBusy()
{
    m_busy = true;
    m_errorCode.clear();
    emit changed();
}

void FolderModel::fail(const QString &code)
{
    m_busy = false;
    m_errorCode = code;
    emit changed();
}

void FolderModel::finish(int generation, const Client::Reply &reply)
{
    if (generation != m_generation)
        return;
    if (!reply.ok) {
        const QString code = failCode(reply);
        if (code == QLatin1String("revision_conflict"))
            reload(code);
        else
            fail(code);
        return;
    }
    reload();
}

void FolderModel::applyList(const Client::Reply &reply, const QJsonArray &list, const QString &settled)
{
    if (!reply.ok) {
        fail(failCode(reply));
        return;
    }

    QVector<FolderRow> rows;
    rows.reserve(list.size());
    for (const QJsonValue &value : list) {
        const FolderRow row = parseRow(value.toObject());
        if (!row.id.isEmpty())
            rows.append(row);
    }

    beginResetModel();
    m_all = rows;
    endResetModel();

    if (!find(m_currentFolderId))
        m_currentFolderId.clear();

    m_busy = false;
    m_errorCode = settled;
    emit changed();
}

FolderRow FolderModel::parseRow(const QJsonObject &json)
{
    FolderRow row;
    row.id = jsonId(json.value(QStringLiteral("id")));
    row.parentId = jsonId(json.value(QStringLiteral("parent_id")));
    row.name = json.value(QStringLiteral("name")).toString();
    row.revision = json.value(QStringLiteral("revision")).toInt(1);
    return row;
}

} // namespace matome
