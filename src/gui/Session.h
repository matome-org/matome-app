#pragma once

#include "Client.h"
#include "DocumentModel.h"
#include "EntryModel.h"
#include "FolderModel.h"
#include "FolderTreeModel.h"
#include "OrgModel.h"
#include "OrgAdmin.h"
#include "OrgBilling.h"
#include "SpaceModel.h"
#include "addons/AddOnManager.h"
#include "controlled_docs/ControlledDocs.h"

#include <QAbstractListModel>
#include <QJsonArray>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVector>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {

/// One signed-in identity at one Core origin. Tokens stay in memory.
class Session : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY changed)
    Q_PROPERTY(bool settingsActive READ settingsActive NOTIFY settingsChanged)
    Q_PROPERTY(bool confirmationPending READ confirmationPending NOTIFY changed)
    Q_PROPERTY(bool confirmationResent READ confirmationResent NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool resetSent READ resetSent NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QStringList errorFields READ errorFields NOTIFY changed)
    Q_PROPERTY(QString email READ email NOTIFY changed)
    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY changed)
    Q_PROPERTY(QAbstractListModel *organizations READ orgList CONSTANT)
    Q_PROPERTY(bool organizationsBusy READ organizationsBusy NOTIFY changed)
    Q_PROPERTY(QString organizationsError READ organizationsError NOTIFY changed)
    Q_PROPERTY(matome::OrgAdmin *orgAdmin READ orgAdmin CONSTANT)
    Q_PROPERTY(matome::OrgBilling *orgBilling READ orgBilling CONSTANT)
    Q_PROPERTY(matome::AddOnManager *addOns READ addOns CONSTANT)
    Q_PROPERTY(matome::ControlledDocs *controlledDocs READ controlledDocs CONSTANT)
    Q_PROPERTY(QString currentOrgId READ currentOrgId NOTIFY changed)
    Q_PROPERTY(QAbstractListModel *spaces READ spaceList CONSTANT)
    Q_PROPERTY(QString currentSpaceId READ currentSpaceId NOTIFY changed)
    Q_PROPERTY(QString currentFolderId READ currentFolderId NOTIFY changed)
    Q_PROPERTY(bool hasClipboard READ hasClipboard NOTIFY changed)
    Q_PROPERTY(bool uploadBusy READ uploadBusy NOTIFY changed)
    Q_PROPERTY(double uploadProgress READ uploadProgress NOTIFY changed)
    Q_PROPERTY(int uploadIndex READ uploadIndex NOTIFY changed)
    Q_PROPERTY(int uploadCount READ uploadCount NOTIFY changed)
    Q_PROPERTY(QString uploadError READ uploadError NOTIFY changed)
    Q_PROPERTY(QString uploadErrorName READ uploadErrorName NOTIFY changed)
    Q_PROPERTY(QString lastTrashedId READ lastTrashedId NOTIFY changed)
    Q_PROPERTY(QVariantList commandList READ commandList NOTIFY changed)
    Q_PROPERTY(QString childKind READ childKind NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString locationError READ locationError NOTIFY changed)
    Q_PROPERTY(QAbstractListModel *entries READ entryList CONSTANT)
    Q_PROPERTY(int entryCount READ entryCount NOTIFY changed)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY changed)
    Q_PROPERTY(QVariantList trail READ trail NOTIFY trailChanged)
    Q_PROPERTY(QAbstractListModel *folderTree READ folderTreeList CONSTANT)

public:
    /// How deep the explorer stands: what its entries list.
    enum class Level { Orgs, Spaces, Files };

    explicit Session(QObject *parent = nullptr, AddOnBackend *backend = nullptr);

    bool signedIn() const { return m_signedIn; }
    bool settingsActive() const { return m_settingsActive; }
    bool confirmationPending() const { return m_confirmationPending; }
    bool confirmationResent() const { return m_confirmationResent; }
    bool busy() const { return m_busy; }
    bool resetSent() const { return m_resetSent; }
    QString errorCode() const { return m_errorCode; }
    /// The fields Core named in the last auth failure's `details`.
    QStringList errorFields() const { return m_errorFields; }
    QString email() const { return m_email; }
    QString apiBaseUrl() const { return m_apiBaseUrl; }
    void setApiBaseUrl(const QString &url);
    QString lastOrgId() const { return m_lastOrgId; }
    void setLastOrgId(const QString &id);

    OrgModel *organizations() { return &m_orgs; }
    bool organizationsBusy() const { return m_orgs.busy(); }
    QString organizationsError() const { return m_orgs.errorCode(); }
    OrgAdmin *orgAdmin() { return &m_orgAdmin; }
    OrgBilling *orgBilling() { return &m_orgBilling; }
    AddOnManager *addOns() { return &m_addOns; }
    ControlledDocs *controlledDocs() { return &m_controlledDocs; }
    QAbstractListModel *orgList() { return &m_orgs; }
    QString currentOrgId() const { return m_orgs.currentOrgId(); }

    SpaceModel *spaces() { return &m_spaces; }
    QAbstractListModel *spaceList() { return &m_spaces; }
    QString currentSpaceId() const { return m_spaces.currentSpaceId(); }

    FolderModel *folders() { return &m_folders; }
    QString currentFolderId() const { return m_folders.currentFolderId(); }

    /// Signed in, with an organization and one of its spaces open.
    bool inSpace() const;
    /// `leaf` under the open space's content API.
    QString spacePath(const QString &leaf) const;

    DocumentModel *documents() { return &m_documents; }
    QString currentDocumentId() const { return m_documents.currentDocumentId(); }
    bool hasClipboard() const { return !m_clip.id.isEmpty(); }
    bool uploadBusy() const { return !m_uploads.isEmpty(); }
    /// The file on the wire, 0 to 1.
    double uploadProgress() const { return m_uploadProgress; }
    /// "Uploading `uploadIndex` of `uploadCount`": 1-based, 0 when idle.
    int uploadIndex() const { return m_uploads.isEmpty() ? 0 : m_uploadDone + 1; }
    int uploadCount() const { return m_uploadDone + int(m_uploads.size()); }
    /// Why the last file that failed did not land ("unreadable" or a Core
    /// code), and its name. Cleared when a new batch starts or on moving.
    QString uploadError() const { return m_uploadError; }
    QString uploadErrorName() const { return m_uploadErrorName; }
    QString lastTrashedId() const { return m_lastTrashed.id; }
    QVariantList commandList() const;

    Level where() const;
    QString level() const;
    QString childKind() const;
    bool loading() const;
    QString locationError() const;
    EntryModel *entries() { return &m_entries; }
    QAbstractListModel *entryList() { return &m_entries; }
    int entryCount() const { return m_entries.rowCount(); }
    QString filter() const { return m_entries.filter(); }
    void setFilter(const QString &filter);
    QVariantList trail() const { return m_trail; }
    FolderTreeModel *folderTree() { return &m_folderTree; }
    QAbstractListModel *folderTreeList() { return &m_folderTree; }
    bool canGoBack() const { return m_historyIndex > 0; }
    bool canGoForward() const { return m_historyIndex + 1 < m_history.size(); }

    Q_INVOKABLE void signIn(const QString &email, const QString &password,
                            const QString &apiBaseUrl);
    Q_INVOKABLE void registerAccount(const QString &email, const QString &password,
                                     const QString &apiBaseUrl);
    Q_INVOKABLE void resendConfirmation();
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void requestPasswordReset(const QString &email, const QString &apiBaseUrl);
    Q_INVOKABLE void refreshOrganizations();
    Q_INVOKABLE bool acceptsDrop(const QString &folderId, const QString &payload) const;
    Q_INVOKABLE void dropPayload(const QString &folderId, const QString &payload);
    Q_INVOKABLE void setFocusPayload(const QString &payload);
    Q_INVOKABLE void renameFocused(const QString &name);
    /// Deletes the focused folder for good; Core refuses one that holds anything.
    Q_INVOKABLE void deleteFocusedFolder();
    /// Reads each local file or Android content:// URI and uploads it.
    Q_INVOKABLE void uploadUrls(const QList<QUrl> &urls);
    /// The one upload entry point: queues a file into the open folder.
    /// Files go one at a time; one that fails is reported and the rest go on.
    void upload(const QString &name, const QByteArray &bytes);
    Q_INVOKABLE void openEntry(const QString &kind, const QString &id);
    Q_INVOKABLE void navigate(const QString &kind, const QString &id);
    Q_INVOKABLE void createHere(const QString &name);
    Q_INVOKABLE void toggleFolder(const QString &folderId);
    Q_INVOKABLE void openSettings();
    Q_INVOKABLE void closeSettings();
    Q_INVOKABLE void runCommand(const QString &id);
    Q_INVOKABLE bool handleKey(int key, int modifiers, bool inField);

    Client *client() { return &m_client; }

    void authedGet(const QString &path, Client::Done done);
    void authedPost(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                    Client::Done done);
    void authedPut(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                   Client::Done done);
    void authedPatch(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                     Client::Done done);
    void authedDelete(const QString &path, const Client::Headers &headers, Client::Done done);
    /// Whether the load that asked for a list still wants its pages.
    using Live = std::function<bool()>;
    /// A whole collection: the entries of every page, or the reply that failed
    /// (and no entries).
    using ListDone = std::function<void(const Client::Reply &reply, const QJsonArray &entries)>;
    /// GETs the collection at `path` page by page, following `next_cursor`
    /// while Core has more, and hands `done` every entry listed under `key`.
    /// A page that arrives once `live` answers false ends the load unseen.
    void authedList(const QString &path, const QString &key, Live live, ListDone done);

protected:
    /// A new translator retitles the commands and the root crumb and
    /// re-reads the sizes in the new locale.
    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void settingsChanged();
    void changed();
    void trailChanged();
    void downloadReady(const QUrl &file);
    void promptRename(const QString &currentName);
    void promptDelete(const QString &folderName);
    void promptUpload();
    void promptNew();
    void focusFilter();
    void showKeymap();
    void showSheet();
    void cycleRegion(int step);

private:
    /// One row of the command table: the keymap, sheet, buttons, and keys
    /// all read it. Titles are English and translated when read; a null
    /// title depends on where the session stands (`faceOf`); a null run is a
    /// command the window carries out (themes, languages).
    struct Command {
        QByteArray id;
        const char *title;
        bool (*usable)(const Session &);
        void (*run)(Session &);
    };
    static const QList<Command> &commands();
    /// The title and icon a command shows now.
    struct Face {
        const char *title;
        const char *icon;
    };
    /// A row's own title with its id as the icon; for a null title, "new"
    /// names the level's entry, and "trash" deletes a focused folder for good.
    Face faceOf(const Command &row) const;
    /// Names of one level: its id, the kind of entry it lists, its "new".
    struct LevelInfo {
        const char *name;
        const char *childKind;
        const char *newTitle;
    };
    static const LevelInfo &levelInfo(Level level);
    const Command *command(const QString &id) const;

    /// Where the explorer stands; one entry of the back/forward history.
    struct Location {
        QString orgId;
        QString spaceId;
        QString folderId;
        bool operator==(const Location &other) const
        {
            return orgId == other.orgId && spaceId == other.spaceId && folderId == other.folderId;
        }
    };

    void notify();
    void clearOrganization();
    void clearSpace();
    void goUp();
    void stepHistory(int delta);
    void cutPayload(const QString &payload);
    void pasteHere();
    /// A folder or document as a row names it: "folder" or "document", its
    /// id, and the revision it was read at.
    struct Entry {
        QString kind;
        QString id;
        int revision = 0;
    };
    /// The row under the cursor; the open document when no row has it;
    /// empty when neither.
    Entry focusedEntry() const;
    /// A folder's name or a document's title.
    QString nameOf(const Entry &entry) const;
    /// Trashes the focused document, or asks before deleting the focused
    /// folder, which has no trash.
    void trashFocused();
    /// Restores or purges (`action`) the last trashed document at the
    /// revision Core trashed it at; a restore `refills` the open folder.
    /// When Core holds it at another revision, it is forgotten.
    void settleLastTrashed(const char *action, bool refills);
    void requestUpload();
    void startUpload();
    void finishUpload(const QString &code);
    void setUploadError(const QString &code = QString(), const QString &name = QString());
    void reportUpload(const QString &code, const QString &name);
    /// The Core this build reaches from where it runs.
    static QString defaultApiBaseUrl();
    bool bindOrigin(const QString &apiBaseUrl);
    bool requireEmailPassword(const QString &email, const QString &password,
                              const QString &apiBaseUrl);
    void postAuth(const QString &path, const QJsonObject &body);
    void load();
    void persistIdentity();
    void setBusy();
    void fail(const QString &code, const QStringList &fields = {});
    /// Fails with Core's code and the fields its `details` name.
    void failReply(const Client::Reply &reply);
    void failConfirmation(const Client::Reply &reply);
    void clearError();
    void clearTokens();
    void clearContent();
    void applyAuth(const Client::Reply &reply);
    void authed(const QByteArray &method, const QString &path, const QJsonObject &body,
                const Client::Headers &headers, Client::Done done, bool retried);
    void refreshQuiet(const std::function<void(bool)> &done);
    void syncSpaces();
    void syncFiles();
    void syncDocuments();
    void applyPayload(const QString &folderId, const Entry &entry);
    /// A row's "kind:id:revision" drag and clipboard payload; empty when malformed.
    static Entry parsePayload(const QString &payload);
    void refreshLocation();
    QVariantList buildTrail() const;
    void promptRenameFocused();
    Location location() const;
    void go(const Location &to);
    void enter(const Location &to);

    Client m_client;
    CoreAddOnBackend m_coreAddOnBackend;
    AddOnManager m_addOns;
    ControlledDocs m_controlledDocs;
    OrgModel m_orgs;
    OrgAdmin m_orgAdmin;
    OrgBilling m_orgBilling;
    SpaceModel m_spaces;
    FolderModel m_folders;
    DocumentModel m_documents;
    EntryModel m_entries;
    FolderTreeModel m_folderTree;
    QVector<Location> m_history;
    QVariantList m_trail;
    int m_historyIndex = -1;
    bool m_signedIn = false;
    bool m_settingsActive = false;
    bool m_confirmationPending = false;
    bool m_confirmationResent = false;
    bool m_busy = false;
    bool m_resetSent = false;
    /// A queued file and the folder it was dropped into.
    struct Upload {
        QString name;
        QByteArray bytes;
        Location to;
    };
    QList<Upload> m_uploads;
    int m_uploadDone = 0;
    // Bumped when the queue is dropped, so late replies are ignored.
    int m_uploadRun = 0;
    double m_uploadProgress = 0;
    QString m_uploadError;
    QString m_uploadErrorName;
    QString m_errorCode;
    QStringList m_errorFields;
    QString m_email;
    QString m_apiBaseUrl = defaultApiBaseUrl();
    QString m_refreshToken;
    QString m_lastOrgId;
    Entry m_clip;
    QString m_focusPayload;
    /// The document Core last confirmed trashing, at its trashed revision.
    Entry m_lastTrashed;
};

} // namespace matome
