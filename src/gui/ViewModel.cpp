#include "ViewModel.h"

namespace matome {

ViewModel::ViewModel(const QMetaEnum &roles, int keyColumns, QObject *parent)
    : QAbstractListModel(parent)
    , m_keyColumns(keyColumns)
{
    // KindRole, EntryIdRole, ... become "kind", "entryId", ... in value order.
    for (int i = 0; i < roles.keyCount(); ++i) {
        Q_ASSERT(roles.value(i) == Qt::UserRole + 1 + i);
        QByteArray name(roles.key(i));
        name.chop(4);
        name[0] = char(QChar::toLower(uchar(name[0])));
        m_roles.append(name);
    }
}

bool ViewModel::sameKey(const QVariantList &a, const QVariantList &b) const
{
    return a.mid(0, m_keyColumns) == b.mid(0, m_keyColumns);
}

int ViewModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant ViewModel::data(const QModelIndex &index, int role) const
{
    const int column = role - Qt::UserRole - 1;
    if (!index.isValid() || index.row() >= m_rows.size() || column < 0 || column >= m_roles.size())
        return {};
    return m_rows.at(index.row()).at(column);
}

QHash<int, QByteArray> ViewModel::roleNames() const
{
    QHash<int, QByteArray> names;
    for (int i = 0; i < m_roles.size(); ++i)
        names.insert(Qt::UserRole + 1 + i, m_roles.at(i));
    return names;
}

void ViewModel::apply(const QString &location, const QList<QVariantList> &rows)
{
    if (location != m_location) {
        beginResetModel();
        m_location = location;
        m_rows = rows;
        endResetModel();
        return;
    }
    // Rows keep their place while their keys match at the head and the tail;
    // only the middle span is removed and inserted. Kept rows whose values
    // changed are signalled as edits, so their delegates survive.
    const int shared = qMin(m_rows.size(), rows.size());
    int head = 0;
    while (head < shared && sameKey(m_rows.at(head), rows.at(head)))
        ++head;
    int tail = 0;
    while (tail < shared - head
           && sameKey(m_rows.at(m_rows.size() - 1 - tail), rows.at(rows.size() - 1 - tail)))
        ++tail;
    const int oldEnd = m_rows.size() - tail;
    const int newEnd = rows.size() - tail;
    if (head < oldEnd) {
        beginRemoveRows({}, head, oldEnd - 1);
        m_rows.remove(head, oldEnd - head);
        endRemoveRows();
    }
    if (head < newEnd) {
        beginInsertRows({}, head, newEnd - 1);
        m_rows.insert(head, newEnd - head, QVariantList());
        for (int i = head; i < newEnd; ++i)
            m_rows[i] = rows.at(i);
        endInsertRows();
    }
    int first = -1;
    int last = -1;
    for (int i = 0; i < rows.size(); ++i) {
        if (m_rows.at(i) == rows.at(i))
            continue;
        m_rows[i] = rows.at(i);
        if (first < 0)
            first = i;
        last = i;
    }
    if (first >= 0)
        emit dataChanged(index(first), index(last));
}

} // namespace matome
