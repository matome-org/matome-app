#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QList>
#include <QMetaEnum>
#include <QString>
#include <QVariantList>

namespace matome {

/// Rows derived from the Session models, one QVariant per role in the order
/// of the subclass's Role enum; the first `keyColumns` values name a row. A new location resets the
/// view; within one location only the rows that changed are signalled, so
/// delegates keep focus and scroll.
class ViewModel : public QAbstractListModel
{
    Q_OBJECT

public:
    ViewModel(const QMetaEnum &roles, int keyColumns, QObject *parent);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

protected:
    QString location() const { return m_location; }
    void apply(const QString &location, const QList<QVariantList> &rows);

private:
    bool sameKey(const QVariantList &a, const QVariantList &b) const;

    QList<QByteArray> m_roles;
    int m_keyColumns = 1;
    QString m_location;
    QList<QVariantList> m_rows;
};

} // namespace matome
