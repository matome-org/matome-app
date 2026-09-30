#include "DocumentModel.h"

#include "JsonList.h"
#include "Session.h"

#include <QDir>
#include <QFile>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrl>

#ifdef Q_OS_WASM
#include <QtCore/private/qstdweb_p.h>

#include <emscripten/val.h>
#endif

namespace matome {

DocumentModel::DocumentModel(Session &session)
    : QAbstractListModel(&session)
    , m_session(session)
{
}

const DocumentRow *DocumentModel::find(const QString &documentId) const
{
    for (const DocumentRow &row : m_rows) {
        if (row.id == documentId)
            return &row;
    }
    return nullptr;
}

int DocumentModel::revisionOf(const QString &documentId) const
{
    const DocumentRow *row = find(documentId);
    return row ? row->revision : 0;
}

QString DocumentModel::titleOf(const QString &documentId) const
{
    const DocumentRow *row = find(documentId);
    return row ? row->title : QString();
}

bool DocumentModel::controlledOf(const QString &documentId) const
{
    const DocumentRow *row = find(documentId);
    return row && row->controlled;
}

int DocumentModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant DocumentModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const DocumentRow &row = m_rows.at(index.row());
    switch (role) {
    case DocumentIdRole:
        return row.id;
    case FolderIdRole:
        return row.folderId;
    case TitleRole:
        return row.title;
    case ByteSizeRole:
        return row.byteSize;
    case RevisionRole:
        return row.revision;
    case ControlledRole:
        return row.controlled;
    default:
        return {};
    }
}

QHash<int, QByteArray> DocumentModel::roleNames() const
{
    return {{DocumentIdRole, "documentId"},
            {FolderIdRole, "folderId"},
            {TitleRole, "documentTitle"},
            {ByteSizeRole, "byteSize"},
            {RevisionRole, "revision"},
            {ControlledRole, "controlled"}};
}

void DocumentModel::reload(const QString &settled)
{
    if (!m_session.inSpace()) {
        clear();
        return;
    }
    const QString folderId = m_session.currentFolderId();
    // Another place's rows never stand in for this one's, even if its load fails.
    const QString listed = m_session.currentSpaceId() + QLatin1Char('/') + folderId;
    if (listed != m_listed) {
        setRows({});
        m_listed = listed;
    }
    const int generation = ++m_generation;
    setBusy();
    const QString path = m_session.spacePath(QStringLiteral("documents"))
            + QStringLiteral("?folder_id=")
            + (folderId.isEmpty() ? QStringLiteral("root") : QUrl::toPercentEncoding(folderId));
    m_session.authedList(path, QStringLiteral("documents"),
                         [this, generation] { return generation == m_generation; },
                         [this, settled](const Client::Reply &reply, const QJsonArray &list) {
                             applyList(reply, list, settled);
                         });
}

void DocumentModel::select(const QString &documentId)
{
    if (!find(documentId) || m_currentDocumentId == documentId)
        return;
    m_currentDocumentId = documentId;
    emit changed();
}

void DocumentModel::download(const QString &documentId, const QString &versionId)
{
    if (m_busy || documentId.isEmpty() || !m_session.inSpace())
        return;
    select(documentId);
    const QString title = titleOf(documentId);
    const int generation = ++m_generation;
    setBusy();
    QString path = m_session.spacePath(QStringLiteral("documents/%1/download").arg(documentId));
    if (!versionId.isEmpty())
        path += QStringLiteral("?version_id=") + versionId;
    m_session.authedGet(path, [this, generation, title](const Client::Reply &reply) {
        if (generation != m_generation)
            return;
        if (!reply.ok) {
            settle(failCode(reply));
            return;
        }
        const QString url = reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString();
        if (url.isEmpty()) {
            settle(QStringLiteral("not_found"));
            return;
        }
        saveDownload(url, title);
    });
}

void DocumentModel::saveDownload(const QString &url, const QString &title)
{
    m_session.client()->getRaw(QUrl(url), [this, title](const Client::Reply &reply) {
        if (!reply.ok) {
            settle(failCode(reply));
            return;
        }
#ifdef Q_OS_WASM
        // The page cannot write the visitor's disk: the bytes go to the browser
        // as a download, through a link to them that the page clicks.
        using emscripten::val;
        const qstdweb::Blob blob = qstdweb::Blob::copyFrom(reply.bytes.constData(), reply.bytes.size());
        const val urls = val::global("URL");
        const val href = urls.call<val>("createObjectURL", blob.val());
        const val body = val::global("document")["body"];
        val link = val::global("document").call<val>("createElement", std::string("a"));
        link.set("href", href);
        link.set("download", title.toStdString());
        body.call<void>("appendChild", link);
        link.call<void>("click");
        body.call<void>("removeChild", link);
        urls.call<void>("revokeObjectURL", href);
        settle();
#else
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        QDir().mkpath(dir);
        const QString path = dir + QLatin1Char('/') + title;
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            settle(QStringLiteral("network"));
            return;
        }
        file.write(reply.bytes);
        file.close();
        settle();
        emit downloadReady(QUrl::fromLocalFile(path));
#endif
    });
}

void DocumentModel::move(const QString &documentId, const QString &folderId, int revision)
{
    if (m_busy || documentId.isEmpty() || !m_session.inSpace())
        return;
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("space_id"), m_session.currentSpaceId());
    if (folderId.isEmpty())
        body.insert(QStringLiteral("folder_id"), QJsonValue::Null);
    else
        body.insert(QStringLiteral("folder_id"), folderId);
    const QString path = m_session.spacePath(QStringLiteral("documents/%1/move").arg(documentId));
    m_session.authedPost(path, body, idempotentMatchHeader(revision),
                         [this, generation](const Client::Reply &reply) { finish(generation, reply); });
}

void DocumentModel::rename(const QString &documentId, const QString &title, int revision)
{
    const QString trimmed = title.trimmed();
    if (m_busy || documentId.isEmpty() || !m_session.inSpace())
        return;
    if (trimmed.isEmpty()) {
        settle(QStringLiteral("invalid_request"));
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("title"), trimmed);
    m_session.authedPatch(m_session.spacePath(QStringLiteral("documents/%1").arg(documentId)), body,
                          matchHeader(revision),
                          [this, generation](const Client::Reply &reply) { finish(generation, reply); });
}

void DocumentModel::trash(const QString &documentId, int revision)
{
    if (m_busy || documentId.isEmpty() || !m_session.inSpace())
        return;
    const int generation = ++m_generation;
    setBusy();
    m_session.authedDelete(m_session.spacePath(QStringLiteral("documents/%1").arg(documentId)),
                           matchHeader(revision),
                           [this, generation, documentId](const Client::Reply &reply) {
                               if (reply.ok) {
                                   const QJsonObject document =
                                           reply.json.value(QStringLiteral("document")).toObject();
                                   emit trashed(documentId, document.value(QStringLiteral("revision")).toInt());
                               }
                               finish(generation, reply);
                           });
}

void DocumentModel::clear()
{
    ++m_generation;
    if (m_rows.isEmpty() && !m_busy && m_errorCode.isEmpty() && m_currentDocumentId.isEmpty())
        return;
    setRows({});
    m_listed.clear();
    m_busy = false;
    m_errorCode.clear();
    m_errorDetails = {};
    m_currentDocumentId.clear();
    emit changed();
}

void DocumentModel::setBusy()
{
    m_busy = true;
    m_errorCode.clear();
    m_errorDetails = {};
    emit changed();
}

void DocumentModel::settle(const QString &errorCode)
{
    m_busy = false;
    m_errorCode = errorCode;
    emit changed();
}

void DocumentModel::setRows(const QVector<DocumentRow> &rows)
{
    beginResetModel();
    m_rows = rows;
    endResetModel();
}

void DocumentModel::finish(int generation, const Client::Reply &reply)
{
    if (generation != m_generation)
        return;
    if (!reply.ok) {
        refuse(failCode(reply), reply.json.value(QStringLiteral("details")).toObject());
        return;
    }
    reload();
}

void DocumentModel::refuse(const QString &errorCode, const QJsonObject &details)
{
    m_errorDetails = details;
    if (errorCode == QLatin1String("revision_conflict"))
        reload(errorCode);
    else
        settle(errorCode);
}

void DocumentModel::applyList(const Client::Reply &reply, const QJsonArray &list, const QString &settled)
{
    if (!reply.ok) {
        settle(failCode(reply));
        return;
    }

    QVector<DocumentRow> rows;
    rows.reserve(list.size());
    for (const QJsonValue &value : list) {
        const DocumentRow row = parseRow(value.toObject());
        if (!row.id.isEmpty())
            rows.append(row);
    }

    setRows(rows);

    if (!find(m_currentDocumentId))
        m_currentDocumentId.clear();

    settle(settled);
}

DocumentRow DocumentModel::parseRow(const QJsonObject &json)
{
    DocumentRow row;
    row.id = jsonId(json.value(QStringLiteral("id")));
    row.folderId = jsonId(json.value(QStringLiteral("folder_id")));
    row.title = json.value(QStringLiteral("title")).toString();
    row.controlled = json.value(QStringLiteral("controlled_docs_enabled")).toBool();
    const QJsonValue version = json.value(QStringLiteral("current_version"));
    if (version.isObject())
        row.byteSize = QString::number(version.toObject().value(QStringLiteral("byte_size")).toInteger());
    row.revision = json.value(QStringLiteral("revision")).toInt(1);
    return row;
}

} // namespace matome
