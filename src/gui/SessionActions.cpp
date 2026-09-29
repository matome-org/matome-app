#include "Session.h"

#include "JsonList.h"
#include "Languages.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

#ifdef Q_OS_WASM
#include <QtGui/private/qwasmlocalfileaccess_p.h>

#include <list>
#include <memory>
#endif

namespace matome {

void Session::setFocusPayload(const QString &payload)
{
    if (payload == m_focusPayload)
        return;
    m_focusPayload = payload;
    notify();
}

void Session::renameFocused(const QString &name)
{
    const auto [kind, id, revision] = parsePayload(m_focusPayload);
    if (id.isEmpty())
        return;
    if (kind == QLatin1String("folder"))
        m_folders.rename(id, name, revision);
    else
        m_documents.rename(id, name, revision);
}

QString Session::nameOf(const Entry &entry) const
{
    return entry.kind == QLatin1String("folder") ? m_folders.nameOf(entry.id)
                                                 : m_documents.titleOf(entry.id);
}

Session::Entry Session::focusedEntry() const
{
    Entry entry = parsePayload(m_focusPayload);
    if (!entry.id.isEmpty())
        return entry;
    entry.id = currentDocumentId();
    if (!entry.id.isEmpty()) {
        entry.kind = QStringLiteral("document");
        entry.revision = m_documents.revisionOf(entry.id);
    }
    return entry;
}

void Session::trashFocused()
{
    const Entry entry = focusedEntry();
    if (entry.id.isEmpty())
        return;
    if (entry.kind == QLatin1String("folder")) {
        emit promptDelete(nameOf(entry));
        return;
    }
    m_documents.trash(entry.id, entry.revision);
}

void Session::deleteFocusedFolder()
{
    const auto [kind, id, revision] = parsePayload(m_focusPayload);
    if (kind == QLatin1String("folder"))
        m_folders.remove(id, revision);
}

void Session::settleLastTrashed(const char *action, bool refills)
{
    const QString orgId = currentOrgId();
    const auto [kind, id, revision] = m_lastTrashed;
    if (!m_signedIn || orgId.isEmpty() || id.isEmpty())
        return;
    authedPost(orgPath(orgId, QStringLiteral("trash/%1/%2").arg(id, QLatin1String(action))),
               {}, idempotentMatchHeader(revision), [this, refills](const Client::Reply &reply) {
                   if (!reply.ok) {
                       const QString code = failCode(reply);
                       // Restored, purged, or changed elsewhere: no longer
                       // the trash this would undo or finish.
                       if (code == QLatin1String("revision_conflict"))
                           m_lastTrashed = {};
                       m_documents.refuse(code);
                       return;
                   }
                   m_lastTrashed = {};
                   if (refills) {
                       m_folders.reload();
                       m_documents.reload();
                   }
                   notify();
               });
}

void Session::uploadUrls(const QList<QUrl> &urls)
{
    // A local path, or the content:// URI Android's picker hands back: QFile
    // opens both there, and QFileInfo names the latter by its display name.
    QStringList unreadable;
    for (const QUrl &url : urls) {
        const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
        const QString name = QFileInfo(path).fileName();
        QFile file(path);
        if (file.open(QIODevice::ReadOnly))
            upload(name, file.readAll());
        else
            unreadable.append(name);
    }
    // Said after queueing, so a batch the readable files start keeps it.
    for (const QString &name : std::as_const(unreadable))
        reportUpload(QStringLiteral("unreadable"), name);
}

void Session::upload(const QString &name, const QByteArray &bytes)
{
    if (!inSpace())
        return;
    const bool idle = m_uploads.isEmpty();
    if (idle)
        setUploadError();
    m_uploads.append({name, bytes, location()});
    if (idle)
        startUpload();
    else
        notify();
}

void Session::requestUpload()
{
#ifdef Q_OS_WASM
    // QML's FileDialog cannot read the visitor's disk; the browser's picker
    // hands over each chosen file's name and bytes, one after another.
    auto picked = std::make_shared<std::list<std::pair<QString, QByteArray>>>();
    QWasmLocalFileAccess::openFiles(
            "*", QWasmLocalFileAccess::FileSelectMode::MultipleFiles, [](int) {},
            [picked](uint64_t size, const std::string &name) {
                picked->emplace_back(QString::fromStdString(name),
                                     QByteArray(qsizetype(size), Qt::Uninitialized));
                return picked->back().second.data();
            },
            [this, picked] {
                const auto [name, bytes] = picked->front();
                picked->pop_front();
                upload(name, bytes);
            });
#else
    emit promptUpload();
#endif
}

// Creates the document, asks Core where to put the bytes, PUTs them there,
// and completes the upload; a step that fails ends this file only.
void Session::startUpload()
{
    m_uploadProgress = 0;
    if (m_uploads.isEmpty()) {
        m_uploadDone = 0;
        notify();
        return;
    }
    notify();
    const Upload &next = m_uploads.constFirst();
    const int run = m_uploadRun;
    // A reply for a queue that has since been dropped (signed out) is ignored.
    const auto live = [this, run](auto step) {
        return [this, run, step](const Client::Reply &reply) {
            if (run == m_uploadRun)
                step(reply);
        };
    };
    const QString orgId = next.to.orgId;
    const QString spaceId = next.to.spaceId;
    const QString name = next.name;
    const QByteArray bytes = next.bytes;
    QJsonObject document;
    document.insert(QStringLiteral("title"), name);
    if (!next.to.folderId.isEmpty())
        document.insert(QStringLiteral("folder_id"), next.to.folderId);
    authedPost(contentPath(orgId, spaceId, QStringLiteral("documents")), document,
               idempotencyHeader(),
               live([this, orgId, spaceId, name, bytes, run](const Client::Reply &reply) {
                   const QString documentId =
                           jsonId(reply.json.value(QStringLiteral("document"))
                                          .toObject()
                                          .value(QStringLiteral("id")));
                   if (!reply.ok || documentId.isEmpty()) {
                       finishUpload(reply.ok ? QStringLiteral("invalid_request") : failCode(reply));
                       return;
                   }
                   QJsonObject upload;
                   upload.insert(QStringLiteral("space_id"), spaceId);
                   upload.insert(QStringLiteral("document_id"), documentId);
                   upload.insert(QStringLiteral("filename"), name);
                   upload.insert(QStringLiteral("content_type"), name.endsWith(QLatin1String(".md"), Qt::CaseInsensitive)
                                 ? QStringLiteral("text/markdown") : QStringLiteral("application/octet-stream"));
                   m_coreAddOnBackend.upload(orgId, upload, bytes, [this, run] { return run == m_uploadRun; },
                           [this](const Client::Reply &done) { finishUpload(done.ok ? QString() : failCode(done)); },
                           [this](qint64 sent, qint64 total) {
                               if (total > 0) { m_uploadProgress = double(sent) / double(total); notify(); }
                           });
               }));
}

// The file at the head of the queue is done, landed (`code` empty) or not;
// the next one starts.
void Session::finishUpload(const QString &code)
{
    const Upload done = m_uploads.takeFirst();
    ++m_uploadDone;
    if (code.isEmpty())
        m_documents.reload();
    else
        reportUpload(code, done.name);
    startUpload();
}

void Session::setUploadError(const QString &code, const QString &name)
{
    m_uploadError = code;
    m_uploadErrorName = name;
}

void Session::reportUpload(const QString &code, const QString &name)
{
    setUploadError(code, name);
    notify();
}

const QList<Session::Command> &Session::commands()
{
    const auto always = [](const Session &) { return true; };
    const auto signedIn = [](const Session &s) { return s.m_signedIn; };
    // Only inside a space: files, folders, uploads, the clipboard.
    static const auto inFiles = [](const Session &s) { return s.inSpace(); };
    const auto focused = [](const Session &s) { return inFiles(s) && !s.m_focusPayload.isEmpty(); };
    const auto trashed = [](const Session &s) {
        return s.m_signedIn && !s.m_lastTrashed.id.isEmpty();
    };
    static const QList<Command> table = [&] {
        QList<Command> rows{
                {"keymap", QT_TR_NOOP("Keyboard map"),
                 always, [](Session &s) { emit s.showKeymap(); }},
                {"sheet", QT_TR_NOOP("Command sheet"),
                 always, [](Session &s) { emit s.showSheet(); }},
                {"settings", QT_TR_NOOP("Settings"),
                 [](const Session &s) { return s.signedIn(); },
                 [](Session &s) { s.openSettings(); }},
                {"next-region", QT_TR_NOOP("Next region"),
                 signedIn, [](Session &s) { emit s.cycleRegion(1); }},
                {"previous-region", QT_TR_NOOP("Previous region"), signedIn,
                 [](Session &s) { emit s.cycleRegion(-1); }},
                {"back", QT_TR_NOOP("Back"), [](const Session &s) { return s.canGoBack(); },
                 [](Session &s) { s.stepHistory(-1); }},
                {"forward", QT_TR_NOOP("Forward"),
                 [](const Session &s) { return s.canGoForward(); },
                 [](Session &s) { s.stepHistory(1); }},
                {"up", QT_TR_NOOP("Up one level"),
                 [](const Session &s) { return s.m_signedIn && s.where() != Level::Orgs; },
                 [](Session &s) { s.goUp(); }},
                {"refresh", QT_TR_NOOP("Refresh"),
                 signedIn, [](Session &s) { s.refreshLocation(); }},
                {"filter", QT_TR_NOOP("Filter"),
                 signedIn, [](Session &s) { emit s.focusFilter(); }},
                {"new", nullptr, signedIn, [](Session &s) { emit s.promptNew(); }},
                {"upload", QT_TR_NOOP("Upload file"),
                 inFiles, [](Session &s) { s.requestUpload(); }},
                {"download", QT_TR_NOOP("Download"),
                 [](const Session &s) {
                     return inFiles(s) && s.focusedEntry().kind == QLatin1String("document");
                 },
                 [](Session &s) {
                     const Entry entry = s.focusedEntry();
                     if (entry.kind == QLatin1String("document"))
                         s.m_documents.download(entry.id);
                 }},
                {"controlled-docs", QT_TR_NOOP("Document reviews"), inFiles, [](Session &s) {
                    const Entry entry = s.focusedEntry();
                    s.m_controlledDocs.open(entry.kind == QLatin1String("document") ? entry.id : QString());
                }},
                {"rename", QT_TR_NOOP("Rename"),
                 focused, [](Session &s) { s.promptRenameFocused(); }},
                {"trash", nullptr,
                 [](const Session &s) { return inFiles(s) && !s.focusedEntry().id.isEmpty(); },
                 [](Session &s) { s.trashFocused(); }},
                {"restore", QT_TR_NOOP("Restore last trash"),
                 trashed, [](Session &s) { s.settleLastTrashed("restore", true); }},
                {"purge", QT_TR_NOOP("Purge last trash"),
                 trashed, [](Session &s) { s.settleLastTrashed("purge", false); }},
                {"cut", QT_TR_NOOP("Cut"),
                 focused, [](Session &s) { s.cutPayload(s.m_focusPayload); }},
                {"paste", QT_TR_NOOP("Paste"),
                 [](const Session &s) {
                     return inFiles(s) && s.hasClipboard();
                 },
                 [](Session &s) { s.pasteHere(); }},
                {"sign-out", QT_TR_NOOP("Sign out"), signedIn, [](Session &s) { s.signOut(); }},
                {"theme-light", QT_TR_NOOP("Theme light"), always, nullptr},
                {"theme-dark", QT_TR_NOOP("Theme dark"), always, nullptr},
                {"theme-system", QT_TR_NOOP("Theme system"), always, nullptr},
        };
        // Each language by its own name, untranslated, like the switcher.
        for (const Language &language : kLanguages)
            rows.append({QByteArray(kLanguageCommand) + language.code, language.name, always,
                         nullptr});
        return rows;
    }();
    return table;
}

const Session::Command *Session::command(const QString &id) const
{
    for (const Command &row : commands()) {
        if (id == QLatin1String(row.id))
            return &row;
    }
    return nullptr;
}

namespace {

// Every key the window routes here. A binding without Shift matches with or
// without it, so layouts that shift '?' and ':' still reach them; a Shift
// binding therefore comes before its plain twin. Labels feed the keymap; an
// empty label is an alternate spelling of the row above.
const struct {
    int key;
    int modifiers;
    bool inField;
    const char *command;
    const char *label;
} bindings[] = {
        {Qt::Key_Question, 0, false, "keymap", "?"},
        {Qt::Key_Slash, Qt::ShiftModifier, false, "keymap", ""},
        {Qt::Key_Colon, 0, false, "sheet", ":"},
        {Qt::Key_Semicolon, Qt::ShiftModifier, false, "sheet", ""},
        {Qt::Key_K, Qt::ControlModifier, true, "sheet", "Ctrl+K"},
        {Qt::Key_F6, Qt::ShiftModifier, true, "previous-region", "Shift+F6"},
        {Qt::Key_F6, 0, true, "next-region", "F6"},
        {Qt::Key_Left, Qt::AltModifier, true, "back", "Alt+Left"},
        {Qt::Key_Right, Qt::AltModifier, true, "forward", "Alt+Right"},
        {Qt::Key_Backspace, 0, false, "up", "Backspace"},
        {Qt::Key_Up, Qt::AltModifier, true, "up", "Alt+Up"},
        {Qt::Key_Escape, 0, true, "up", "Esc"},
        {Qt::Key_F5, 0, true, "refresh", "F5"},
        {Qt::Key_R, Qt::ControlModifier, true, "refresh", "Ctrl+R"},
        {Qt::Key_F, Qt::ControlModifier, true, "filter", "Ctrl+F"},
        {Qt::Key_N, 0, false, "new", "N"},
        {Qt::Key_N, Qt::ControlModifier | Qt::ShiftModifier, true, "new", "Ctrl+Shift+N"},
        {Qt::Key_U, 0, false, "upload", "U"},
        {Qt::Key_D, 0, false, "download", "D"},
        {Qt::Key_F2, 0, false, "rename", "F2"},
        {Qt::Key_Delete, 0, false, "trash", "Del"},
        {Qt::Key_Z, Qt::ControlModifier, false, "restore", "Ctrl+Z"},
        {Qt::Key_X, Qt::ControlModifier, false, "cut", "Ctrl+X"},
        {Qt::Key_V, Qt::ControlModifier, false, "paste", "Ctrl+V"},
};

} // namespace

QVariantList Session::commandList() const
{
    QVariantList list;
    for (const Command &row : commands()) {
        const QString id = QString::fromLatin1(row.id);
        QStringList keys;
        for (const auto &binding : bindings) {
            if (id == QLatin1String(binding.command) && *binding.label)
                keys.append(QString::fromLatin1(binding.label));
        }
        QVariantMap map;
        map.insert(QStringLiteral("id"), id);
        const Face face = faceOf(row);
        map.insert(QStringLiteral("title"), tr(face.title));
        map.insert(QStringLiteral("icon"), QString::fromLatin1(face.icon));
        map.insert(QStringLiteral("shortcut"), keys.join(QStringLiteral(" / ")));
        map.insert(QStringLiteral("usable"), row.usable(*this));
        list.append(map);
    }
    return list;
}

Session::Face Session::faceOf(const Command &row) const
{
    if (row.title)
        return {row.title, row.id.constData()};
    if (row.id == "trash") {
        if (focusedEntry().kind == QLatin1String("folder"))
            return {QT_TR_NOOP("Delete folder"), "purge"};
        return {QT_TR_NOOP("Move to trash"), "trash"};
    }
    return {levelInfo(where()).newTitle, row.id.constData()};
}

void Session::runCommand(const QString &id)
{
    const Command *row = command(id);
    if (row && row->run)
        row->run(*this);
}

void Session::refreshLocation()
{
    switch (where()) {
    case Level::Orgs:
        m_orgs.reload();
        break;
    case Level::Spaces:
        m_spaces.reload();
        break;
    case Level::Files:
        m_folders.reload();
        break;
    }
}

void Session::promptRenameFocused()
{
    const Entry focused = parsePayload(m_focusPayload);
    if (focused.id.isEmpty())
        return;
    emit promptRename(nameOf(focused));
}

bool Session::handleKey(int key, int modifiers, bool inField)
{
    const int held = modifiers & (Qt::ShiftModifier | Qt::ControlModifier | Qt::AltModifier);
    for (const auto &binding : bindings) {
        const int wanted = (binding.modifiers & Qt::ShiftModifier)
                                   ? held
                                   : held & ~int(Qt::ShiftModifier);
        if (binding.key != key || binding.modifiers != wanted || (inField && !binding.inField))
            continue;
        const Command *row = command(QString::fromLatin1(binding.command));
        if (!row->usable(*this))
            return false;
        row->run(*this);
        return true;
    }
    return false;
}

} // namespace matome
