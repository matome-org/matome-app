#pragma once

#include "Client.h"

#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>
#include <QUrl>
#include <QVector>

namespace matome {

class Session;

struct DocumentRow {
    QString id;
    QString folderId;
    QString title;
    QString byteSize;
    int revision = 1;
};

/// Documents in the current folder; the entry list reads it.
class DocumentModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        DocumentIdRole = Qt::UserRole + 1,
        FolderIdRole,
        TitleRole,
        ByteSizeRole,
        RevisionRole
    };

    explicit DocumentModel(Session &session);

    bool busy() const { return m_busy; }
    QString errorCode() const { return m_errorCode; }
    QString currentDocumentId() const { return m_currentDocumentId; }
    int revisionOf(const QString &documentId) const;
    QString titleOf(const QString &documentId) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// Lists again; a list that lands then reports `settled` (nothing when empty).
    void reload(const QString &settled = QString());
    void select(const QString &documentId);
    void download(const QString &documentId);
    void move(const QString &documentId, const QString &folderId, int revision);
    void rename(const QString &documentId, const QString &title, int revision);
    void trash(const QString &documentId, int revision);
    /// Not busy any more, failed with `errorCode` (none when empty).
    void settle(const QString &errorCode = QString());
    /// Fails with Core's `errorCode`; a stale revision lists again first.
    void refuse(const QString &errorCode);
    void clear();

signals:
    void changed();
    void downloadReady(const QUrl &file);
    /// Core moved `documentId` to the trash, where it is at `revision`.
    void trashed(const QString &documentId, int revision);

private:
    const DocumentRow *find(const QString &documentId) const;
    void setBusy();
    void setRows(const QVector<DocumentRow> &rows);
    void finish(int generation, const Client::Reply &reply);
    void applyList(const Client::Reply &reply, const QJsonArray &list, const QString &settled);
    void saveDownload(const QString &url, const QString &title);
    static DocumentRow parseRow(const QJsonObject &json);

    Session &m_session;
    QVector<DocumentRow> m_rows;
    QString m_currentDocumentId;
    // The space and folder `m_rows` were listed for.
    QString m_listed;
    QString m_errorCode;
    bool m_busy = false;
    int m_generation = 0;
};

} // namespace matome
