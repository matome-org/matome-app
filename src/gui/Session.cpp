#include "Session.h"
#include "MatomeBuildConfig.h"

#include "JsonList.h"

#include <QCoreApplication>
#include <QEvent>
#include <QJsonObject>
#include <QStringList>
#include <QSettings>
#include <QUrl>
#include <QVariantMap>

#ifdef Q_OS_WASM
#include <QClipboard>
#include <QGuiApplication>
#endif

namespace matome {

Session::Session(QObject *parent)
    : QObject(parent)
    , m_orgs(*this)
    , m_orgAdmin(*this)
    , m_orgBilling(*this)
    , m_spaces(*this)
    , m_folders(*this)
    , m_documents(*this)
    , m_entries(*this)
    , m_folderTree(*this)
{
    connect(this, &Session::changed, this, [this] {
        if (!m_settingsActive)
            return;
        if (!signedIn())
            closeSettings();
        else {
            m_orgAdmin.open();
            m_orgBilling.open();
        }
    });
    load();
    m_trail = buildTrail();
    connect(&m_orgs, &OrgModel::changed, this, [this] {
        syncSpaces();
        notify();
    });
    connect(&m_spaces, &SpaceModel::changed, this, [this] {
        syncFiles();
        notify();
    });
    connect(&m_folders, &FolderModel::changed, this, [this] {
        syncDocuments();
        notify();
    });
    connect(&m_documents, &DocumentModel::changed, this, &Session::notify);
    connect(&m_documents, &DocumentModel::downloadReady, this, &Session::downloadReady);
    connect(&m_documents, &DocumentModel::trashed, this, [this](const QString &id, int revision) {
        m_lastTrashed = {QStringLiteral("document"), id, revision};
        notify();
    });
    QCoreApplication::instance()->installEventFilter(this);
}

void Session::openSettings()
{
    if (!signedIn() || m_settingsActive)
        return;
    m_settingsActive = true;
    m_orgAdmin.open();
    m_orgBilling.open();
    emit settingsChanged();
}

void Session::closeSettings()
{
    if (!m_settingsActive)
        return;
    m_settingsActive = false;
    m_orgAdmin.close();
    m_orgBilling.close();
    emit settingsChanged();
}

bool Session::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance())
        notify();
    return QObject::eventFilter(watched, event);
}

void Session::notify()
{
    // QML bindings hear `changed` before any C++ slot does, so the views
    // must be current before it is emitted.
    m_entries.refresh();
    m_folderTree.refresh();
    const QVariantList trail = buildTrail();
    const bool moved = trail != m_trail;
    m_trail = trail;
    emit changed();
    if (moved)
        emit trailChanged();
}

void Session::clearOrganization()
{
    m_documents.clear();
    m_folders.clear();
    m_spaces.clear();
    m_orgs.clearCurrent();
}

void Session::clearSpace()
{
    m_documents.clear();
    m_folders.clear();
    m_clip = {};
    m_spaces.clearCurrent();
    notify();
}

bool Session::inSpace() const
{
    return m_signedIn && !currentOrgId().isEmpty() && !currentSpaceId().isEmpty();
}

QString Session::spacePath(const QString &leaf) const
{
    return contentPath(currentOrgId(), currentSpaceId(), leaf);
}

Session::Level Session::where() const
{
    if (currentOrgId().isEmpty())
        return Level::Orgs;
    return currentSpaceId().isEmpty() ? Level::Spaces : Level::Files;
}

const Session::LevelInfo &Session::levelInfo(Level level)
{
    static const LevelInfo levels[] = {
            {"orgs", "org", QT_TR_NOOP("New organization")},
            {"spaces", "space", QT_TR_NOOP("New space")},
            {"files", "folder", QT_TR_NOOP("New folder")},
    };
    return levels[int(level)];
}

QString Session::level() const
{
    return QString::fromLatin1(levelInfo(where()).name);
}

QString Session::childKind() const
{
    return QString::fromLatin1(levelInfo(where()).childKind);
}

bool Session::loading() const
{
    switch (where()) {
    case Level::Orgs:
        return m_orgs.busy();
    case Level::Spaces:
        return m_spaces.busy();
    case Level::Files:
        break;
    }
    return m_folders.busy() || m_documents.busy();
}

QString Session::locationError() const
{
    switch (where()) {
    case Level::Orgs:
        return m_orgs.errorCode();
    case Level::Spaces:
        return m_spaces.errorCode();
    case Level::Files:
        break;
    }
    return m_folders.errorCode().isEmpty() ? m_documents.errorCode() : m_folders.errorCode();
}

void Session::setFilter(const QString &filter)
{
    if (filter == m_entries.filter())
        return;
    m_entries.setFilter(filter);
    notify();
}

QVariantList Session::buildTrail() const
{
    const auto crumb = [](const char *kind, const QString &id, const QString &name) {
        return QVariantMap{{QStringLiteral("kind"), QString::fromLatin1(kind)},
                           {QStringLiteral("id"), id},
                           {QStringLiteral("name"), name}};
    };
    QVariantList crumbs{crumb("root", QString(), tr("Matome"))};
    if (currentOrgId().isEmpty())
        return crumbs;
    crumbs.append(crumb("org", currentOrgId(), m_orgs.nameOf(currentOrgId())));
    if (currentSpaceId().isEmpty())
        return crumbs;
    crumbs.append(crumb("space", currentSpaceId(), m_spaces.nameOf(currentSpaceId())));
    for (const FolderRow &row : m_folders.path())
        crumbs.append(crumb("folder", row.id, row.name));
    return crumbs;
}

void Session::openEntry(const QString &kind, const QString &id)
{
    if (kind == QLatin1String("document"))
        m_documents.select(id);
    else
        navigate(kind, id);
}

void Session::navigate(const QString &kind, const QString &id)
{
    Location to;
    if (kind == QLatin1String("org"))
        to.orgId = id;
    else if (kind == QLatin1String("space"))
        to = {currentOrgId(), id, QString()};
    else if (kind == QLatin1String("folder"))
        to = {currentOrgId(), currentSpaceId(), id};
    else if (kind != QLatin1String("root"))
        return;
    go(to);
}

void Session::createHere(const QString &name)
{
    switch (where()) {
    case Level::Orgs:
        m_orgs.create(name);
        break;
    case Level::Spaces:
        m_spaces.create(name);
        break;
    case Level::Files:
        m_folders.create(name);
        break;
    }
}

void Session::goUp()
{
    Location up = location();
    switch (where()) {
    case Level::Orgs:
        return;
    case Level::Spaces:
        up.orgId.clear();
        break;
    case Level::Files:
        if (up.folderId.isEmpty())
            up.spaceId.clear();
        else
            up.folderId = m_folders.parentFolderId();
        break;
    }
    go(up);
}

void Session::toggleFolder(const QString &folderId)
{
    m_folderTree.toggle(folderId);
}

Session::Location Session::location() const
{
    return {currentOrgId(), currentSpaceId(), currentFolderId()};
}

void Session::go(const Location &to)
{
    const Location from = location();
    enter(to);
    const Location here = location();
    if (here == from)
        return;
    // Drop the forward branch; record the start when history has not seen it.
    m_history.resize(m_historyIndex + 1);
    if (m_history.isEmpty() || !(m_history.constLast() == from))
        m_history.append(from);
    m_history.append(here);
    m_historyIndex = m_history.size() - 1;
    notify();
}

void Session::enter(const Location &to)
{
    setUploadError();
    if (to.orgId.isEmpty()) {
        clearOrganization();
        return;
    }
    m_orgs.select(to.orgId);
    if (to.spaceId.isEmpty()) {
        clearSpace();
        return;
    }
    m_spaces.select(to.spaceId);
    m_folders.open(to.folderId);
}

void Session::stepHistory(int delta)
{
    const int target = m_historyIndex + delta;
    if (target < 0 || target >= m_history.size())
        return;
    m_historyIndex = target;
    enter(m_history.at(target));
    notify();
}

void Session::cutPayload(const QString &payload)
{
    const Entry entry = parsePayload(payload);
    if (entry.id.isEmpty())
        return;
    m_clip = entry;
#ifdef Q_OS_WASM
    // The browser hands Ctrl+V to the page only as a paste of what its
    // clipboard holds, and an empty one delivers nothing; the cut row's name
    // there is what lets the paste key reach pasteHere.
    QGuiApplication::clipboard()->setText(nameOf(entry));
#endif
    notify();
}

bool Session::acceptsDrop(const QString &folderId, const QString &payload) const
{
    const Entry dragged = parsePayload(payload);
    if (where() != Level::Files || dragged.id.isEmpty())
        return false;
    if (dragged.kind == QLatin1String("document")) // dragged from the open folder, it lives there
        return folderId != currentFolderId();
    if (m_folders.parentOf(dragged.id) == folderId)
        return false;
    for (QString at = folderId; !at.isEmpty(); at = m_folders.parentOf(at)) {
        if (at == dragged.id)
            return false;
    }
    return true;
}

void Session::dropPayload(const QString &folderId, const QString &payload)
{
    const Entry entry = parsePayload(payload);
    if (!entry.id.isEmpty())
        applyPayload(folderId, entry);
}

void Session::pasteHere()
{
    if (m_clip.id.isEmpty())
        return;
    applyPayload(m_folders.currentFolderId(), m_clip);
    m_clip = {};
    notify();
}

Session::Entry Session::parsePayload(const QString &payload)
{
    const QStringList parts = payload.split(QLatin1Char(':'));
    if (parts.size() != 3)
        return {};
    if (parts.at(0) != QLatin1String("folder") && parts.at(0) != QLatin1String("document"))
        return {};
    if (parts.at(1).isEmpty())
        return {};
    return {parts.at(0), parts.at(1), parts.at(2).toInt()};
}

void Session::applyPayload(const QString &folderId, const Entry &entry)
{
    if (entry.kind == QLatin1String("folder"))
        m_folders.move(entry.id, folderId, entry.revision);
    else
        m_documents.move(entry.id, folderId, entry.revision);
}

void Session::syncSpaces()
{
    if (!m_signedIn || m_orgs.currentOrgId().isEmpty()) {
        m_documents.clear();
        m_folders.clear();
        m_spaces.clear();
        return;
    }
    if (!m_orgs.busy())
        m_spaces.reload();
}

void Session::syncFiles()
{
    if (!inSpace()) {
        m_documents.clear();
        m_folders.clear();
        return;
    }
    if (!m_spaces.busy())
        m_folders.reload();
}

void Session::syncDocuments()
{
    if (!m_signedIn || m_spaces.currentSpaceId().isEmpty()) {
        m_documents.clear();
        return;
    }
    if (!m_folders.busy())
        m_documents.reload();
}

void Session::setApiBaseUrl(const QString &url)
{
    const QString trimmed = url.trimmed();
    if (trimmed == m_apiBaseUrl)
        return;
    m_apiBaseUrl = trimmed.isEmpty() ? defaultApiBaseUrl() : trimmed;
    persistIdentity();
    notify();
}

void Session::setLastOrgId(const QString &id)
{
    if (id == m_lastOrgId)
        return;
    m_lastOrgId = id;
    persistIdentity();
    notify();
}

void Session::signIn(const QString &email, const QString &password, const QString &apiBaseUrl)
{
    if (!requireEmailPassword(email, password, apiBaseUrl))
        return;
    QJsonObject body;
    body.insert(QStringLiteral("email"), m_email);
    body.insert(QStringLiteral("password"), password);
    postAuth(QStringLiteral("/api/auth/login"), body);
}

void Session::registerAccount(const QString &email, const QString &password,
                              const QString &apiBaseUrl)
{
    if (!requireEmailPassword(email, password, apiBaseUrl))
        return;
    QJsonObject body;
    body.insert(QStringLiteral("email"), m_email);
    body.insert(QStringLiteral("password"), password);
    postAuth(QStringLiteral("/api/auth/register"), body);
}

void Session::resendConfirmation()
{
    if (m_busy || !m_confirmationPending)
        return;
    m_confirmationResent = false;
    setBusy();
    authedPost(QStringLiteral("/api/auth/resend-confirmation"), {}, {},
               [this](const Client::Reply &reply) {
                   if (!reply.ok) {
                       failConfirmation(reply);
                       return;
                   }
                   m_busy = false;
                   m_confirmationResent = true;
                   clearError();
                   notify();
               });
}

void Session::requestPasswordReset(const QString &email, const QString &apiBaseUrl)
{
    if (m_busy)
        return;
    const QString trimmedEmail = email.trimmed();
    if (trimmedEmail.isEmpty() || !bindOrigin(apiBaseUrl)) {
        fail(QStringLiteral("invalid_request"));
        return;
    }
    m_email = trimmedEmail;
    persistIdentity();
    m_resetSent = false;
    m_client.abortAll();
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("email"), trimmedEmail);
    m_client.post(QStringLiteral("/api/auth/forgot-password"), body,
                  [this](const Client::Reply &reply) {
                      if (!reply.ok) {
                          failReply(reply);
                          return;
                      }
                      m_busy = false;
                      m_resetSent = true;
                      clearError();
                      notify();
                  });
}

void Session::refreshOrganizations()
{
    if (m_signedIn && !m_orgs.busy())
        m_orgs.reload();
}

void Session::signOut()
{
    const QString refresh = m_refreshToken;
    const QUrl origin = m_client.baseUrl();
    m_client.abortAll();
    if (!refresh.isEmpty() && origin.isValid()) {
        m_client.setAccessToken(QString());
        QJsonObject body;
        body.insert(QStringLiteral("refresh_token"), refresh);
        m_client.post(QStringLiteral("/api/auth/logout"), body, [](const Client::Reply &) {});
    }
    clearTokens();
    m_busy = false;
    m_resetSent = false;
    m_confirmationPending = false;
    m_confirmationResent = false;
    clearError();
    m_signedIn = false;
    clearContent();
    notify();
}

void Session::authedGet(const QString &path, Client::Done done)
{
    authed("GET", path, {}, {}, std::move(done), false);
}

void Session::authedPost(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                         Client::Done done)
{
    authed("POST", path, body, headers, std::move(done), false);
}

void Session::authedPut(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                        Client::Done done)
{
    authed("PUT", path, body, headers, std::move(done), false);
}

void Session::authedPatch(const QString &path, const QJsonObject &body, const Client::Headers &headers,
                          Client::Done done)
{
    authed("PATCH", path, body, headers, std::move(done), false);
}

void Session::authedDelete(const QString &path, const Client::Headers &headers, Client::Done done)
{
    authed("DELETE", path, {}, headers, std::move(done), false);
}

void Session::authedList(const QString &path, const QString &key, Live live, ListDone done)
{
    listPage(path, QString(), key, QJsonArray(), live, done);
}

void Session::listPage(const QString &path, const QString &cursor, const QString &key,
                       const QJsonArray &entries, const Live &live, const ListDone &done)
{
    const QString page = cursor.isEmpty()
            ? path
            : path + (path.contains(QLatin1Char('?')) ? QLatin1Char('&') : QLatin1Char('?'))
                    + QStringLiteral("cursor=") + QString::fromLatin1(QUrl::toPercentEncoding(cursor));
    authedGet(page, [this, path, key, entries, live, done](const Client::Reply &reply) {
        if (!live())
            return;
        if (!reply.ok) {
            done(reply, {});
            return;
        }
        QJsonArray all = entries;
        for (const QJsonValue &value : reply.json.value(key).toArray())
            all.append(value);
        const QJsonObject paging = reply.json.value(QStringLiteral("page")).toObject();
        if (paging.value(QStringLiteral("has_more")).toBool()) {
            listPage(path, paging.value(QStringLiteral("next_cursor")).toString(), key, all, live, done);
            return;
        }
        done(reply, all);
    });
}

QString Session::defaultApiBaseUrl()
{
    return QStringLiteral(MATOME_DEFAULT_SERVER);
}

bool Session::bindOrigin(const QString &apiBaseUrl)
{
    const QString trimmedUrl = apiBaseUrl.trimmed();
    if (trimmedUrl.isEmpty())
        return false;
    QUrl origin(trimmedUrl);
    if (!origin.isValid() || origin.host().isEmpty()
        || (origin.scheme() != QLatin1String("http")
            && origin.scheme() != QLatin1String("https"))) {
        return false;
    }
    origin.setPath(QString());
    origin.setQuery(QString());
    origin.setFragment(QString());
    m_apiBaseUrl = origin.toString(QUrl::RemoveUserInfo | QUrl::StripTrailingSlash);
    persistIdentity();
    m_client.setBaseUrl(origin);
    return true;
}

bool Session::requireEmailPassword(const QString &email, const QString &password,
                                   const QString &apiBaseUrl)
{
    if (m_busy)
        return false;
    const QString trimmedEmail = email.trimmed();
    if (trimmedEmail.isEmpty() || password.isEmpty()) {
        fail(QStringLiteral("invalid_request"));
        return false;
    }
    if (!bindOrigin(apiBaseUrl)) {
        fail(QStringLiteral("network"));
        return false;
    }
    m_email = trimmedEmail;
    persistIdentity();
    return true;
}

void Session::postAuth(const QString &path, const QJsonObject &body)
{
    m_client.abortAll();
    clearTokens();
    m_confirmationPending = false;
    m_confirmationResent = false;
    m_signedIn = false;
    setBusy();
    m_client.post(path, body, [this](const Client::Reply &reply) { applyAuth(reply); });
}

void Session::load()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("session"));
    const QString email = settings.value(QStringLiteral("email")).toString();
    const QString url = settings.value(QStringLiteral("apiBaseUrl")).toString();
    const QString org = settings.value(QStringLiteral("lastOrgId")).toString();
    settings.endGroup();
    if (!email.isEmpty())
        m_email = email;
    if (!url.isEmpty())
        m_apiBaseUrl = url;
    if (!org.isEmpty())
        m_lastOrgId = org;
}

void Session::persistIdentity()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("session"));
    settings.setValue(QStringLiteral("email"), m_email);
    settings.setValue(QStringLiteral("apiBaseUrl"), m_apiBaseUrl);
    settings.setValue(QStringLiteral("lastOrgId"), m_lastOrgId);
    settings.endGroup();
}

void Session::setBusy()
{
    m_busy = true;
    clearError();
    m_resetSent = false;
    notify();
}

void Session::fail(const QString &code, const QStringList &fields)
{
    m_busy = false;
    m_signedIn = false;
    m_confirmationPending = false;
    m_confirmationResent = false;
    m_errorCode = code;
    m_errorFields = fields;
    m_resetSent = false;
    clearTokens();
    clearContent();
    notify();
}

void Session::clearError()
{
    m_errorCode.clear();
    m_errorFields.clear();
}

void Session::failReply(const Client::Reply &reply)
{
    fail(failCode(reply), reply.json.value(QStringLiteral("details")).toObject().keys());
}

void Session::failConfirmation(const Client::Reply &reply)
{
    m_busy = false;
    m_errorCode = failCode(reply);
    m_errorFields = reply.json.value(QStringLiteral("details")).toObject().keys();
    notify();
}

void Session::clearTokens()
{
    m_client.setAccessToken(QString());
    m_refreshToken.clear();
}

void Session::clearContent()
{
    m_orgs.clear();
    m_spaces.clear();
    m_folders.clear();
    m_documents.clear();
    m_history.clear();
    m_historyIndex = -1;
    m_uploads.clear();
    ++m_uploadRun;
    m_uploadDone = 0;
    m_uploadProgress = 0;
    setUploadError();
}

void Session::applyAuth(const Client::Reply &reply)
{
    if (!reply.ok) {
        failReply(reply);
        return;
    }

    const QJsonObject user = reply.json.value(QStringLiteral("user")).toObject();
    const QJsonValue confirmed = user.value(QStringLiteral("email_confirmed"));
    const QString email = user.value(QStringLiteral("email")).toString();
    const QString access = reply.json.value(QStringLiteral("access_token")).toString();
    const QString refresh = reply.json.value(QStringLiteral("refresh_token")).toString();
    if (access.isEmpty() || !confirmed.isBool()) {
        fail(QStringLiteral("invalid_request"));
        return;
    }

    m_client.setAccessToken(access);
    m_refreshToken = refresh;
    if (!email.isEmpty())
        m_email = email;
    persistIdentity();
    m_busy = false;
    m_signedIn = confirmed.toBool();
    m_confirmationPending = !m_signedIn;
    m_confirmationResent = false;
    m_resetSent = false;
    clearError();
    if (m_signedIn)
        m_orgs.reload();
    notify();
}

void Session::authed(const QByteArray &method, const QString &path, const QJsonObject &body,
                     const Client::Headers &headers, Client::Done done, bool retried)
{
    const bool confirmationRoute = path == QLatin1String("/api/auth/resend-confirmation");
    if (!m_signedIn && !(m_confirmationPending && confirmationRoute)) {
        Client::Reply reply;
        reply.code = QStringLiteral("unauthenticated");
        done(reply);
        return;
    }

    auto finish = [this, method, path, body, headers, done, retried](const Client::Reply &reply) {
        if (reply.code == QLatin1String("unauthenticated") && !retried && !m_refreshToken.isEmpty()) {
            refreshQuiet([this, method, path, body, headers, done](bool ok) {
                if (!ok) {
                    fail(QStringLiteral("session_expired"));
                    Client::Reply failed;
                    failed.code = QStringLiteral("unauthenticated");
                    done(failed);
                    return;
                }
                authed(method, path, body, headers, done, true);
            });
            return;
        }
        done(reply);
    };

    if (method == "GET")
        m_client.get(path, finish, headers);
    else if (method == "PATCH")
        m_client.patch(path, body, finish, headers);
    else if (method == "PUT")
        m_client.put(path, body, finish, headers);
    else if (method == "DELETE")
        m_client.del(path, finish, headers);
    else
        m_client.post(path, body, finish, headers);
}

void Session::refreshQuiet(const std::function<void(bool)> &done)
{
    QJsonObject body;
    body.insert(QStringLiteral("refresh_token"), m_refreshToken);
    m_client.post(QStringLiteral("/api/auth/refresh"), body, [this, done](const Client::Reply &reply) {
        if (!reply.ok) {
            done(false);
            return;
        }
        const QString access = reply.json.value(QStringLiteral("access_token")).toString();
        const QString refresh = reply.json.value(QStringLiteral("refresh_token")).toString();
        if (access.isEmpty()) {
            done(false);
            return;
        }
        m_client.setAccessToken(access);
        if (!refresh.isEmpty())
            m_refreshToken = refresh;
        done(true);
    });
}

} // namespace matome
