#pragma once

#include "ViewModel.h"

#include <QString>

namespace matome {

class Session;

/// Children of the current location: organizations at the root, spaces in an
/// organization, folders then documents in a space. Filtered by name.
class EntryModel : public ViewModel
{
    Q_OBJECT

public:
    /// Role names derive from these: EntryIdRole is "entryId".
    enum Role {
        KindRole = Qt::UserRole + 1,
        EntryIdRole,
        NameRole,
        DetailRole,
        ColorIndexRole,
        PayloadRole,
        CurrentRole,
        ControlledRole
    };
    Q_ENUM(Role)

    explicit EntryModel(Session &session);

    QString filter() const { return m_filter; }
    void setFilter(const QString &filter) { m_filter = filter; }
    void refresh();
    static QString detailWord(const QString &value);

private:
    void add(QList<QVariantList> &rows, const QString &kind, const QString &id,
             const QString &name, const QString &detail, int colorIndex, const QString &payload,
             bool current, bool controlled = false) const;

    Session &m_session;
    QString m_filter;
};

} // namespace matome
