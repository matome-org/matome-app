#pragma once

#include "Client.h"

#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>
#include <QVector>

namespace matome {

class Session;

struct OrgRow {
    QString id;
    QString name;
    QString role;
    int revision = 1;
};

/// Organizations of the signed-in identity. QML binds roles; it does not
/// parse the Core JSON.
class OrgModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        OrgIdRole = Qt::UserRole + 1,
        NameRole,
        RoleNameRole,
        RevisionRole
    };

    explicit OrgModel(Session &session);

    bool busy() const { return m_busy; }
    QString errorCode() const { return m_errorCode; }
    QString currentOrgId() const { return m_currentOrgId; }
    QString nameOf(const QString &orgId) const;
    QString roleOf(const QString &orgId) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reload();
    void create(const QString &name);
    void select(const QString &orgId);
    void clearCurrent();
    void clear();

signals:
    void changed();

private:
    const OrgRow *find(const QString &orgId) const;
    void setBusy();
    void fail(const QString &code);
    void applyList(const Client::Reply &reply, const QJsonArray &list);
    static OrgRow parseRow(const QJsonObject &json);

    Session &m_session;
    QVector<OrgRow> m_rows;
    QString m_currentOrgId;
    QString m_errorCode;
    bool m_busy = false;
    int m_generation = 0;
};

} // namespace matome
