#include "Session.h"

#include "JsonList.h"
#include "Languages.h"
#include "LocalFiles.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

#include <utility>

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
                       m_documents.refuse(code, reply.json.value(QStringLiteral("details")).toObject());
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
    if (m_uploads.isEmpty() && m_staged.isEmpty())
        setUploadError();
    // Core grants the managing action in a space only where the add-on is
    // active there, so holding it means the space requires reviews.
    const QVariantMap addOn = m_addOns.state(QStringLiteral("controlled_docs"));
    const bool requiresReviews = name.endsWith(QLatin1String(".md"), Qt::CaseInsensitive)
            && m_permissions.spaceGrants(currentSpaceId(), QStringLiteral("addon.controlled_docs.document_manage"))
            && (!addOn.value(QStringLiteral("known")).toBool() || addOn.value(QStringLiteral("available")).toBool());
    if (requiresReviews)
        stage({name, bytes, location()});
    else
        enqueue({name, bytes, location()});
}

void Session::enqueue(const Upload &file)
{
    const bool idle = m_uploads.isEmpty();
    m_uploads.append(file);
    if (idle)
        startUpload();
    else
        notify();
}

// A Markdown file waits until the person says whether to manage it with
// reviews; the files that join meanwhile wait on the same answer.
void Session::stage(const Upload &file)
{
    m_staged.append(file);
    notify();
    if (m_staged.size() == 1)
        emit promptUploadReviews();
}

void Session::uploadStaged(bool manage)
{
    const QList<Upload> files = std::exchange(m_staged, {});
    for (Upload file : files) {
        file.manage = manage;
        enqueue(file);
    }
    notify();
}

void Session::cancelStaged()
{
    if (m_staged.isEmpty())
        return;
    m_staged.clear();
    notify();
}

void Session::requestUpload()
{
#ifdef Q_OS_WASM
    pickLocalFiles("*", [this](const QString &name, const QByteArray &bytes) { upload(name, bytes); });
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
    const Location to = next.to;
    const QString orgId = to.orgId;
    const QString spaceId = to.spaceId;
    const QString name = next.name;
    const QByteArray bytes = next.bytes;
    const bool manage = next.manage;
    QJsonObject document;
    document.insert(QStringLiteral("title"), name);
    if (!next.to.folderId.isEmpty())
        document.insert(QStringLiteral("folder_id"), next.to.folderId);
    authedPost(contentPath(orgId, spaceId, QStringLiteral("documents")), document,
               idempotencyHeader(),
               live([this, to, orgId, spaceId, name, bytes, manage, run](const Client::Reply &reply) {
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
                           [this, to, documentId, manage](const Client::Reply &done) {
                               if (!done.ok)
                                   finishUpload(failCode(done));
                               else if (manage)
                                   manageUploaded(to, documentId);
                               else
                                   finishUpload({});
                           },
                           [this](qint64 sent, qint64 total) {
                               if (total > 0) { m_uploadProgress = double(sent) / double(total); notify(); }
                           });
               }));
}

// Reads the landed document's revision, then turns its control on with it.
void Session::manageUploaded(const Location &to, const QString &documentId)
{
    const int run = m_uploadRun;
    const QString path = contentPath(to.orgId, to.spaceId, QStringLiteral("documents/") + documentId);
    AddOnBackend &backend = m_addOns.backend();
    backend.request("GET", path, {}, {}, [this, run, path, &backend](const Client::Reply &read) {
        if (run != m_uploadRun)
            return;
        if (!read.ok) {
            finishUpload(failCode(read), true);
            return;
        }
        const int revision = read.json.value(QStringLiteral("document")).toObject().value(QStringLiteral("revision")).toInt();
        backend.request("PUT", path + QStringLiteral("/controlled-docs"), {}, idempotentMatchHeader(revision),
                        [this, run](const Client::Reply &reply) {
            if (run == m_uploadRun)
                finishUpload(reply.ok ? QString() : failCode(reply), true);
        });
    });
}

// The next file starts.
void Session::finishUpload(const QString &code, bool landed)
{
    const Upload done = m_uploads.takeFirst();
    ++m_uploadDone;
    if (code.isEmpty() || landed)
        m_documents.reload();
    if (!code.isEmpty())
        reportUpload(code, done.name, landed);
    startUpload();
}

void Session::setUploadError(const QString &code, const QString &name, bool landed)
{
    m_uploadError = code;
    m_uploadErrorName = name;
    m_uploadLanded = landed;
}

void Session::reportUpload(const QString &code, const QString &name, bool landed)
{
    setUploadError(code, name, landed);
    notify();
}

const QList<Session::Command> &Session::commands()
{
    const auto always = [](const Session &) { return true; };
    const auto signedIn = [](const Session &s) { return s.m_signedIn; };
    // The explorer is the screen: neither settings nor document reviews cover it.
    static const auto explorer = [](const Session &s) {
        return s.m_signedIn && !s.m_settingsActive && !s.m_documentView.active();
    };
    // Only inside a space: files, folders, uploads, the clipboard.
    static const auto inFiles = [](const Session &s) { return explorer(s) && s.inSpace(); };
    const auto focused = [](const Session &s) { return inFiles(s) && !s.m_focusPayload.isEmpty(); };
    // The action the current space's catalog must allow on an entry of `kind`.
    static const auto onKind = [](const QString &kind, const char *onFolder, const char *onDocument) {
        return QString::fromLatin1(kind == QLatin1String("folder") ? onFolder : onDocument);
    };
    static const auto needs = [](const char *action) {
        return [action](const Session &) { return QString::fromLatin1(action); };
    };
    const auto trashed = [](const Session &s) {
        return explorer(s) && !s.m_lastTrashed.id.isEmpty();
    };
    static const QList<Command> table = [&] {
        QList<Command> rows{
                {"keymap", QT_TR_NOOP("Keyboard map"),
                 always, [](Session &s) { emit s.showKeymap(); }},
                {"sheet", QT_TR_NOOP("Command sheet"),
                 always, [](Session &s) { emit s.showSheet(); }},
                {"settings", QT_TR_NOOP("Settings"), explorer,
                 [](Session &s) { s.openSettings(); }},
                {"next-region", QT_TR_NOOP("Next region"),
                 explorer, [](Session &s) { emit s.cycleRegion(1); }},
                {"previous-region", QT_TR_NOOP("Previous region"), explorer,
                 [](Session &s) { emit s.cycleRegion(-1); }},
                {"back", QT_TR_NOOP("Back"), [](const Session &s) { return explorer(s) && s.canGoBack(); },
                 [](Session &s) { s.stepHistory(-1); }},
                {"forward", QT_TR_NOOP("Forward"),
                 [](const Session &s) { return explorer(s) && s.canGoForward(); },
                 [](Session &s) { s.stepHistory(1); }},
                {"up", QT_TR_NOOP("Up one level"),
                 [](const Session &s) { return explorer(s) && s.where() != Level::Orgs; },
                 [](Session &s) { s.goUp(); }},
                {"refresh", QT_TR_NOOP("Refresh"),
                 [](const Session &s) { return explorer(s) || s.m_documentView.active(); },
                 [](Session &s) { s.refreshLocation(); }},
                {"filter", QT_TR_NOOP("Filter"),
                 explorer, [](Session &s) { emit s.focusFilter(); }},
                {"new", nullptr, explorer, [](Session &s) { emit s.promptNew(); }, nullptr,
                 [](const Session &s) { return s.inSpace() ? QStringLiteral("folder.create") : QString(); }},
                {"upload", QT_TR_NOOP("Upload file"), inFiles, [](Session &s) { s.requestUpload(); }, nullptr,
                 needs("upload.create")},
                {"download", QT_TR_NOOP("Download"),
                 [](const Session &s) { return inFiles(s) && s.focusedEntry().kind == QLatin1String("document"); },
                 [](Session &s) {
                     const Entry entry = s.focusedEntry();
                     if (entry.kind == QLatin1String("document"))
                         s.m_documents.download(entry.id);
                 }, nullptr, needs("content.download")},
                {"open", QT_TR_NOOP("Open"), focused, [](Session &s) {
                     const Entry entry = s.focusedEntry();
                     s.openEntry(entry.kind, entry.id);
                 }, "forward"},
                {"rename", QT_TR_NOOP("Rename"), focused, [](Session &s) { s.promptRenameFocused(); }, nullptr,
                 [](const Session &s) { return onKind(s.focusedEntry().kind, "folder.rename", "document.metadata_update"); }},
                {"access", QT_TR_NOOP("Manage access"),
                 [](const Session &s) { return inFiles(s) && !s.focusedEntry().id.isEmpty(); },
                 [](Session &s) { s.openFocusedAccess(); }, nullptr, needs("resource_grant.read")},
                {"trash", nullptr,
                 [](const Session &s) { return inFiles(s) && !s.focusedEntry().id.isEmpty(); },
                 [](Session &s) { s.trashFocused(); }, nullptr,
                 [](const Session &s) { return onKind(s.focusedEntry().kind, "folder.delete", "document.trash"); }},
                {"restore", QT_TR_NOOP("Restore last trash"),
                 trashed, [](Session &s) { s.settleLastTrashed("restore", true); }},
                {"purge", QT_TR_NOOP("Purge last trash"),
                 trashed, [](Session &s) { s.settleLastTrashed("purge", false); }},
                {"cut", QT_TR_NOOP("Cut"), focused, [](Session &s) { s.cutPayload(s.m_focusPayload); }, nullptr,
                 [](const Session &s) { return onKind(s.focusedEntry().kind, "folder.move", "document.move"); }},
                {"paste", QT_TR_NOOP("Paste"),
                 [](const Session &s) { return inFiles(s) && s.hasClipboard(); },
                 [](Session &s) { s.pasteHere(); }, nullptr,
                 [](const Session &s) { return onKind(s.m_clip.kind, "folder.move", "document.move"); }},
                {"sign-out", QT_TR_NOOP("Sign out"), signedIn, [](Session &s) { s.signOut(); }},
                {"theme-light", QT_TR_NOOP("Theme light"), always, nullptr},
                {"theme-dark", QT_TR_NOOP("Theme dark"), always, nullptr},
                {"theme-system", QT_TR_NOOP("Theme system"), always, nullptr},
        };
        // The document screen's verbs: DocumentView decides when each can
        // run and runs it, or asks the screen to.
        static const struct {
            const char *id;
            const char *title;
            const char *icon;
        } viewing[] = {
                {"view-tab", QT_TR_NOOP("Preview"), "document"},
                {"edit-tab", QT_TR_NOOP("Edit"), "rename"},
                {"versions-tab", QT_TR_NOOP("Versions"), "restore"},
                {"related-tab", QT_TR_NOOP("Related"), "link"},
                {"reviews-tab", QT_TR_NOOP("Reviews"), "controlled-docs"},
                {"download-version", QT_TR_NOOP("Download"), "download"},
                {"insert-image", QT_TR_NOOP("Insert image"), "image"},
                {"discard-changes", QT_TR_NOOP("Discard changes"), "restore"},
                {"save-document", QT_TR_NOOP("Save"), "check"},
        };
        for (const auto &action : viewing) {
            const QByteArray id(action.id);
            rows.append({id, action.title,
                         [id](const Session &s) { return s.m_documentView.allows(id); },
                         [id](Session &s) { s.m_documentView.perform(id); }, action.icon});
        }
        // The controlled-documents add-on's verbs on the open document.
        static const struct {
            const char *id;
            const char *title;
            const char *icon;
        } reviewing[] = {
                {"open-review", QT_TR_NOOP("Open review"), "forward"},
                {"close-review", QT_TR_NOOP("Back to reviews"), "back"},
                {"download-candidate", QT_TR_NOOP("Download proposal"), "download"},
                {"approve-review", QT_TR_NOOP("Approve"), "check"},
                {"reject-review", QT_TR_NOOP("Reject"), "close"},
                {"cancel-review", QT_TR_NOOP("Cancel review"), "cancel"},
                {"update-review", QT_TR_NOOP("Update review"), "refresh"},
                {"resolve-conflicts", QT_TR_NOOP("Resolve conflicts"), "diff"},
                {"edit-proposal", QT_TR_NOOP("Edit proposal"), "rename"},
                {"manage-document", QT_TR_NOOP("Manage with reviews"), "controlled-docs"},
                {"unmanage-document", QT_TR_NOOP("Stop managing"), "document"},
        };
        // Managing also acts on the explorer's focused document: it opens,
        // and the add-on runs the verb once it has loaded.
        static const auto fromExplorer = [](const Session &s, QByteArrayView id) {
            const Entry entry = s.focusedEntry();
            if (!inFiles(s) || entry.kind != QLatin1String("document")
                || s.m_addOns.state(QStringLiteral("controlled_docs")).value(QStringLiteral("status")).toString().isEmpty())
                return false;
            const bool controlled = s.m_documents.controlledOf(entry.id);
            if (id == "unmanage-document") return controlled;
            return id == "manage-document" && !controlled
                    && s.m_documents.titleOf(entry.id).endsWith(QLatin1String(".md"), Qt::CaseInsensitive);
        };
        for (const auto &action : reviewing) {
            const QByteArray id(action.id);
            rows.append({id, action.title,
                         [id](const Session &s) { return s.m_controlledDocs.allows(id) || fromExplorer(s, id); },
                         [id](Session &s) {
                             if (!s.usable(*s.command(QString::fromLatin1(id)))) return;
                             if (s.m_controlledDocs.allows(id) || !fromExplorer(s, id)) {
                                 s.m_controlledDocs.perform(id);
                                 return;
                             }
                             s.openEntry(QStringLiteral("document"), s.focusedEntry().id);
                             s.m_controlledDocs.performWhenLoaded(id);
                         }, action.icon,
                         id == "manage-document" ? std::function<QString(const Session &)>(needs("addon.controlled_docs.document_manage"))
                                                 : nullptr});
        }
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
// empty label is an alternate spelling of the row above. A key may bind one
// command per screen: the first usable one runs.
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
        {Qt::Key_D, 0, false, "download-version", "D"},
        {Qt::Key_1, 0, false, "view-tab", "1"},
        {Qt::Key_2, 0, false, "edit-tab", "2"},
        {Qt::Key_3, 0, false, "versions-tab", "3"},
        {Qt::Key_4, 0, false, "related-tab", "4"},
        {Qt::Key_5, 0, false, "reviews-tab", "5"},
        {Qt::Key_S, Qt::ControlModifier, true, "save-document", "Ctrl+S"},
        {Qt::Key_Return, Qt::ControlModifier, true, "save-document", "Ctrl+Enter"},
        {Qt::Key_Enter, Qt::ControlModifier, true, "save-document", ""},
        {Qt::Key_F2, 0, false, "rename", "F2"},
        {Qt::Key_A, 0, false, "access", "A"},
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
        const bool can = usable(row);
        map.insert(QStringLiteral("usable"), can);
        // Refused by the space's catalog: why, and what fixes it.
        if (!can && row.action && row.usable(*this))
            map.insert(QStringLiteral("refusal"), m_permissions.explain(row.action(*this), currentSpaceId()));
        list.append(map);
    }
    return list;
}

bool Session::usable(const Command &row) const
{
    if (!row.usable(*this))
        return false;
    const QString action = row.action ? row.action(*this) : QString();
    return action.isEmpty() || m_permissions.spaceAllows(currentSpaceId(), action);
}

Session::Face Session::faceOf(const Command &row) const
{
    if (row.title)
        return {row.title, row.icon ? row.icon : row.id.constData()};
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
    if (m_documentView.active()) {
        m_documentView.refresh();
        m_controlledDocs.refresh();
        m_permissions.reload();
        return;
    }
    switch (where()) {
    case Level::Orgs:
        m_orgs.reload();
        break;
    case Level::Spaces:
        m_spaces.reload();
        break;
    case Level::Files:
        m_folders.reload();
        m_permissions.reload();
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

void Session::openFocusedAccess()
{
    const Entry focused = focusedEntry();
    if (focused.id.isEmpty())
        return;
    m_accessGrants.open(focused.kind, currentSpaceId(), focused.id, nameOf(focused));
    emit promptAccess();
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
        if (!usable(*row))
            continue;
        row->run(*this);
        return true;
    }
    return false;
}

} // namespace matome
