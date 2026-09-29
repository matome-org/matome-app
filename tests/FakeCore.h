#pragma once

#include <QByteArray>
#include <QCryptographicHash>
#include <QDateTime>
#include <QHash>
#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSet>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrl>
#include <QUrlQuery>

#include <algorithm>
#include <optional>
#include <utility>

namespace matome {
namespace test {

/// A Core stand-in on loopback: the routes the studio calls, with state in
/// memory. Tests drive it through this API; the `fakecore` binary exposes the
/// same controls over HTTP under /__e2e/ for the browser and Android suites.
class FakeCore : public QObject
{
    Q_OBJECT

public:
    /// How a faulted response fails: a status with an error code, a dropped
    /// connection (no response at all), or an expired access token (401).
    /// Hold answers as usual but parks the answer until `release`: the
    /// client's in-between state lasts as long as a test needs to look.
    enum class FaultMode { Status, Drop, Expire, Hold };

    explicit FakeCore(QObject *parent = nullptr)
        : QObject(parent)
    {
        connect(&m_server, &QTcpServer::newConnection, this, &FakeCore::accept);
        reset();
    }

    bool listen(const QHostAddress &address = QHostAddress::LocalHost, quint16 port = 0)
    {
        return m_server.listen(address, port);
    }

    /// Core dies: nothing listens and open connections drop. `listen` again
    /// on the same port brings it back with its state.
    void close()
    {
        m_server.close();
        for (QTcpSocket *socket : findChildren<QTcpSocket *>())
            socket->abort();
    }

    quint16 port() const { return m_server.serverPort(); }

    QString url() const
    {
        return QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort());
    }

    QString lastPath() const { return m_lastPath; }
    QString lastQuery() const { return m_lastQuery; }
    QJsonObject billingRequest() const { return m_billingRequest; }
    QDateTime checkoutExpiresAt;
    void seedPackages(const QJsonArray &packages) { m_packages = packages; }
    void seedSubscription(const QString &orgId, const QJsonObject &subscription)
    { m_subscriptions[orgId] = subscription; }
    void seedAddOns(const QString &orgId, const QJsonArray &products)
    { m_addOns[orgId] = products; }
    QString lastIdempotency() const { return m_lastIdempotency; }
    int hits() const { return m_hits; }

    /// How many answers a Hold fault parks.
    int held() const { return int(m_held.size()); }

    /// Sends every parked answer.
    void release()
    {
        const QList<Held> parked = std::exchange(m_held, {});
        for (const Held &one : parked) {
            if (one.socket)
                write(one.socket, one.reply);
        }
    }

    void seedDocument(const QString &spaceId, const QString &title, const QString &folderId = {},
                      const std::optional<QByteArray> &content = std::nullopt)
    {
        addDocument(spaceId, title, folderId, content);
    }

    void seedSpace(const QString &orgId, const QString &name) { addSpace(orgId, name); }

    // An organization of the signed-in user in which they hold `role`.
    void seedOrganization(const QString &name, const QString &role) { addOrg(name, role, m_user); }

    QString seedMember(const QString &orgId, const QString &email, const QString &role)
    {
        const QString id = QString::number(++m_nextPerson);
        m_members[orgId].append(QJsonObject{{QStringLiteral("id"), id},
                {QStringLiteral("email"), email}, {QStringLiteral("role"), role},
                {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}});
        return id;
    }

    /// The live document titled `title`, with the checksum of its stored bytes.
    QJsonObject documentTitled(const QString &title) const
    {
        for (const QJsonArray &list : m_documents) {
            for (const QJsonValue &value : list) {
                if (value.toObject().value(QStringLiteral("title")).toString() == title)
                    return withContent(value.toObject());
            }
        }
        return {};
    }

    /// Someone else renames the folder named or the live document titled
    /// `from` to `to`, which moves its revision on.
    void renameElsewhere(const QString &from, const QString &to)
    {
        const auto renameIn = [&](QHash<QString, QJsonArray> &bySpace, const QString &field) {
            for (QJsonArray &list : bySpace) {
                for (int at = 0; at < list.size(); ++at) {
                    QJsonObject item = list.at(at).toObject();
                    if (item.value(field).toString() != from)
                        continue;
                    item.insert(field, to);
                    list.replace(at, bumped(item));
                }
            }
        };
        renameIn(m_folders, QStringLiteral("name"));
        renameIn(m_documents, QStringLiteral("title"));
    }

    /// Someone else changes the trashed document titled `title`, which
    /// moves its revision on.
    void changeTrashedElsewhere(const QString &title)
    {
        for (QJsonObject &doc : m_trashed) {
            if (doc.value(QStringLiteral("title")).toString() == title)
                doc = bumped(doc);
        }
    }

    /// The checksum of the bytes held for the document titled `title`; empty
    /// before they land.
    QString landed(const QString &title) const
    {
        return documentTitled(title).value(QStringLiteral("content_sha256")).toString();
    }

    /// The next `count` requests whose method is `method` (any when empty)
    /// and whose path matches `path` fail as `mode` says.
    bool failNext(const QString &method, const QString &path, int count, FaultMode mode,
                  int status = 500, const QString &error = QStringLiteral("server_error"))
    {
        const QRegularExpression pattern(path);
        if (path.isEmpty() || !pattern.isValid() || count < 1)
            return false;
        m_faults.append({method.toUpper().toUtf8(), pattern, count, mode, status, error});
        return true;
    }

    /// Builds users, organizations, spaces, folders, and documents from one
    /// JSON description (the /__e2e/seed body) and answers the whole state.
    QJsonObject seed(const QJsonObject &spec)
    {
        for (const QJsonValue &value : spec.value(QStringLiteral("users")).toArray()) {
            const QJsonObject user = value.toObject();
            m_passwords.insert(user.value(QStringLiteral("email")).toString(),
                               user.value(QStringLiteral("password")).toString());
        }
        for (const QJsonValue &value : spec.value(QStringLiteral("organizations")).toArray()) {
            const QJsonObject org = value.toObject();
            const QString orgId = addOrg(org.value(QStringLiteral("name")).toString(), QStringLiteral("owner"),
                                         org.value(QStringLiteral("user")).toString(defaultUser()))
                                          .value(QStringLiteral("id"))
                                          .toString();
            for (const QJsonValue &spaceValue : org.value(QStringLiteral("spaces")).toArray()) {
                const QJsonObject space = spaceValue.toObject();
                const QString spaceId = addSpace(orgId, space.value(QStringLiteral("name")).toString())
                                                .value(QStringLiteral("id"))
                                                .toString();
                seedChildren(spaceId, QString(), space);
            }
        }
        return state();
    }

    /// Everything Core holds, flattened for assertions. Uploaded or seeded
    /// documents carry the SHA-256 and size of the bytes storage holds.
    QJsonObject state() const
    {
        QJsonArray orgs;
        for (const QString &user : sortedKeys(m_orgsByUser)) {
            for (const QJsonValue &value : m_orgsByUser.value(user)) {
                QJsonObject org = value.toObject();
                org.insert(QStringLiteral("user"), user);
                orgs.append(org);
            }
        }
        QJsonArray documents;
        for (const QString &spaceId : sortedKeys(m_documents)) {
            for (const QJsonValue &value : m_documents.value(spaceId))
                documents.append(withContent(value.toObject()));
        }
        QJsonArray trash;
        for (const QString &id : sortedKeys(m_trashed))
            trash.append(withContent(m_trashed.value(id)));
        QJsonArray faults;
        for (const Fault &fault : m_faults) {
            faults.append(QJsonObject{{QStringLiteral("method"), QString::fromUtf8(fault.method)},
                                      {QStringLiteral("path"), fault.path.pattern()},
                                      {QStringLiteral("count"), fault.count},
                                      {QStringLiteral("mode"), modeName(fault.mode)}});
        }
        return {{QStringLiteral("user"), m_user},
                {QStringLiteral("users"), QJsonArray::fromStringList(sortedKeys(m_passwords))},
                {QStringLiteral("organizations"), orgs},
                {QStringLiteral("spaces"), flatten(m_spaces)},
                {QStringLiteral("folders"), flatten(m_folders)},
                {QStringLiteral("documents"), documents},
                {QStringLiteral("trash"), trash},
                {QStringLiteral("faults"), faults},
                {QStringLiteral("held"), held()},
                {QStringLiteral("hits"), m_hits}};
    }

    void reset()
    {
        overflow = false;
        forcedStatus = 0;
        forcedError = QStringLiteral("server_error");
        m_faults.clear();
        // A Core that starts over drops what it held.
        for (const Held &one : std::exchange(m_held, {})) {
            if (one.socket)
                one.socket->abort();
        }
        m_user.clear();
        m_passwords = {{defaultUser(), QStringLiteral("secret12")}};
        m_pendingEmails.clear();
        m_sessionEpoch = 1;
        m_orgsByUser.clear();
        m_members.clear();
        m_subscriptions.clear();
        m_addOns.clear();
        m_billingRequest = {};
        checkoutExpiresAt = {};
        m_packages = {};
        m_invitations.clear();
        m_nextPerson = 0;
        m_spaces.clear();
        m_folders.clear();
        m_documents.clear();
        m_lastPath.clear();
        m_lastQuery.clear();
        m_lastBody.clear();
        m_lastAuth.clear();
        m_lastMatch.clear();
        m_lastIdempotency.clear();
        m_host.clear();
        m_hits = 0;
        m_nextOrg = 0;
        m_nextSpace = 0;
        m_nextFolder = 0;
        m_nextDocument = 0;
        m_nextUpload = 0;
        m_nextVersion = 0;
        m_uploads.clear();
        m_blobs.clear();
        m_trashed.clear();
    }

    bool confirmEmailInBrowser(const QString &email)
    {
        if (!m_pendingEmails.remove(email))
            return false;
        ++m_sessionEpoch;
        return true;
    }

    bool resetPasswordInBrowser(const QString &email, const QString &password)
    {
        if (!m_passwords.contains(email) || !passwordDetails(password).isEmpty())
            return false;
        m_passwords.insert(email, password);
        ++m_sessionEpoch;
        return true;
    }

    bool acceptInvitationInBrowser(const QString &email, const QString &name)
    {
        if (!m_passwords.contains(email) || m_pendingEmails.contains(email) || name.isEmpty())
            return false;
        addOrg(name, QStringLiteral("member"), email);
        return true;
    }

    static QString sha256(const QByteArray &bytes)
    {
        return QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
    }

    bool overflow = false;
    // Every non-control response answers this status (with `forcedError`)
    // until it is set back to 0.
    int forcedStatus = 0;
    QString forcedError = QStringLiteral("server_error");

private:
    // Every upload session is on its first generation.
    static constexpr int UploadGeneration = 1;

    struct Fault {
        QByteArray method;
        QRegularExpression path;
        int count;
        FaultMode mode;
        int status;
        QString error;
    };

    struct Held {
        QPointer<QTcpSocket> socket;
        QByteArray reply;
    };

    static QString modeName(FaultMode mode)
    {
        return mode == FaultMode::Drop ? QStringLiteral("drop")
             : mode == FaultMode::Expire ? QStringLiteral("expire")
             : mode == FaultMode::Hold ? QStringLiteral("hold")
                                       : QStringLiteral("status");
    }

    template<typename Map>
    static QStringList sortedKeys(const Map &map)
    {
        QStringList keys = map.keys();
        std::sort(keys.begin(), keys.end());
        return keys;
    }

    static QJsonArray flatten(const QHash<QString, QJsonArray> &byParent)
    {
        QJsonArray out;
        for (const QString &key : sortedKeys(byParent)) {
            for (const QJsonValue &value : byParent.value(key))
                out.append(value);
        }
        return out;
    }

    QJsonObject withContent(QJsonObject doc) const
    {
        const QString id = jsonId(doc.value(QStringLiteral("id")));
        const bool stored = m_blobs.contains(id);
        doc.insert(QStringLiteral("content_sha256"),
                   stored ? QJsonValue(sha256(m_blobs.value(id))) : QJsonValue(QJsonValue::Null));
        doc.insert(QStringLiteral("content_size"), stored ? m_blobs.value(id).size() : 0);
        return doc;
    }

    // Folders and documents of one level of a seed description; `repeat`
    // makes that many numbered copies ("Row 001" …) for long lists.
    void seedChildren(const QString &spaceId, const QString &parentId, const QJsonObject &level)
    {
        const auto copies = [](const QJsonObject &item, const QString &name) {
            const int repeat = item.value(QStringLiteral("repeat")).toInt();
            if (repeat < 1)
                return QStringList{name};
            QStringList names;
            for (int i = 1; i <= repeat; ++i)
                names.append(QStringLiteral("%1 %2").arg(name).arg(i, 3, 10, QLatin1Char('0')));
            return names;
        };
        for (const QJsonValue &value : level.value(QStringLiteral("folders")).toArray()) {
            const QJsonObject folder = value.toObject();
            for (const QString &name : copies(folder, folder.value(QStringLiteral("name")).toString())) {
                const QString id = addFolder(spaceId, parentId, name).value(QStringLiteral("id")).toString();
                seedChildren(spaceId, id, folder);
            }
        }
        for (const QJsonValue &value : level.value(QStringLiteral("documents")).toArray()) {
            const QJsonObject doc = value.toObject();
            const QJsonValue content = doc.value(QStringLiteral("content"));
            for (const QString &title : copies(doc, doc.value(QStringLiteral("title")).toString())) {
                if (content.isString())
                    addDocument(spaceId, title, parentId, content.toString().toUtf8());
                else
                    addDocument(spaceId, title, parentId);
            }
        }
    }

    void accept()
    {
        while (m_server.hasPendingConnections()) {
            QTcpSocket *socket = m_server.nextPendingConnection();
            socket->setParent(this);
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] { read(socket); });
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            connect(socket, &QObject::destroyed, this, [this, socket] { m_buffer.remove(socket); });
        }
    }

    void read(QTcpSocket *socket)
    {
        m_buffer[socket].append(socket->readAll());
        const QByteArray &buf = m_buffer[socket];
        const int headerEnd = buf.indexOf("\r\n\r\n");
        if (headerEnd < 0)
            return;
        const QByteArray headers = buf.left(headerEnd);
        int contentLength = 0;
        for (const QByteArray &line : headers.split('\n')) {
            const QByteArray trimmed = line.trimmed();
            if (trimmed.toLower().startsWith("content-length:"))
                contentLength = trimmed.mid(15).trimmed().toInt();
        }
        const int total = headerEnd + 4 + contentLength;
        if (buf.size() < total)
            return;
        const QByteArray request = buf.left(total);
        m_buffer[socket].remove(0, total);
        serve(socket, request);
    }

    void serve(QTcpSocket *socket, const QByteArray &request)
    {
        const int lineEnd = request.indexOf("\r\n");
        const QList<QByteArray> parts = request.left(lineEnd).split(' ');
        const QByteArray method = parts.value(0);
        QByteArray rawPath = parts.value(1);
        QString query;
        const int mark = rawPath.indexOf('?');
        if (mark >= 0) {
            query = QString::fromUtf8(rawPath.mid(mark + 1));
            rawPath = rawPath.left(mark);
        }
        const QString path = QString::fromUtf8(rawPath);
        const int headerEnd = request.indexOf("\r\n\r\n");
        const QByteArray body = request.mid(headerEnd + 4);
        QByteArray preflight;
        QString auth;
        std::optional<QByteArray> idempotency;
        QString match;
        QString host;
        for (const QByteArray &headerLine : request.left(headerEnd).split('\n')) {
            const QByteArray trimmed = headerLine.trimmed();
            const int colon = trimmed.indexOf(':');
            const QByteArray name = trimmed.left(colon).trimmed().toLower();
            const QByteArray value = trimmed.mid(colon + 1).trimmed();
            if (name == "authorization")
                auth = QString::fromUtf8(value);
            else if (name == "idempotency-key")
                idempotency = value;
            else if (name == "if-match")
                match = QString::fromUtf8(value);
            else if (name == "host")
                host = QString::fromUtf8(value);
            else if (name == "access-control-request-headers")
                preflight = value;
        }
        const QJsonObject json = QJsonDocument::fromJson(body).object();

        // The browser asks before a cross-origin PUT or an Authorization header.
        if (method == "OPTIONS") {
            write(socket, http(204, {}, preflight.isEmpty() ? QByteArrayLiteral("content-type") : preflight));
            return;
        }
        if (path.startsWith(QLatin1String("/__e2e/"))) {
            write(socket, control(method, path.mid(7), json));
            return;
        }

        ++m_hits;
        m_lastPath = path;
        m_lastQuery = query;
        m_lastBody = body;
        m_lastAuth = auth;
        m_lastMatch = match;
        m_host = host;
        if (idempotency && !idempotency->isEmpty())
            m_lastIdempotency = QString::fromUtf8(*idempotency);

        // Core refuses a mutation under /api/v1/ with a malformed Idempotency-Key
        // and a POST there without one.
        if (method != "GET" && path.startsWith(QLatin1String("/api/v1/"))) {
            if (idempotency && !wellFormedKey(*idempotency)) {
                write(socket, errorReply(422, QStringLiteral("invalid_idempotency_key")));
                return;
            }
            if (!idempotency && method == "POST") {
                write(socket, errorReply(428, QStringLiteral("idempotency_key_required")));
                return;
            }
        }

        const std::optional<Fault> fault = takeFault(method, path);
        if (fault && fault->mode == FaultMode::Drop) {
            socket->abort();
            return;
        }
        const bool holds = fault && fault->mode == FaultMode::Hold;
        const QByteArray reply = !fault || holds ? response(method, json)
                               : fault->mode == FaultMode::Expire ? errorReply(401, QStringLiteral("unauthenticated"))
                                                                  : errorReply(fault->status, fault->error);
        if (holds)
            m_held.append({socket, reply});
        else
            write(socket, reply);
    }

    // 1 to 128 printable ASCII characters, as Core takes an Idempotency-Key.
    static bool wellFormedKey(const QByteArray &key)
    {
        if (key.isEmpty() || key.size() > 128)
            return false;
        return std::all_of(key.begin(), key.end(), [](char c) { return c >= 0x21 && c <= 0x7e; });
    }

    std::optional<Fault> takeFault(const QByteArray &method, const QString &path)
    {
        for (int i = 0; i < m_faults.size(); ++i) {
            Fault &fault = m_faults[i];
            if ((!fault.method.isEmpty() && fault.method != method) || !fault.path.match(path).hasMatch())
                continue;
            const Fault taken = fault;
            if (--fault.count == 0)
                m_faults.removeAt(i);
            return taken;
        }
        return std::nullopt;
    }

    // The test-control API: /__e2e/reset, seed, fail, release, and state.
    QByteArray control(const QByteArray &method, const QString &route, const QJsonObject &json)
    {
        if (method == "GET" && route == QLatin1String("state"))
            return jsonReply(200, state());
        if (method != "POST")
            return errorReply(404, QStringLiteral("not_found"));
        if (route == QLatin1String("reset")) {
            reset();
            return jsonReply(200, state());
        }
        if (route == QLatin1String("seed"))
            return jsonReply(200, seed(json));
        if (route == QLatin1String("confirm-email"))
            return confirmEmailInBrowser(json.value(QStringLiteral("email")).toString())
                    ? jsonReply(200, state())
                    : errorReply(422, QStringLiteral("invalid_confirmation_token"));
        if (route == QLatin1String("reset-password"))
            return resetPasswordInBrowser(json.value(QStringLiteral("email")).toString(),
                                          json.value(QStringLiteral("password")).toString())
                    ? jsonReply(200, state())
                    : errorReply(422, QStringLiteral("invalid_reset_token"));
        if (route == QLatin1String("accept-invitation"))
            return acceptInvitationInBrowser(json.value(QStringLiteral("email")).toString(),
                                             json.value(QStringLiteral("name")).toString())
                    ? jsonReply(200, state())
                    : errorReply(422, QStringLiteral("invalid_invitation"));
        if (route == QLatin1String("release")) {
            release();
            return jsonReply(200, state());
        }
        if (route == QLatin1String("fail")) {
            const QString mode = json.value(QStringLiteral("mode")).toString(QStringLiteral("status"));
            const FaultMode parsed = mode == QLatin1String("drop") ? FaultMode::Drop
                                   : mode == QLatin1String("expire") ? FaultMode::Expire
                                   : mode == QLatin1String("hold") ? FaultMode::Hold
                                                                   : FaultMode::Status;
            if (modeName(parsed) != mode
                || !failNext(json.value(QStringLiteral("method")).toString(),
                             json.value(QStringLiteral("path")).toString(),
                             json.value(QStringLiteral("count")).toInt(1), parsed,
                             json.value(QStringLiteral("status")).toInt(500),
                             json.value(QStringLiteral("error")).toString(QStringLiteral("server_error"))))
                return errorReply(422, QStringLiteral("invalid_fault"));
            return jsonReply(200, state());
        }
        return errorReply(404, QStringLiteral("not_found"));
    }

    // Signed storage URLs point back at the host the client reached us by,
    // so the Android emulator (10.0.2.2) and a proxied page both get there.
    QString origin() const
    {
        return m_host.isEmpty() ? url() : QStringLiteral("http://") + m_host;
    }

    QByteArray response(const QByteArray &method, const QJsonObject &json)
    {
        if (overflow) {
            QByteArray body(1024 * 1024 + 64, 'x');
            return http(200, body);
        }
        if (forcedStatus)
            return errorReply(forcedStatus, forcedError);
        if (method == "GET" && m_lastPath == QLatin1String("/health"))
            return jsonReply(200, QJsonObject{{QStringLiteral("status"), QStringLiteral("ok")}});
        if (method == "GET" && m_lastPath == QLatin1String("/api/auth/me"))
            return jsonReply(200, QJsonObject{{QStringLiteral("user"), user(m_user.isEmpty() ? defaultUser() : m_user)}});

        if (m_lastPath.startsWith(QLatin1String("/api/v1/"))) {
            if (m_lastAuth != QStringLiteral("Bearer access-%1").arg(m_sessionEpoch))
                return errorReply(401, QStringLiteral("unauthenticated"));
            if (m_pendingEmails.contains(m_user))
                return errorReply(403, QStringLiteral("email_not_confirmed"));
            if (method == "GET" && m_lastPath == QLatin1String("/api/v1/organizations"))
                return listed(QStringLiteral("organizations"), m_orgsByUser.value(m_user));
            if (method == "POST" && m_lastPath == QLatin1String("/api/v1/organizations")) {
                return created(QStringLiteral("organization"), QStringLiteral("owner"), json, QStringLiteral("name"),
                               [this](const QString &name) { return addOrg(name, QStringLiteral("owner"), m_user); });
            }
            const QString orgPrefix = QStringLiteral("/api/v1/organizations/");
            if (m_lastPath.startsWith(orgPrefix) && m_lastPath.endsWith(QLatin1String("/spaces"))) {
                const QString orgId = m_lastPath.mid(orgPrefix.size(),
                        m_lastPath.size() - orgPrefix.size() - int(QStringLiteral("/spaces").size()));
                if (method == "GET")
                    return listed(QStringLiteral("spaces"), m_spaces.value(orgId));
                if (method == "POST") {
                    return created(QStringLiteral("space"), QStringLiteral("manager"), json, QStringLiteral("name"),
                                   [&](const QString &name) { return addSpace(orgId, name); });
                }
            }
            if (method == "GET" && m_lastPath == QLatin1String("/api/v1/add-ons"))
                return jsonReply(200, {{QStringLiteral("products"), addOnCatalog()}});
            const QStringList parts = m_lastPath.split(QLatin1Char('/'));
            if (const auto reply = organizationCommerce(method, parts, json))
                return *reply;
            if (const auto reply = organizationAdmin(method, parts, json))
                return *reply;
            if (parts.size() >= 8 && parts.at(1) == QLatin1String("api")
                && parts.at(2) == QLatin1String("v1") && parts.at(3) == QLatin1String("organizations")
                && parts.at(5) == QLatin1String("spaces")) {
                const QString spaceId = parts.at(6);
                const QString kind = parts.at(7);
                const QString itemId = parts.size() >= 9 ? parts.at(8) : QString();
                const QString action = parts.size() >= 10 ? parts.at(9) : QString();
                if (kind == QLatin1String("folders") && itemId.isEmpty()) {
                    if (method == "GET")
                        return listed(QStringLiteral("folders"), m_folders.value(spaceId));
                    if (method == "POST") {
                        const QString parentId = json.value(QStringLiteral("parent_id")).toString();
                        const QString name = storedName(json.value(QStringLiteral("name")));
                        if (const std::optional<QByteArray> refused = refuseName(spaceId, parentId, name))
                            return *refused;
                        return made(QStringLiteral("folder"), addFolder(spaceId, parentId, name));
                    }
                }
                if (kind == QLatin1String("folders") && action == QLatin1String("move")) {
                    const QString parentId = json.value(QStringLiteral("parent_id")).toString();
                    const QJsonObject folder = byId(m_folders.value(spaceId), itemId);
                    if (folder.isEmpty())
                        return errorReply(404, QStringLiteral("not_found"));
                    if (const std::optional<QByteArray> refused = refuseRevision(folder))
                        return *refused;
                    if (movesInside(spaceId, itemId, parentId))
                        return errorReply(409, QStringLiteral("folder_cycle"));
                    if (const std::optional<QByteArray> refused =
                                refuseName(spaceId, parentId, folder.value(QStringLiteral("name")).toString(), itemId))
                        return *refused;
                    update(m_folders[spaceId], itemId,
                           [&](QJsonObject &moved) { moved.insert(QStringLiteral("parent_id"), nullable(parentId)); });
                    return single(QStringLiteral("folder"), m_folders.value(spaceId), itemId);
                }
                if (kind == QLatin1String("documents") && itemId.isEmpty()) {
                    if (method == "GET") {
                        const QString folderId = query().queryItemValue(QStringLiteral("folder_id"), QUrl::FullyDecoded);
                        QJsonArray filtered;
                        for (const QJsonValue &value : m_documents.value(spaceId)) {
                            const QJsonObject doc = value.toObject();
                            const QString docFolder = doc.value(QStringLiteral("folder_id")).toString();
                            const bool root = folderId.isEmpty() || folderId == QLatin1String("root");
                            if ((root && docFolder.isEmpty()) || (!root && docFolder == folderId))
                                filtered.append(doc);
                        }
                        return listed(QStringLiteral("documents"), filtered);
                    }
                }
                if (kind == QLatin1String("documents") && action == QLatin1String("download")) {
                    QJsonObject data;
                    data.insert(QStringLiteral("url"), origin() + QStringLiteral("/files/") + itemId);
                    data.insert(QStringLiteral("method"), QStringLiteral("GET"));
                    return jsonReply(200, QJsonObject{{QStringLiteral("data"), data}});
                }
                if (kind == QLatin1String("documents") && action == QLatin1String("move")) {
                    const QString folderId = json.value(QStringLiteral("folder_id")).toString();
                    const QJsonObject doc = byId(m_documents.value(spaceId), itemId);
                    if (doc.isEmpty())
                        return errorReply(404, QStringLiteral("not_found"));
                    if (const std::optional<QByteArray> refused = refuseRevision(doc))
                        return *refused;
                    if (const std::optional<QByteArray> refused =
                                refuseName(spaceId, folderId, doc.value(QStringLiteral("title")).toString(), itemId))
                        return *refused;
                    update(m_documents[spaceId], itemId,
                           [&](QJsonObject &moved) { moved.insert(QStringLiteral("folder_id"), nullable(folderId)); });
                    return single(QStringLiteral("document"), m_documents.value(spaceId), itemId);
                }
                if (kind == QLatin1String("folders") && !itemId.isEmpty() && action.isEmpty()) {
                    if (method == "PATCH")
                        return rename(QStringLiteral("folder"), m_folders, spaceId, itemId, json);
                    if (method == "DELETE") {
                        const QJsonObject folder = byId(m_folders.value(spaceId), itemId);
                        if (folder.isEmpty())
                            return errorReply(404, QStringLiteral("not_found"));
                        if (const std::optional<QByteArray> refused = refuseRevision(folder))
                            return *refused;
                        if (holdsAnything(spaceId, itemId))
                            return errorReply(409, QStringLiteral("non_empty_resource"));
                        drop(m_folders[spaceId], itemId);
                        return http(204, {});
                    }
                }
                if (kind == QLatin1String("documents") && itemId.isEmpty() && method == "POST") {
                    const QString folderId = json.value(QStringLiteral("folder_id")).toString();
                    const QString title = storedName(json.value(QStringLiteral("title")));
                    if (const std::optional<QByteArray> refused = refuseName(spaceId, folderId, title))
                        return *refused;
                    return made(QStringLiteral("document"), addDocument(spaceId, title, folderId));
                }
                if (kind == QLatin1String("documents") && !itemId.isEmpty() && action.isEmpty()) {
                    if (method == "PATCH")
                        return rename(QStringLiteral("document"), m_documents, spaceId, itemId, json);
                    if (method == "DELETE") {
                        const QJsonObject doc = byId(m_documents.value(spaceId), itemId);
                        if (doc.isEmpty())
                            return errorReply(404, QStringLiteral("not_found"));
                        if (const std::optional<QByteArray> refused = refuseRevision(doc))
                            return *refused;
                        drop(m_documents[spaceId], itemId);
                        m_trashed.insert(itemId, bumped(doc));
                        return jsonReply(200, QJsonObject{{QStringLiteral("document"), m_trashed.value(itemId)}});
                    }
                }
            }
            if (m_lastPath.startsWith(orgPrefix) && m_lastPath.contains(QLatin1String("/uploads"))) {
                const QStringList up = m_lastPath.split(QLatin1Char('/'));
                if (method == "POST" && up.size() == 6 && up.at(5) == QLatin1String("uploads")) {
                    const QJsonValue checksum = json.value(QStringLiteral("checksum_sha256"));
                    if (checksum.isUndefined() || checksum.isNull())
                        return errorReply(422, QStringLiteral("checksum_required"));
                    static const QRegularExpression sha256Hex(QStringLiteral("^[0-9a-f]{64}$"));
                    if (!sha256Hex.match(checksum.toString()).hasMatch())
                        return errorReply(422, QStringLiteral("invalid_checksum"));
                    QJsonArray &list = m_documents[json.value(QStringLiteral("space_id")).toString()];
                    const int at = indexOf(list, jsonId(json.value(QStringLiteral("document_id"))));
                    if (at < 0)
                        return errorReply(404, QStringLiteral("not_found"));
                    QJsonObject doc = list.at(at).toObject();
                    doc.insert(QStringLiteral("pending_version_id"), newVersionId());
                    list.replace(at, doc);
                    const QString uploadId = QStringLiteral("upl-%1").arg(++m_nextUpload);
                    m_uploads.insert(uploadId, json);
                    QJsonObject request;
                    request.insert(QStringLiteral("url"), origin() + QStringLiteral("/files/") + uploadId);
                    request.insert(QStringLiteral("method"), QStringLiteral("PUT"));
                    request.insert(QStringLiteral("headers"), QJsonObject());
                    QJsonObject data;
                    data.insert(QStringLiteral("upload_id"), uploadId);
                    data.insert(QStringLiteral("generation"), UploadGeneration);
                    data.insert(QStringLiteral("mode"), QStringLiteral("single"));
                    data.insert(QStringLiteral("request"), request);
                    return jsonReply(201, QJsonObject{{QStringLiteral("data"), data},
                                                      {QStringLiteral("request_id"), requestId()}});
                }
                if (method == "POST" && up.size() >= 7 && up.last() == QLatin1String("complete"))
                    return completeUpload(up.at(up.size() - 2), json.value(QStringLiteral("generation")));
            }
            if (m_lastPath.startsWith(orgPrefix) && m_lastPath.contains(QLatin1String("/trash/"))) {
                const QStringList tr = m_lastPath.split(QLatin1Char('/'));
                const QString action = tr.last();
                const QString id = tr.size() >= 2 ? tr.at(tr.size() - 2) : QString();
                if (action == QLatin1String("restore")) {
                    if (!m_trashed.contains(id))
                        return errorReply(404, QStringLiteral("not_found"));
                    const QJsonObject doc = m_trashed.value(id);
                    if (const std::optional<QByteArray> refused = refuseRevision(doc))
                        return *refused;
                    const QString spaceId = doc.value(QStringLiteral("space_id")).toString();
                    if (const std::optional<QByteArray> refused =
                                refuseName(spaceId, doc.value(QStringLiteral("folder_id")).toString(),
                                           doc.value(QStringLiteral("title")).toString(), id))
                        return *refused;
                    m_documents[spaceId].append(bumped(m_trashed.take(id)));
                    return jsonReply(200, QJsonObject{{QStringLiteral("status"), action}});
                }
                if (action == QLatin1String("purge")) {
                    if (!m_trashed.contains(id))
                        return errorReply(404, QStringLiteral("not_found"));
                    if (const std::optional<QByteArray> refused = refuseRevision(m_trashed.value(id)))
                        return *refused;
                    m_trashed.remove(id);
                    m_blobs.remove(id);
                    return jsonReply(200, QJsonObject{{QStringLiteral("status"), action}});
                }
            }
            return errorReply(404, QStringLiteral("not_found"));
        }

        if (m_lastPath.startsWith(QLatin1String("/files/"))) {
            const QString id = m_lastPath.mid(QStringLiteral("/files/").size());
            if (method == "PUT") {
                m_blobs.insert(id, m_lastBody);
                return http(200, {});
            }
            if (method == "GET")
                return http(200, m_blobs.value(id, QByteArrayLiteral("file-bytes")));
        }

        if (method != "POST")
            return errorReply(404, QStringLiteral("not_found"));

        if (m_lastPath == QLatin1String("/api/auth/login")
            || m_lastPath == QLatin1String("/api/auth/register")) {
            const QString email = json.value(QStringLiteral("email")).toString();
            const QString password = json.value(QStringLiteral("password")).toString();
            const bool registering = m_lastPath.endsWith("register");
            if (!registering && m_passwords.value(email) != password)
                return errorReply(401, QStringLiteral("invalid_credentials"));
            if (registering) {
                QJsonObject details = passwordDetails(password);
                if (!QRegularExpression(QStringLiteral("^[^\\s]+@[^\\s]+$")).match(email).hasMatch())
                    details.insert(QStringLiteral("email"), QJsonArray{QStringLiteral("has invalid format")});
                else if (m_passwords.contains(email))
                    details.insert(QStringLiteral("email"), QJsonArray{QStringLiteral("has already been taken")});
                if (!details.isEmpty())
                    return errorReply(422, QStringLiteral("invalid_request"), details);
                m_passwords.insert(email, password);
                m_pendingEmails.insert(email);
            }
            ensureOrg(email);
            return session(email, registering ? 201 : 200);
        }
        if (m_lastPath == QLatin1String("/api/auth/forgot-password")) {
            return jsonReply(200, QJsonObject{{QStringLiteral("status"), QStringLiteral("ok")}});
        }
        if (m_lastPath == QLatin1String("/api/auth/refresh")) {
            if (json.value(QStringLiteral("refresh_token")).toString()
                    != QStringLiteral("refresh-%1").arg(m_sessionEpoch))
                return errorReply(401, QStringLiteral("invalid_refresh_token"));
            return session(m_user.isEmpty() ? defaultUser() : m_user, 200);
        }
        if (m_lastPath == QLatin1String("/api/auth/resend-confirmation")) {
            if (m_lastAuth != QStringLiteral("Bearer access-%1").arg(m_sessionEpoch))
                return errorReply(401, QStringLiteral("unauthenticated"));
            if (!m_pendingEmails.contains(m_user))
                return errorReply(422, QStringLiteral("email_already_confirmed"));
            return jsonReply(200, QJsonObject{{QStringLiteral("status"), QStringLiteral("ok")}});
        }
        if (m_lastPath == QLatin1String("/api/auth/logout"))
            return http(204, {});
        return errorReply(404, QStringLiteral("not_found"));
    }

    // Storage holds the PUT bytes; completing the session's `generation`
    // (the current one when absent) checks them against the checksum
    // declared at creation and makes the pending version the document's
    // current one, one revision later.
    QByteArray completeUpload(const QString &uploadId, const QJsonValue &generation)
    {
        if (!m_uploads.contains(uploadId) || !m_blobs.contains(uploadId))
            return errorReply(404, QStringLiteral("not_found"));
        if (!generation.isUndefined() && !generation.isNull()
            && generation.toVariant().toString() != QString::number(UploadGeneration))
            return errorReply(409, QStringLiteral("stale_upload_generation"));
        const QByteArray bytes = m_blobs.value(uploadId);
        if (sha256(bytes) != m_uploads.value(uploadId).value(QStringLiteral("checksum_sha256")).toString())
            return errorReply(422, QStringLiteral("verification_failed"));
        const QJsonObject upload = m_uploads.take(uploadId);
        const QString spaceId = upload.value(QStringLiteral("space_id")).toString();
        const QString documentId = jsonId(upload.value(QStringLiteral("document_id")));
        const bool stored = update(m_documents[spaceId], documentId, [&](QJsonObject &doc) {
            const int number = doc.value(QStringLiteral("current_version")).toObject()
                                       .value(QStringLiteral("version_number")).toInt() + 1;
            doc.insert(QStringLiteral("current_version"),
                       readyVersion(doc.value(QStringLiteral("pending_version_id")).toString(), number,
                                    upload.value(QStringLiteral("filename")).toString(),
                                    upload.value(QStringLiteral("content_type")).toString(), bytes));
            doc.insert(QStringLiteral("pending_version_id"), QJsonValue(QJsonValue::Null));
        });
        if (!stored)
            return errorReply(404, QStringLiteral("not_found"));
        m_blobs.insert(documentId, m_blobs.take(uploadId));
        return jsonReply(200, QJsonObject{{QStringLiteral("data"),
                                           QJsonObject{{QStringLiteral("state"), QStringLiteral("uploaded")}}},
                                          {QStringLiteral("request_id"), requestId()}});
    }

    QString newVersionId() { return QStringLiteral("version-%1").arg(++m_nextVersion); }

    // The `number`th version of a document, ready and current, holding `bytes`.
    static QJsonObject readyVersion(const QString &id, int number, const QString &filename,
                                    const QString &contentType, const QByteArray &bytes)
    {
        return {{QStringLiteral("id"), id},
                {QStringLiteral("version_number"), number},
                {QStringLiteral("state"), QStringLiteral("ready")},
                {QStringLiteral("current"), true},
                {QStringLiteral("ready_at"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                {QStringLiteral("filename"), filename},
                {QStringLiteral("content_type"), contentType},
                {QStringLiteral("byte_size"), bytes.size()},
                {QStringLiteral("checksum_sha256"), sha256(bytes)}};
    }

    void ensureOrg(const QString &email)
    {
        m_user = email;
        const QString name = email.section(QLatin1Char('@'), 0, 0) + QStringLiteral(" organization");
        for (const QJsonValue &value : m_orgsByUser.value(email)) {
            if (value.toObject().value(QStringLiteral("name")).toString() == name)
                return;
        }
        addOrg(name, QStringLiteral("owner"), email);
    }

    QJsonObject addOrg(const QString &name, const QString &role, const QString &user)
    {
        QJsonObject org;
        org.insert(QStringLiteral("id"), QStringLiteral("org-%1").arg(++m_nextOrg));
        org.insert(QStringLiteral("name"), name);
        org.insert(QStringLiteral("status"), QStringLiteral("active"));
        org.insert(QStringLiteral("revision"), 1);
        org.insert(QStringLiteral("role"), role);
        m_orgsByUser[user].append(org);
        seedMember(org.value(QStringLiteral("id")).toString(), user, role);
        return org;
    }

    static QJsonArray addOnCatalog()
    {
        const QJsonObject limits{{QStringLiteral("addon_classifier_calls_monthly"), 1000}};
        const QJsonObject sku{{QStringLiteral("key"), QStringLiteral("classifier-1000")},
                {QStringLiteral("version"), 1}, {QStringLiteral("stackable"), true},
                {QStringLiteral("limits"), limits}};
        const QJsonObject product{{QStringLiteral("key"), QStringLiteral("classifier")},
                {QStringLiteral("name"), QStringLiteral("Classification")},
                {QStringLiteral("meter_dimension"), QStringLiteral("addon_classifier_calls_monthly")},
                {QStringLiteral("skus"), QJsonArray{sku}}};
        return {product};
    }

    std::optional<QByteArray> organizationCommerce(const QByteArray &method, const QStringList &parts,
                                                  const QJsonObject &json)
    {
        if (parts.size() < 6 || (parts.at(5) != QLatin1String("billing") && parts.at(5) != QLatin1String("add-ons")))
            return std::nullopt;
        const QString orgId = parts.at(4);
        const QString role = byId(m_orgsByUser.value(m_user), orgId).value(QStringLiteral("role")).toString();
        if (role != QLatin1String("owner") && role != QLatin1String("admin") && role != QLatin1String("billing"))
            return errorReply(403, QStringLiteral("forbidden"));
        if (parts.at(5) == QLatin1String("billing")) {
            if (method == "GET" && parts.last() == QLatin1String("packages"))
                return jsonReply(200, {{QStringLiteral("packages"), m_packages}});
            if (method == "GET")
                return jsonReply(200, {{QStringLiteral("subscription"), m_subscriptions.contains(orgId)
                        ? QJsonValue(m_subscriptions.value(orgId)) : QJsonValue(QJsonValue::Null)}});
            if (role == QLatin1String("admin")) return errorReply(403, QStringLiteral("forbidden"));
            m_billingRequest = json;
            if (method == "POST" && parts.last() == QLatin1String("portal-sessions"))
                return jsonReply(200, {{QStringLiteral("url"), QStringLiteral("https://billing.stripe.com/session/test")}});
            if (method == "POST" && parts.last() == QLatin1String("checkout-sessions"))
                return jsonReply(200, {{QStringLiteral("url"), QStringLiteral("https://checkout.stripe.com/session/test")},
                        {QStringLiteral("expires_at"), (checkoutExpiresAt.isValid() ? checkoutExpiresAt
                                : QDateTime::currentDateTimeUtc().addSecs(1800)).toString(Qt::ISODateWithMs)}});
            if (method == "PUT" && parts.last() == QLatin1String("subscription"))
                return jsonReply(202, {{QStringLiteral("subscription"), m_subscriptions.value(orgId)}});
        } else {
            if (method == "GET") return jsonReply(200, {{QStringLiteral("products"), m_addOns.value(orgId)}});
            if (role == QLatin1String("billing")) return errorReply(403, QStringLiteral("forbidden"));
            if (parts.size() < 8) return std::nullopt;
            const QString key = parts.at(6);
            for (int i = 0; i < m_addOns[orgId].size(); ++i) {
                QJsonObject product = m_addOns[orgId].at(i).toObject();
                if (product.value(QStringLiteral("key")).toString() != key) continue;
                QJsonObject installation = product.value(QStringLiteral("installation")).toObject();
                if (method == "PUT") installation = json;
                installation.insert(QStringLiteral("status"), method == "PUT" ? QStringLiteral("active") : QStringLiteral("paused"));
                installation.insert(QStringLiteral("revision"), 2);
                product.insert(QStringLiteral("installation"), installation);
                m_addOns[orgId].replace(i, product);
                return jsonReply(200, {{QStringLiteral("installation"), installation}});
            }
        }
        return std::nullopt;
    }

    std::optional<QByteArray> organizationAdmin(const QByteArray &method, const QStringList &parts,
                                               const QJsonObject &json)
    {
        if (parts.size() < 5)
            return std::nullopt;
        const QString orgId = parts.at(4);
        const QString kind = parts.size() > 5 ? parts.at(5) : QString();
        if (!kind.isEmpty() && kind != QLatin1String("members") && kind != QLatin1String("invitations")
            && kind != QLatin1String("usage") && kind != QLatin1String("entitlements"))
            return std::nullopt;
        const QJsonObject org = byId(m_orgsByUser.value(m_user), orgId);
        if (org.isEmpty())
            return errorReply(403, QStringLiteral("organization_access_denied"));
        const QString role = org.value(QStringLiteral("role")).toString();
        if (role != QLatin1String("owner") && role != QLatin1String("admin")
                && !(role == QLatin1String("billing") && method == "GET"
                     && (kind == QLatin1String("usage") || kind == QLatin1String("entitlements"))))
            return errorReply(403, QStringLiteral("forbidden"));
        if (kind.isEmpty()) {
            if (method == "GET")
                return jsonReply(200, {{QStringLiteral("organization"), org}});
            if (method == "PATCH") {
                if (const auto refused = refuseRevision(org))
                    return *refused;
                update(m_orgsByUser[m_user], orgId, [&](QJsonObject &row) {
                    row.insert(QStringLiteral("name"), json.value(QStringLiteral("name")));
                });
                return single(QStringLiteral("organization"), m_orgsByUser.value(m_user), orgId);
            }
        }
        const QString id = parts.size() > 6 ? parts.at(6) : QString();
        if (kind == QLatin1String("members")) {
            if (method == "GET" && id.isEmpty())
                return listed(QStringLiteral("members"), m_members.value(orgId));
            const QJsonObject member = byId(m_members.value(orgId), id);
            if (member.isEmpty())
                return errorReply(404, QStringLiteral("not_found"));
            const QString nextRole = json.value(QStringLiteral("role")).toString();
            int owners = 0;
            for (const QJsonValue &row : m_members.value(orgId)) {
                if (row.toObject().value(QStringLiteral("role")) == QLatin1String("owner"))
                    ++owners;
            }
            if (member.value(QStringLiteral("role")) == QLatin1String("owner") && owners == 1
                && (method == "DELETE" || nextRole != QLatin1String("owner")))
                return errorReply(409, QStringLiteral("last_owner"));
            if (method == "PATCH") {
                update(m_members[orgId], id, [&](QJsonObject &row) {
                    row.insert(QStringLiteral("role"), nextRole);
                });
                if (member.value(QStringLiteral("email")).toString() == m_user) {
                    update(m_orgsByUser[m_user], orgId, [&](QJsonObject &row) {
                        row.insert(QStringLiteral("role"), nextRole);
                    });
                }
                return single(QStringLiteral("membership"), m_members.value(orgId), id);
            }
            if (method == "DELETE") {
                m_members[orgId].removeAt(indexOf(m_members.value(orgId), id));
                return http(204, {});
            }
        }
        if (kind == QLatin1String("invitations")) {
            if (method == "GET")
                return listed(QStringLiteral("invitations"), m_invitations.value(orgId));
            if (method == "POST" && id.isEmpty()) {
                const QString email = json.value(QStringLiteral("email")).toString();
                for (const QJsonValue &member : m_members.value(orgId)) {
                    if (member.toObject().value(QStringLiteral("email")) == email)
                        return errorReply(409, QStringLiteral("already_member"));
                }
                for (const QJsonValue &value : m_invitations.value(orgId)) {
                    const QJsonObject invitation = value.toObject();
                    if (invitation.value(QStringLiteral("email")) == email
                        && invitation.value(QStringLiteral("canceled_at")).isNull())
                        return errorReply(409, QStringLiteral("already_invited"));
                }
                const QJsonObject invitation{{QStringLiteral("id"), QString::number(++m_nextPerson)},
                        {QStringLiteral("email"), email}, {QStringLiteral("role"), json.value(QStringLiteral("role"))},
                        {QStringLiteral("expires_at"), QDateTime::currentDateTimeUtc().addDays(7).toString(Qt::ISODate)},
                        {QStringLiteral("accepted_at"), QJsonValue::Null},
                        {QStringLiteral("canceled_at"), QJsonValue::Null}, {QStringLiteral("revision"), 1}};
                m_invitations[orgId].append(invitation);
                return jsonReply(201, {{QStringLiteral("invitation"), invitation}});
            }
            if (method == "POST" && parts.size() == 8 && parts.at(7) == QLatin1String("cancel")) {
                if (!update(m_invitations[orgId], id, [&](QJsonObject &row) {
                    row.insert(QStringLiteral("canceled_at"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
                }))
                    return errorReply(404, QStringLiteral("not_found"));
                return http(204, {});
            }
        }
        if (method == "GET" && (kind == QLatin1String("usage") || kind == QLatin1String("entitlements"))) {
            const QJsonObject limits{{QStringLiteral("storage_bytes"), 1073741824},
                    {QStringLiteral("members"), 10}, {QStringLiteral("guests"), 5}, {QStringLiteral("spaces"), 10}};
            if (kind == QLatin1String("entitlements"))
                return jsonReply(200, {{kind, QJsonObject{{QStringLiteral("limits"), limits},
                        {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("free")}, {QStringLiteral("version"), 1}}}}}});
            QJsonObject dimensions;
            for (const QString &dimension : {QStringLiteral("storage_bytes"), QStringLiteral("members"),
                                             QStringLiteral("guests"), QStringLiteral("spaces")}) {
                const int confirmed = dimension == QLatin1String("storage_bytes") ? 1048576
                                    : dimension == QLatin1String("members") ? m_members.value(orgId).size()
                                    : dimension == QLatin1String("spaces") ? m_spaces.value(orgId).size() : 0;
                dimensions.insert(dimension, QJsonObject{{QStringLiteral("confirmed"), confirmed},
                        {QStringLiteral("reserved"), 0}, {QStringLiteral("limit"), limits.value(dimension)}});
            }
            return jsonReply(200, {{kind, QJsonObject{{QStringLiteral("dimensions"), dimensions},
                                                    {QStringLiteral("limits"), limits}}}});
        }
        return std::nullopt;
    }

    QJsonObject addFolder(const QString &spaceId, const QString &parentId, const QString &name)
    {
        QJsonObject folder;
        folder.insert(QStringLiteral("id"), QStringLiteral("folder-%1").arg(++m_nextFolder));
        folder.insert(QStringLiteral("space_id"), spaceId);
        folder.insert(QStringLiteral("parent_id"), nullable(parentId));
        folder.insert(QStringLiteral("name"), name);
        folder.insert(QStringLiteral("revision"), 1);
        m_folders[spaceId].append(folder);
        return folder;
    }

    QJsonObject addDocument(const QString &spaceId, const QString &title, const QString &folderId,
                            const std::optional<QByteArray> &content = std::nullopt)
    {
        QJsonObject doc;
        doc.insert(QStringLiteral("id"), QString::number(++m_nextDocument));
        doc.insert(QStringLiteral("space_id"), spaceId);
        doc.insert(QStringLiteral("folder_id"), nullable(folderId));
        doc.insert(QStringLiteral("title"), title);
        doc.insert(QStringLiteral("revision"), 1);
        doc.insert(QStringLiteral("current_version"),
                   content ? QJsonValue(readyVersion(newVersionId(), 1, title, QStringLiteral("text/plain"), *content))
                           : QJsonValue(QJsonValue::Null));
        doc.insert(QStringLiteral("pending_version_id"), QJsonValue(QJsonValue::Null));
        if (content)
            m_blobs.insert(doc.value(QStringLiteral("id")).toString(), *content);
        m_documents[spaceId].append(doc);
        return doc;
    }

    QJsonObject addSpace(const QString &orgId, const QString &name)
    {
        QJsonObject space;
        space.insert(QStringLiteral("id"), QStringLiteral("space-%1").arg(++m_nextSpace));
        space.insert(QStringLiteral("organization_id"), orgId);
        space.insert(QStringLiteral("name"), name);
        space.insert(QStringLiteral("status"), QStringLiteral("active"));
        space.insert(QStringLiteral("revision"), 1);
        m_spaces[orgId].append(space);
        return space;
    }

    static QJsonValue nullable(const QString &id)
    {
        return id.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(id);
    }

    static QString jsonId(const QJsonValue &value)
    {
        if (value.isString())
            return value.toString();
        if (value.isDouble())
            return QString::number(value.toInteger());
        return {};
    }

    static int indexOf(const QJsonArray &list, const QString &id)
    {
        for (int i = 0; i < list.size(); ++i) {
            if (jsonId(list.at(i).toObject().value(QStringLiteral("id"))) == id)
                return i;
        }
        return -1;
    }

    static QJsonObject byId(const QJsonArray &list, const QString &id)
    {
        const int at = indexOf(list, id);
        return at < 0 ? QJsonObject() : list.at(at).toObject();
    }

    // Lets `change` edit the item `id` of `list` and stores it back one
    // revision later; false when there is no such item.
    template<typename Change>
    static bool update(QJsonArray &list, const QString &id, Change change)
    {
        const int at = indexOf(list, id);
        if (at < 0)
            return false;
        QJsonObject item = list.at(at).toObject();
        change(item);
        list.replace(at, bumped(item));
        return true;
    }

    // `item` one revision later.
    static QJsonObject bumped(QJsonObject item)
    {
        item.insert(QStringLiteral("revision"), item.value(QStringLiteral("revision")).toInt() + 1);
        return item;
    }

    // Renames the folder or document `id` of `spaceId` to the request's name
    // (a folder's `name`, a document's `title`) within its own parent.
    QByteArray rename(const QString &kind, QHash<QString, QJsonArray> &bySpace, const QString &spaceId,
                      const QString &id, const QJsonObject &json)
    {
        const bool folder = kind == QLatin1String("folder");
        const QString field = folder ? QStringLiteral("name") : QStringLiteral("title");
        const QJsonObject item = byId(bySpace.value(spaceId), id);
        if (item.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (const std::optional<QByteArray> refused = refuseRevision(item))
            return *refused;
        const QString parentId = item.value(folder ? QStringLiteral("parent_id") : QStringLiteral("folder_id")).toString();
        const QString name = storedName(json.value(field));
        if (const std::optional<QByteArray> refused = refuseName(spaceId, parentId, name, id))
            return *refused;
        update(bySpace[spaceId], id, [&](QJsonObject &renamed) { renamed.insert(field, name); });
        return single(kind, bySpace.value(spaceId), id);
    }

    // A folder `name` or document `title` as Core stores it: NFC-normalized
    // and trimmed.
    static QString storedName(const QJsonValue &name)
    {
        return name.toString().normalized(QString::NormalizationForm_C).trimmed();
    }

    // The form under which two names collide: stored, then lowercased.
    static QString nameKey(const QString &name)
    {
        return storedName(name).toLower();
    }

    // Core's naming rule for a folder or document named `name` (stored form)
    // in the parent `parentId` (the root when empty) of `spaceId`: 422
    // invalid_name when it is empty, "." or "..", or holds "/", "\" or a
    // control character; 409 name_conflict when a folder or live document
    // there other than `selfId` has the same key. Nothing when it fits.
    std::optional<QByteArray> refuseName(const QString &spaceId, const QString &parentId, const QString &name,
                                         const QString &selfId = {}) const
    {
        const bool unusable = name.isEmpty() || name == QLatin1String(".") || name == QLatin1String("..")
                || std::any_of(name.cbegin(), name.cend(), [](QChar c) {
                       return c == QLatin1Char('/') || c == QLatin1Char('\\') || c.unicode() < 0x20
                               || c.unicode() == 0x7f;
                   });
        if (unusable)
            return errorReply(422, QStringLiteral("invalid_name"));
        const QString key = nameKey(name);
        const auto holds = [&](const QJsonArray &list, const QString &parentField, const QString &nameField) {
            return std::any_of(list.begin(), list.end(), [&](const QJsonValue &value) {
                const QJsonObject item = value.toObject();
                return jsonId(item.value(QStringLiteral("id"))) != selfId
                        && item.value(parentField).toString() == parentId
                        && nameKey(item.value(nameField).toString()) == key;
            });
        };
        if (holds(m_folders.value(spaceId), QStringLiteral("parent_id"), QStringLiteral("name"))
            || holds(m_documents.value(spaceId), QStringLiteral("folder_id"), QStringLiteral("title")))
            return errorReply(409, QStringLiteral("name_conflict"));
        return std::nullopt;
    }

    // 422 revision_required without an If-Match; 409 revision_conflict
    // unless it names the stored revision of `item`. Nothing when it does.
    std::optional<QByteArray> refuseRevision(const QJsonObject &item) const
    {
        if (m_lastMatch.isEmpty())
            return errorReply(422, QStringLiteral("revision_required"));
        if (m_lastMatch != QString::number(item.value(QStringLiteral("revision")).toInt()))
            return errorReply(409, QStringLiteral("revision_conflict"));
        return std::nullopt;
    }

    // Removes the item `id`, which `list` holds, from it.
    static void drop(QJsonArray &list, const QString &id) { list.removeAt(indexOf(list, id)); }

    // True when the folder `id` holds a folder or a document, a trashed one
    // included, as Core counts before it deletes a folder.
    bool holdsAnything(const QString &spaceId, const QString &id) const
    {
        const auto holds = [&](const QJsonArray &list, const QString &parentField) {
            return std::any_of(list.begin(), list.end(), [&](const QJsonValue &value) {
                return value.toObject().value(parentField).toString() == id;
            });
        };
        return holds(m_folders.value(spaceId), QStringLiteral("parent_id"))
                || holds(m_documents.value(spaceId), QStringLiteral("folder_id"))
                || std::any_of(m_trashed.cbegin(), m_trashed.cend(), [&](const QJsonObject &doc) {
                       return doc.value(QStringLiteral("folder_id")).toString() == id;
                   });
    }

    // True when `parentId` is the folder `id` itself or anywhere below it.
    bool movesInside(const QString &spaceId, const QString &id, const QString &parentId) const
    {
        const QJsonArray list = m_folders.value(spaceId);
        for (QString at = parentId; !at.isEmpty();
             at = byId(list, at).value(QStringLiteral("parent_id")).toString()) {
            if (at == id)
                return true;
        }
        return false;
    }

    QUrlQuery query() const { return QUrlQuery(m_lastQuery); }

    static QString defaultUser() { return QStringLiteral("ok@localhost"); }

    QJsonObject user(const QString &email) const
    {
        return {{QStringLiteral("id"), 1}, {QStringLiteral("email"), email},
                {QStringLiteral("email_confirmed"), !m_pendingEmails.contains(email)}};
    }

    QByteArray session(const QString &email, int status) const
    {
        QJsonObject body;
        body.insert(QStringLiteral("user"), user(email));
        body.insert(QStringLiteral("access_token"), QStringLiteral("access-%1").arg(m_sessionEpoch));
        body.insert(QStringLiteral("refresh_token"), QStringLiteral("refresh-%1").arg(m_sessionEpoch));
        body.insert(QStringLiteral("token_type"), QStringLiteral("Bearer"));
        return jsonReply(status, body);
    }

    // Ids of one kind share their prefix, so comparing them length first
    // orders them by their number: the order they were made in.
    static bool idBefore(const QString &a, const QString &b)
    {
        return a.size() != b.size() ? a.size() < b.size() : a < b;
    }

    // The page of `list` the request's `cursor` and `limit` ask for, as Core
    // pages a collection: ordered by id, `limit` 1 to 100 (else 50) entries
    // after the id the cursor encodes, under the list's own name and under
    // "data", with the cursor of the next page while there is one. A cursor
    // that does not encode an id is 400 invalid_cursor.
    QByteArray listed(const QString &kind, const QJsonArray &list) const
    {
        const QUrlQuery params = query();
        QString after;
        if (params.hasQueryItem(QStringLiteral("cursor"))) {
            const auto decoded = QByteArray::fromBase64Encoding(
                    params.queryItemValue(QStringLiteral("cursor"), QUrl::FullyDecoded).toLatin1(),
                    QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals
                            | QByteArray::AbortOnBase64DecodingErrors);
            after = QString::fromLatin1(decoded.decoded);
            static const QRegularExpression id(QStringLiteral("^(?:[0-9]+|[a-z]+-[0-9]+)$"));
            if (!decoded || !id.match(after).hasMatch())
                return errorReply(400, QStringLiteral("invalid_cursor"));
        }
        bool numeric = false;
        const int asked = params.queryItemValue(QStringLiteral("limit")).toInt(&numeric);
        const int limit = numeric && asked >= 1 && asked <= 100 ? asked : 50;

        QList<QJsonValue> sorted(list.begin(), list.end());
        std::sort(sorted.begin(), sorted.end(), [](const QJsonValue &a, const QJsonValue &b) {
            return idBefore(jsonId(a.toObject().value(QStringLiteral("id"))),
                            jsonId(b.toObject().value(QStringLiteral("id"))));
        });
        QJsonArray entries;
        bool more = false;
        for (const QJsonValue &value : sorted) {
            if (!after.isEmpty() && !idBefore(after, jsonId(value.toObject().value(QStringLiteral("id")))))
                continue;
            if (entries.size() == limit) {
                more = true;
                break;
            }
            entries.append(value);
        }
        const QJsonValue next = more
                ? QJsonValue(QString::fromLatin1(
                          jsonId(entries.last().toObject().value(QStringLiteral("id")))
                                  .toLatin1()
                                  .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals)))
                : QJsonValue(QJsonValue::Null);
        return jsonReply(200, QJsonObject{{kind, entries},
                                          {QStringLiteral("data"), entries},
                                          {QStringLiteral("page"),
                                           QJsonObject{{QStringLiteral("limit"), limit},
                                                       {QStringLiteral("next_cursor"), next},
                                                       {QStringLiteral("has_more"), more}}},
                                          {QStringLiteral("request_id"), requestId()}});
    }

    static QByteArray single(const QString &kind, const QJsonArray &list, const QString &id)
    {
        return jsonReply(200, QJsonObject{{kind, byId(list, id)}});
    }

    // Creates the organization or space `make` builds from the trimmed
    // `field` of the request, or refuses a blank one. Core answers it under
    // its own name and under "data", beside the creator's membership (`role`).
    template<typename Make>
    static QByteArray created(const QString &kind, const QString &role, const QJsonObject &json,
                              const QString &field, Make make)
    {
        const QString value = json.value(field).toString().trimmed();
        if (value.isEmpty())
            return errorReply(422, QStringLiteral("invalid_request"));
        const QJsonObject item = make(value);
        const QString id = item.value(QStringLiteral("id")).toString();
        const QJsonObject membership{{QStringLiteral("id"), QStringLiteral("membership-") + id},
                                     {kind + QStringLiteral("_id"), id},
                                     {QStringLiteral("role"), role},
                                     {QStringLiteral("status"), QStringLiteral("active")},
                                     {QStringLiteral("revision"), 1}};
        return jsonReply(201, QJsonObject{{kind, item},
                                          {QStringLiteral("data"), item},
                                          {QStringLiteral("membership"), membership},
                                          {QStringLiteral("request_id"), requestId()}});
    }

    // A created folder or document, answered under its own name.
    static QByteArray made(const QString &kind, const QJsonObject &item)
    {
        return jsonReply(201, QJsonObject{{kind, item}});
    }

    // Core's password rule, as its `details`: 8 to 72 characters.
    static QJsonObject passwordDetails(const QString &password)
    {
        if (password.size() < 8)
            return {{QStringLiteral("password"), QJsonArray{QStringLiteral("should be at least 8 character(s)")}}};
        if (password.size() > 72)
            return {{QStringLiteral("password"), QJsonArray{QStringLiteral("should be at most 72 character(s)")}}};
        return {};
    }

    static QString requestId()
    {
        static int nextRequest = 0;
        return QStringLiteral("req-%1").arg(++nextRequest);
    }

    // Core's one error body: the code under `code` and `error`, a request id,
    // `retry_after` seconds on a rate limit, and a validation failure's
    // `details`, the messages by field.
    static QByteArray errorReply(int status, const QString &code, const QJsonObject &details = {})
    {
        QJsonObject body{{QStringLiteral("code"), code},
                         {QStringLiteral("error"), code},
                         {QStringLiteral("request_id"), requestId()}};
        if (code == QLatin1String("rate_limited"))
            body.insert(QStringLiteral("retry_after"), 30);
        if (!details.isEmpty())
            body.insert(QStringLiteral("details"), details);
        return jsonReply(status, body);
    }

    static QByteArray jsonReply(int status, const QJsonObject &body)
    {
        return http(status, QJsonDocument(body).toJson(QJsonDocument::Compact));
    }

    // Open to any origin: the WASM page reaches Core and storage cross-origin.
    static QByteArray http(int status, const QByteArray &body, const QByteArray &allowHeaders = {})
    {
        const char *reason = status == 201 ? "Created" : status == 204 ? "No Content"
                         : status == 400 ? "Bad Request" : status == 401 ? "Unauthorized" : status == 404 ? "Not Found"
                         : status == 409 ? "Conflict"
                         : status == 422 ? "Unprocessable Entity"
                         : status == 429 ? "Too Many Requests"
                         : status >= 500 ? "Server Error" : "OK";
        QByteArray out;
        out += "HTTP/1.1 " + QByteArray::number(status) + " " + reason + "\r\n";
        out += "Content-Type: application/json\r\n";
        out += "Access-Control-Allow-Origin: *\r\n";
        if (!allowHeaders.isEmpty()) {
            out += "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n";
            out += "Access-Control-Allow-Headers: " + allowHeaders + "\r\n";
        }
        out += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
        out += "Connection: close\r\n\r\n";
        out += body;
        return out;
    }

    void write(QTcpSocket *socket, const QByteArray &bytes)
    {
        socket->write(bytes);
        socket->disconnectFromHost();
    }

    QTcpServer m_server;
    QHash<QTcpSocket *, QByteArray> m_buffer;
    QList<Fault> m_faults;
    QList<Held> m_held;
    QString m_user;
    QHash<QString, QString> m_passwords;
    QSet<QString> m_pendingEmails;
    int m_sessionEpoch = 1;
    QHash<QString, QJsonArray> m_orgsByUser;
    QHash<QString, QJsonArray> m_members;
    QHash<QString, QJsonObject> m_subscriptions;
    QHash<QString, QJsonArray> m_addOns;
    QJsonObject m_billingRequest;
    QJsonArray m_packages;
    QHash<QString, QJsonArray> m_invitations;
    int m_nextPerson = 0;
    QHash<QString, QJsonArray> m_spaces;
    QHash<QString, QJsonArray> m_folders;
    QHash<QString, QJsonArray> m_documents;
    QString m_lastPath;
    QString m_lastQuery;
    QByteArray m_lastBody;
    QString m_lastAuth;
    QString m_lastMatch;
    QString m_lastIdempotency;
    QString m_host;
    int m_hits = 0;
    int m_nextOrg = 0;
    int m_nextSpace = 0;
    int m_nextFolder = 0;
    int m_nextDocument = 0;
    int m_nextUpload = 0;
    int m_nextVersion = 0;
    QHash<QString, QJsonObject> m_uploads;
    QHash<QString, QByteArray> m_blobs;
    QHash<QString, QJsonObject> m_trashed;
};

} // namespace test
} // namespace matome
