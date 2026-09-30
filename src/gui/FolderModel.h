#pragma once

#include "Client.h"

#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>
#include <QVector>

namespace matome {

class Session;

struct FolderRow {
    QString id;
    QString parentId;
    QString name;
    int revision = 1;
};

/// Child folders of the current folder; the entry list and folder tree read it.
class FolderModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        FolderIdRole = Qt::UserRole + 1,
        ParentIdRole,
        NameRole,
        RevisionRole
    };

    explicit FolderModel(Session &session);

    bool busy() const { return m_busy; }
    QString errorCode() const { return m_errorCode; }
    QString currentFolderId() const { return m_currentFolderId; }
    QString parentFolderId() const { return parentOf(m_currentFolderId); }
    QString parentOf(const QString &folderId) const;
    const QVector<FolderRow> &all() const { return m_all; }
    QVector<FolderRow> path() const;
    QString nameOf(const QString &folderId) const;
    /// The names from the space root down to `folderId`, as far as they are known.
    QStringList namesTo(const QString &folderId) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    /// Lists again; a list that lands then reports `settled` (nothing when empty).
    void reload(const QString &settled = QString());
    void create(const QString &name);
    void open(const QString &folderId);
    void move(const QString &folderId, const QString &parentId, int revision);
    void rename(const QString &folderId, const QString &name, int revision);
    void remove(const QString &folderId, int revision);
    void clear();

signals:
    void changed();

private:
    QVector<FolderRow> visible() const;
    const FolderRow *find(const QString &folderId) const;
    bool isDescendant(const QString &folderId, const QString &maybeAncestor) const;
    void setBusy();
    void fail(const QString &code);
    void finish(int generation, const Client::Reply &reply);
    void applyList(const Client::Reply &reply, const QJsonArray &list, const QString &settled);
    static FolderRow parseRow(const QJsonObject &json);

    Session &m_session;
    QVector<FolderRow> m_all;
    QString m_currentFolderId;
    QString m_errorCode;
    bool m_busy = false;
    int m_generation = 0;
};

} // namespace matome
