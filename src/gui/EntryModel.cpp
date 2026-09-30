#include "EntryModel.h"

#include "Session.h"

#include <QLocale>

namespace matome {
namespace {

// Core's membership roles and space states: the detail column says these in
// the interface language and any other value as Core sent it.
const char *const kDetailWords[] = {
        QT_TRANSLATE_NOOP("matome::EntryModel", "owner"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "admin"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "member"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "billing"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "guest"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "draft"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "active"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "paused"),
        QT_TRANSLATE_NOOP("matome::EntryModel", "archived"),
};

} // namespace

EntryModel::EntryModel(Session &session)
    : ViewModel(QMetaEnum::fromType<Role>(), 2, &session)
    , m_session(session)
{
}

QString EntryModel::detailWord(const QString &value)
{
    for (const char *word : kDetailWords) {
        if (value == QLatin1String(word))
            return tr(word);
    }
    return value;
}

void EntryModel::add(QList<QVariantList> &rows, const QString &kind, const QString &id,
                     const QString &name, const QString &detail, int colorIndex,
                     const QString &payload, bool current, bool controlled) const
{
    if (!name.contains(m_filter, Qt::CaseInsensitive))
        return;
    rows.append({kind, id, name, detail, colorIndex, payload, current, controlled});
}

void EntryModel::refresh()
{
    const QString here = QStringList{m_session.level(), m_session.currentOrgId(), m_session.currentSpaceId(),
                                     m_session.currentFolderId()}
                                 .join(QLatin1Char('/'));
    if (here != location())
        m_filter.clear();

    QList<QVariantList> rows;
    switch (m_session.where()) {
    case Session::Level::Orgs: {
        const OrgModel *orgs = m_session.organizations();
        for (int i = 0; i < orgs->rowCount(); ++i) {
            const QModelIndex at = orgs->index(i);
            const QString id = at.data(OrgModel::OrgIdRole).toString();
            add(rows, QStringLiteral("org"), id, at.data(OrgModel::NameRole).toString(),
                detailWord(at.data(OrgModel::RoleNameRole).toString()), -1, QString(),
                id == m_session.lastOrgId());
        }
        break;
    }
    case Session::Level::Spaces: {
        const SpaceModel *spaces = m_session.spaces();
        for (int i = 0; i < spaces->rowCount(); ++i) {
            const QModelIndex at = spaces->index(i);
            add(rows, QStringLiteral("space"), at.data(SpaceModel::SpaceIdRole).toString(),
                at.data(SpaceModel::NameRole).toString(),
                detailWord(at.data(SpaceModel::StatusRole).toString()),
                at.data(SpaceModel::ColorIndexRole).toInt(), QString(), false);
        }
        break;
    }
    case Session::Level::Files: {
        const FolderModel *folders = m_session.folders();
        for (int i = 0; i < folders->rowCount(); ++i) {
            const QModelIndex at = folders->index(i);
            const QString id = at.data(FolderModel::FolderIdRole).toString();
            add(rows, QStringLiteral("folder"), id, at.data(FolderModel::NameRole).toString(),
                QString(), -1,
                QStringLiteral("folder:%1:%2").arg(id).arg(at.data(FolderModel::RevisionRole).toInt()),
                false);
        }
        const DocumentModel *documents = m_session.documents();
        // The default locale is the interface language's (Theme sets it).
        const QLocale locale;
        for (int i = 0; i < documents->rowCount(); ++i) {
            const QModelIndex at = documents->index(i);
            const QString id = at.data(DocumentModel::DocumentIdRole).toString();
            const QString bytes = at.data(DocumentModel::ByteSizeRole).toString();
            const QString detail = bytes.isEmpty() ? QString() : locale.formattedDataSize(bytes.toLongLong());
            const bool controlled = at.data(DocumentModel::ControlledRole).toBool();
            add(rows, QStringLiteral("document"), id, at.data(DocumentModel::TitleRole).toString(),
                detail, -1,
                QStringLiteral("document:%1:%2")
                        .arg(id)
                        .arg(at.data(DocumentModel::RevisionRole).toInt()),
                id == m_session.currentDocumentId(), controlled);
        }
        break;
    }
    }
    apply(here, rows);
}

} // namespace matome
