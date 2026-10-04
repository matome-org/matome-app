#pragma once

#include "Client.h"

#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>
#include <QVector>

namespace matome {

class Session;

struct SpaceRow {
    QString id;
    QString name;
    QString status;
    int revision = 1;
    int colorIndex = 0;
    bool operator==(const SpaceRow &other) const
    {
        return id == other.id && name == other.name && status == other.status && revision == other.revision
                && colorIndex == other.colorIndex;
    }
};

/// Spaces of the current organization. QML binds roles; it does not parse JSON.
class SpaceModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role {
        SpaceIdRole = Qt::UserRole + 1,
        NameRole,
        StatusRole,
        RevisionRole,
        ColorIndexRole
    };

    explicit SpaceModel(Session &session);

    bool busy() const { return m_busy; }
    QString errorCode() const { return m_errorCode; }
    QString currentSpaceId() const { return m_currentSpaceId; }
    QString nameOf(const QString &spaceId) const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reload();
    /// Creates the space `name`, `visibility` "public" or "private".
    void create(const QString &name, const QString &visibility);
    void select(const QString &spaceId);
    void clearCurrent();
    void clear();

signals:
    void changed();
    /// Core created the space `spaceId`.
    void created(const QString &spaceId);

private:
    const SpaceRow *find(const QString &spaceId) const;
    void setBusy();
    void fail(const QString &code);
    void applyList(const Client::Reply &reply, const QJsonArray &list);
    static SpaceRow parseRow(const QJsonObject &json, int colorIndex);

    Session &m_session;
    QVector<SpaceRow> m_rows;
    QString m_currentSpaceId;
    QString m_errorCode;
    bool m_busy = false;
    int m_generation = 0;
};

} // namespace matome
