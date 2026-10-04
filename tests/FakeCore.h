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
    QByteArray lastBody() const { return m_lastBody; }
    QString lastQuery() const { return m_lastQuery; }
    QJsonObject billingRequest() const { return m_billingRequest; }
    QDateTime checkoutExpiresAt;
    void seedPackages(const QJsonArray &packages) { m_packages = packages; }
    void seedSubscription(const QString &orgId, const QJsonObject &subscription)
    { m_subscriptions[orgId] = subscription; }
    void seedAddOns(const QString &orgId, const QJsonArray &products)
    {
        m_addOns[orgId] = products;
        syncAddOnRoles(orgId);
    }
    // A catalog product beside the built-in ones, with its settings schema.
    void seedCatalogProduct(const QJsonObject &product) { m_catalog.append(product); }
    // The body of the last installation change.
    QJsonObject addOnRequest() const { return m_addOnRequest; }
    QString lastIdempotency() const { return m_lastIdempotency; }
    // The `retry_after` seconds a rate limit answers.
    int retryAfter = 30;
    // The body of the last personal API token creation.
    QJsonObject tokenRequest() const { return m_tokenRequest; }
    // The session's sign-in is too old for token creation until the next login.
    void expireSignIn() { m_signInStale = true; }
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

    /// What `GET …/documents/:id/references` answers in `data` for `documentId`;
    /// both directions are empty until seeded.
    void seedReferences(const QString &documentId, const QJsonObject &data) { m_references.insert(documentId, data); }

    QString seedSpace(const QString &orgId, const QString &name)
    { return addSpace(orgId, name, QStringLiteral("private")).value(QStringLiteral("id")).toString(); }

    // An organization of the signed-in user in which they hold `role`.
    void seedOrganization(const QString &name, const QString &role) { addOrg(name, role, m_user); }

    // A member of `orgId` with a personal account under `email`, holding the
    // built-in organization role `role`.
    QString seedMember(const QString &orgId, const QString &email, const QString &role)
    {
        const QString id = QString::number(++m_nextPerson);
        m_members[orgId].append(QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("user_id"), userIdOf(email)},
                {QStringLiteral("email"), email}, {QStringLiteral("username"), QJsonValue::Null},
                {QStringLiteral("name"), QJsonValue::Null}, {QStringLiteral("managed"), false},
                {QStringLiteral("roles"), QJsonArray{role}},
                {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}});
        return id;
    }

    // An account `orgId` manages, signing in as `org-slug/username`, holding
    // `role` and waiting on the one-time setup code `code`. Answers its
    // identifier.
    QString seedManagedMember(const QString &orgId, const QString &username, const QString &role, const QString &code)
    {
        addManagedMember(orgId, username, {}, QJsonArray{role});
        const QString identifier = slugOf(orgId) + QLatin1Char('/') + username;
        m_setupCodes.insert(identifier, code);
        return identifier;
    }

    /// Grants the role `roleKey` on space `spaceId` of `orgId` to the member
    /// signing in as `identifier`, as a space access manager would.
    void seedSpaceGrant(const QString &orgId, const QString &spaceId, const QString &identifier, const QString &roleKey)
    {
        QString membership;
        for (const QJsonValue &member : m_members.value(orgId))
            if (member.toObject().value(QStringLiteral("user_id")).toString() == userIdOf(identifier))
                membership = member.toObject().value(QStringLiteral("id")).toString();
        QJsonObject grant = grantResource(QStringLiteral("space"), spaceId, {});
        grant.insert(QStringLiteral("id"), QStringLiteral("access-%1").arg(++m_nextAccess));
        grant.insert(QStringLiteral("role_id"), QStringLiteral("role-") + roleKey);
        grant.insert(QStringLiteral("role_key"), roleKey);
        grant.insert(QStringLiteral("principal_kind"), QStringLiteral("user"));
        grant.insert(QStringLiteral("organization_membership_id"), membership);
        grant.insert(QStringLiteral("group_id"), QJsonValue::Null);
        grant.insert(QStringLiteral("role_principal_id"), QJsonValue::Null);
        grant.insert(QStringLiteral("status"), QStringLiteral("active"));
        m_grants.append(grant);
    }

    /// Turns the add-on `key` on in `spaceId`, as its activation panel would.
    void seedActivation(const QString &spaceId, const QString &key)
    {
        m_activations.insert(spaceId + QLatin1Char('|') + key, QJsonObject{{QStringLiteral("status"), QStringLiteral("active")},
                                                                          {QStringLiteral("settings"), QJsonObject()},
                                                                          {QStringLiteral("revision"), 1}});
    }

    /// A group `groupName` of `orgId` with the members signing in as
    /// `identifiers`, given across the organization a custom role
    /// `roleName` of `actions`, as an administrator would.
    void seedGroupRole(const QString &orgId, const QString &groupName, const QStringList &identifiers,
                       const QString &roleName, const QStringList &actions)
    {
        const QString role = QStringLiteral("access-%1").arg(++m_nextAccess);
        accessRoles(orgId).append(QJsonObject{{QStringLiteral("id"), role}, {QStringLiteral("key"), QStringLiteral("custom-") + role},
                {QStringLiteral("name"), roleName}, {QStringLiteral("origin"), QStringLiteral("organization")},
                {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1},
                {QStringLiteral("actions"), QJsonArray::fromStringList(actions)}});
        const QString group = QStringLiteral("access-%1").arg(++m_nextAccess);
        m_groups[orgId].append(QJsonObject{{QStringLiteral("id"), group}, {QStringLiteral("name"), groupName},
                {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}});
        for (const QJsonValue &member : m_members.value(orgId))
            if (identifiers.contains(member.toObject().value(QStringLiteral("email")).toString()))
                m_groupMembers[group].append(QJsonObject{{QStringLiteral("id"), QStringLiteral("access-%1").arg(++m_nextAccess)},
                        {QStringLiteral("group_id"), group},
                        {QStringLiteral("organization_membership_id"), member.toObject().value(QStringLiteral("id"))}});
        m_principalRoles[orgId].append(QJsonObject{{QStringLiteral("id"), QStringLiteral("access-%1").arg(++m_nextAccess)},
                {QStringLiteral("role_id"), role}, {QStringLiteral("principal_kind"), QStringLiteral("group")},
                {QStringLiteral("organization_membership_id"), QJsonValue::Null}, {QStringLiteral("group_id"), group}});
    }

    /// A tag of `orgId` named `name`, restricted when `controlled`; answers its id.
    QString seedTag(const QString &orgId, const QString &name, bool controlled)
    {
        const QString id = QStringLiteral("access-%1").arg(++m_nextAccess);
        m_tags[orgId].append(QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("name"), name},
                {QStringLiteral("access_controlled"), controlled}, {QStringLiteral("status"), QStringLiteral("active")},
                {QStringLiteral("revision"), 1}});
        return id;
    }

    /// Puts the tag `tagId` of `orgId` on the document titled `title` in
    /// `spaceId`, as Core lists it in the document's `tag_assignments`.
    void seedDocumentTag(const QString &orgId, const QString &spaceId, const QString &title, const QString &tagId)
    {
        const QJsonObject tag = byId(m_tags.value(orgId), tagId);
        QJsonArray &documents = m_documents[spaceId];
        for (qsizetype at = 0; at < documents.size(); ++at) {
            QJsonObject doc = documents.at(at).toObject();
            if (doc.value(QStringLiteral("title")).toString() != title)
                continue;
            QJsonArray assignments = doc.value(QStringLiteral("tag_assignments")).toArray();
            assignments.append(QJsonObject{{QStringLiteral("name"), tag.value(QStringLiteral("name"))}, {QStringLiteral("tag_id"), tagId},
                                           {QStringLiteral("source"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("manual")},
                                                                                  {QStringLiteral("id"), QJsonValue::Null}}}});
            doc.insert(QStringLiteral("tag_assignments"), assignments);
            documents.replace(at, doc);
        }
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
                const QString spaceId = addSpace(orgId, space.value(QStringLiteral("name")).toString(),
                                                 space.value(QStringLiteral("visibility")).toString(QStringLiteral("private")))
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
        retryAfter = 30;
        m_faults.clear();
        // A Core that starts over drops what it held.
        for (const Held &one : std::exchange(m_held, {})) {
            if (one.socket)
                one.socket->abort();
        }
        m_user.clear();
        m_passwords = {{defaultUser(), QStringLiteral("secret12")}};
        m_pendingEmails.clear();
        m_setupCodes.clear();
        m_sessionEpoch = 1;
        m_orgsByUser.clear();
        m_members.clear();
        m_roles.clear();
        m_groups.clear();
        m_groupMembers.clear();
        m_principalRoles.clear();
        m_tags.clear();
        m_grants = {};
        m_activations.clear();
        m_nextAccess = 0;
        m_subscriptions.clear();
        m_addOns.clear();
        m_catalog = {};
        m_addOnRequest = {};
        m_apiTokens = {};
        m_tokenRequest = {};
        m_signInStale = false;
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
        if (m_lastPath == QLatin1String("/api/auth/tokens") || m_lastPath.startsWith(QLatin1String("/api/auth/tokens/")))
            return apiTokens(method, json);

        if (m_lastPath.startsWith(QLatin1String("/api/v1/"))) {
            if (m_lastAuth != QStringLiteral("Bearer access-%1").arg(m_sessionEpoch))
                return errorReply(401, QStringLiteral("unauthenticated"));
            if (method == "GET" && m_lastPath == QLatin1String("/api/v1/organizations")) {
                // Each organization with the built-in roles its membership holds directly.
                QJsonArray orgs;
                for (const QJsonValue &value : m_orgsByUser.value(m_user)) {
                    QJsonObject org = value.toObject();
                    org.insert(QStringLiteral("roles"), QJsonArray::fromStringList(rolesIn(org.value(QStringLiteral("id")).toString())));
                    orgs.append(org);
                }
                return listed(QStringLiteral("organizations"), orgs);
            }
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
                    const QString visibility = json.value(QStringLiteral("visibility")).toString();
                    if (visibility != QLatin1String("public") && visibility != QLatin1String("private"))
                        return errorReply(422, QStringLiteral("invalid_visibility"));
                    return created(QStringLiteral("space"), QStringLiteral("space_admin"), json, QStringLiteral("name"),
                                   [&](const QString &name) { return addSpace(orgId, name, visibility); });
                }
            }
            if (method == "GET" && m_lastPath == QLatin1String("/api/v1/add-ons")) {
                QJsonArray catalog = addOnCatalog();
                for (const auto &product : std::as_const(m_catalog)) catalog.append(product);
                return jsonReply(200, {{QStringLiteral("products"), catalog}});
            }
            const QStringList parts = m_lastPath.split(QLatin1Char('/'));
            if (const auto reply = organizationCommerce(method, parts, json))
                return *reply;
            if (const auto reply = organizationAdmin(method, parts, json))
                return *reply;
            if (const auto reply = organizationAccess(method, parts, json))
                return *reply;
            if (const auto reply = spaceAddOns(method, parts, json))
                return *reply;
            if (const auto reply = spaceLifecycle(method, parts, json))
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
                if (kind == QLatin1String("documents") && action == QLatin1String("controlled-docs") && method == "PUT")
                    return enableControl(parts.at(4), spaceId, itemId);
                if (kind == QLatin1String("documents") && action == QLatin1String("download")) {
                    QJsonObject data;
                    data.insert(QStringLiteral("url"), origin() + QStringLiteral("/files/") + itemId);
                    data.insert(QStringLiteral("method"), QStringLiteral("GET"));
                    return jsonReply(200, QJsonObject{{QStringLiteral("data"), data}});
                }
                if (kind == QLatin1String("documents") && action == QLatin1String("references") && method == "GET") {
                    const QJsonObject none{{QStringLiteral("incoming"), QJsonObject{{QStringLiteral("references"), QJsonArray()},
                                                                                    {QStringLiteral("hidden_count"), 0}}},
                                           {QStringLiteral("outgoing"), QJsonObject{{QStringLiteral("references"), QJsonArray()}}}};
                    return jsonReply(200, QJsonObject{{QStringLiteral("data"), m_references.value(itemId, none)}});
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
                    if (method == "GET")
                        return byId(m_folders.value(spaceId), itemId).isEmpty() ? errorReply(404, QStringLiteral("not_found"))
                                                                               : single(QStringLiteral("folder"), m_folders.value(spaceId), itemId);
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
                if (kind == QLatin1String("documents") && method == "GET" && !itemId.isEmpty()
                    && (action == QLatin1String("versions") || action == QLatin1String("reviews"))) {
                    const QJsonObject doc = byId(m_documents.value(spaceId), itemId);
                    if (doc.isEmpty())
                        return errorReply(404, QStringLiteral("not_found"));
                    if (action == QLatin1String("reviews"))
                        return listed(QStringLiteral("reviews"), {});
                    // Only the current version is kept, and it is published.
                    QJsonArray versions;
                    if (doc.value(QStringLiteral("current_version")).isObject()) {
                        QJsonObject current = doc.value(QStringLiteral("current_version")).toObject();
                        current.insert(QStringLiteral("publication_state"), QStringLiteral("published"));
                        versions.append(current);
                    }
                    return listed(QStringLiteral("data"), versions);
                }
                if (kind == QLatin1String("documents") && !itemId.isEmpty() && action.isEmpty()) {
                    if (method == "GET") {
                        if (byId(m_documents.value(spaceId), itemId).isEmpty())
                            return errorReply(404, QStringLiteral("not_found"));
                        return single(QStringLiteral("document"), m_documents.value(spaceId), itemId);
                    }
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

        if (m_lastPath == QLatin1String("/api/auth/login")) {
            const QString identifier = json.value(QStringLiteral("identifier")).toString();
            const QString key = identifier.contains(QLatin1Char('@')) ? identifier : identifier.toLower();
            if (key.isEmpty() || m_passwords.value(key) != json.value(QStringLiteral("password")).toString())
                return errorReply(401, QStringLiteral("invalid_credentials"));
            if (m_pendingEmails.contains(key))
                return errorReply(403, QStringLiteral("email_not_confirmed"));
            m_signInStale = false;
            if (key.contains(QLatin1Char('@')))
                ensureOrg(key);
            m_user = key;
            return session(key, 200);
        }
        if (m_lastPath == QLatin1String("/api/auth/register")) {
            const QString email = json.value(QStringLiteral("email")).toString();
            const QString password = json.value(QStringLiteral("password")).toString();
            QJsonObject details = passwordDetails(password);
            if (!QRegularExpression(QStringLiteral("^[^\\s]+@[^\\s]+$")).match(email).hasMatch())
                details.insert(QStringLiteral("email"), QJsonArray{QStringLiteral("has invalid format")});
            else if (m_passwords.contains(email))
                details.insert(QStringLiteral("email"), QJsonArray{QStringLiteral("has already been taken")});
            if (!details.isEmpty())
                return errorReply(422, QStringLiteral("invalid_request"), details);
            m_passwords.insert(email, password);
            m_pendingEmails.insert(email);
            return jsonReply(201, {{QStringLiteral("user"), user(email)}});
        }
        if (m_lastPath == QLatin1String("/api/auth/setup")) {
            const QString identifier = json.value(QStringLiteral("identifier")).toString().toLower();
            const QString code = json.value(QStringLiteral("code")).toString();
            if (code.isEmpty() || m_setupCodes.value(identifier) != code)
                return errorReply(401, QStringLiteral("invalid_setup_code"));
            if (const QJsonObject details = passwordDetails(json.value(QStringLiteral("password")).toString()); !details.isEmpty())
                return errorReply(422, QStringLiteral("invalid_request"), details);
            m_setupCodes.remove(identifier);
            m_passwords.insert(identifier, json.value(QStringLiteral("password")).toString());
            m_signInStale = false;
            m_user = identifier;
            return session(identifier, 200);
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
            if (!json.value(QStringLiteral("email")).isString())
                return errorReply(422, QStringLiteral("email_required"));
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
            // Publishing the version advances the document's revision, as Core does.
            doc.insert(QStringLiteral("revision"), doc.value(QStringLiteral("revision")).toInt() + 1);
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
        org.insert(QStringLiteral("slug"), QStringLiteral("%1-%2").arg(name.toLower().replace(QLatin1Char(' '), QLatin1Char('-'))).arg(m_nextOrg));
        org.insert(QStringLiteral("status"), QStringLiteral("active"));
        org.insert(QStringLiteral("revision"), 1);
        m_orgsByUser[user].append(org);
        seedMember(org.value(QStringLiteral("id")).toString(), user, role);
        return org;
    }

    QString orgName(const QString &orgId) const
    {
        for (const auto &orgs : m_orgsByUser)
            if (const QJsonObject org = byId(orgs, orgId); !org.isEmpty()) return org.value(QStringLiteral("name")).toString();
        return {};
    }

    // The account id Core gives the person who signs in as `identifier`.
    static QString userIdOf(const QString &identifier) { return QStringLiteral("user-") + identifier; }

    // The member row of the signed-in user in `orgId`.
    QJsonObject myMembership(const QString &orgId) const
    {
        for (const QJsonValue &member : m_members.value(orgId))
            if (member.toObject().value(QStringLiteral("user_id")).toString() == userIdOf(m_user))
                return member.toObject();
        return {};
    }

    // The built-in organization roles the signed-in user holds in `orgId`.
    QStringList rolesIn(const QString &orgId) const
    {
        QStringList roles;
        for (const QJsonValue &role : myMembership(orgId).value(QStringLiteral("roles")).toArray())
            roles.append(role.toString());
        return roles;
    }

    bool holdsAny(const QString &orgId, const QStringList &roles) const
    {
        const QStringList held = rolesIn(orgId);
        return std::any_of(roles.begin(), roles.end(), [&](const QString &role) { return held.contains(role); });
    }

    // Members of `orgId` holding `owner` directly.
    int owners(const QString &orgId) const
    {
        const QJsonArray members = m_members.value(orgId);
        return int(std::count_if(members.begin(), members.end(), [](const QJsonValue &member) {
            return member.toObject().value(QStringLiteral("roles")).toArray().contains(QStringLiteral("owner"));
        }));
    }

    static QJsonArray addOnCatalog()
    {
        const QJsonObject limits{{QStringLiteral("addon_classifier_calls_monthly"), 1000}};
        const QJsonObject sku{{QStringLiteral("key"), QStringLiteral("classifier-1000")},
                {QStringLiteral("version"), 1}, {QStringLiteral("stackable"), true},
                {QStringLiteral("limits"), limits}};
        const QJsonObject product{{QStringLiteral("key"), QStringLiteral("classifier")},
                {QStringLiteral("name"), QStringLiteral("Classification")},
                {QStringLiteral("capability"), QStringLiteral("addon.classifier")},
                {QStringLiteral("meter_dimension"), QStringLiteral("addon_classifier_calls_monthly")},
                {QStringLiteral("settings_schema"), QJsonObject{
                    {QStringLiteral("rerun_on_new_version"), QJsonObject{{QStringLiteral("type"), QStringLiteral("boolean")},
                                                                         {QStringLiteral("default"), false}}},
                    {QStringLiteral("labels"), QJsonObject{{QStringLiteral("type"), QStringLiteral("string_list")},
                                                           {QStringLiteral("required"), true},
                                                           {QStringLiteral("min_items"), 1}, {QStringLiteral("max_items"), 20}}}}},
                {QStringLiteral("skus"), QJsonArray{sku}}};
        return {product};
    }

    std::optional<QByteArray> organizationCommerce(const QByteArray &method, const QStringList &parts,
                                                  const QJsonObject &json)
    {
        if (parts.size() < 6 || (parts.at(5) != QLatin1String("billing") && parts.at(5) != QLatin1String("add-ons")))
            return std::nullopt;
        const QString orgId = parts.at(4);
        if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin"), QStringLiteral("billing")}))
            return errorReply(403, QStringLiteral("forbidden"));
        const bool installs = holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")});
        if (parts.at(5) == QLatin1String("billing")) {
            if (method == "GET" && parts.last() == QLatin1String("packages"))
                return jsonReply(200, {{QStringLiteral("packages"), m_packages}});
            if (method == "GET")
                return jsonReply(200, {{QStringLiteral("subscription"), m_subscriptions.contains(orgId)
                        ? QJsonValue(m_subscriptions.value(orgId)) : QJsonValue(QJsonValue::Null)}});
            if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("billing")})) return errorReply(403, QStringLiteral("forbidden"));
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
            if (!installs) return errorReply(403, QStringLiteral("forbidden"));
            if (parts.size() < 8) return std::nullopt;
            const QString key = parts.at(6);
            for (int i = 0; i < m_addOns[orgId].size(); ++i) {
                QJsonObject product = m_addOns[orgId].at(i).toObject();
                if (product.value(QStringLiteral("key")).toString() != key) continue;
                QJsonObject installation = product.value(QStringLiteral("installation")).toObject();
                m_addOnRequest = json;
                if (method == "PATCH") {
                    QJsonObject settings = installation.value(QStringLiteral("settings")).toObject();
                    const auto patch = json.value(QStringLiteral("settings")).toObject();
                    for (auto it = patch.begin(); it != patch.end(); ++it) settings.insert(it.key(), it.value());
                    installation.insert(QStringLiteral("settings"), settings);
                }
                // An uninstall marks the installation uninstalled, its roles'
                // grants and space activations kept; a pause leaves an
                // uninstalled one so; a PUT reactivates either. A new
                // installation answers for the installer's membership.
                if (method == "PUT") {
                    const QJsonValue responsible = json.contains(QStringLiteral("responsible_membership_id"))
                            ? json.value(QStringLiteral("responsible_membership_id"))
                            : installation.contains(QStringLiteral("responsible_membership_id"))
                            ? installation.value(QStringLiteral("responsible_membership_id"))
                            : myMembership(orgId).value(QStringLiteral("id"));
                    installation = QJsonObject{{QStringLiteral("id"), QStringLiteral("installation-") + key},
                            {QStringLiteral("product_key"), key}, {QStringLiteral("settings"), json.value(QStringLiteral("settings")).toObject()},
                            {QStringLiteral("responsible_membership_id"), responsible},
                            {QStringLiteral("revision"), installation.value(QStringLiteral("revision"))}};
                    installation.insert(QStringLiteral("status"), QStringLiteral("active"));
                } else if (method == "PATCH" && json.contains(QStringLiteral("responsible_membership_id"))) {
                    installation.insert(QStringLiteral("responsible_membership_id"), json.value(QStringLiteral("responsible_membership_id")));
                } else if (method == "DELETE") {
                    installation.insert(QStringLiteral("status"), QStringLiteral("uninstalled"));
                } else if (method != "PATCH" && installation.value(QStringLiteral("status")) != QLatin1String("uninstalled")) {
                    installation.insert(QStringLiteral("status"), QStringLiteral("paused"));
                }
                installation.insert(QStringLiteral("revision"), installation.value(QStringLiteral("revision")).toInt() + 1);
                product.insert(QStringLiteral("installation"), installation);
                m_addOns[orgId].replace(i, product);
                syncAddOnRoles(orgId);
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
        if ((!kind.isEmpty() && kind != QLatin1String("members") && kind != QLatin1String("invitations")
             && kind != QLatin1String("usage") && kind != QLatin1String("entitlements"))
            || (parts.size() == 8 && parts.at(7) == QLatin1String("access")))
            return std::nullopt;
        const QJsonObject org = byId(m_orgsByUser.value(m_user), orgId);
        if (org.isEmpty())
            return errorReply(403, QStringLiteral("organization_access_denied"));
        if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")})
                && !(holdsAny(orgId, {QStringLiteral("billing")}) && method == "GET"
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
            if (method == "POST" && id.isEmpty()) {
                const QString username = json.value(QStringLiteral("username")).toString().toLower();
                static const QRegularExpression valid(QStringLiteral("^[a-z0-9._-]{2,64}$"));
                if (!valid.match(username).hasMatch())
                    return errorReply(422, QStringLiteral("invalid_username"));
                const QJsonArray roles = invitedRoles(json);
                if (roles.isEmpty())
                    return errorReply(422, QStringLiteral("invalid_role"));
                const QString password = json.value(QStringLiteral("password")).toString();
                if (json.contains(QStringLiteral("password")) && (password.size() < 8 || password.size() > 72))
                    return errorReply(422, QStringLiteral("invalid_request"));
                for (const QJsonValue &member : m_members.value(orgId))
                    if (member.toObject().value(QStringLiteral("username")).toString() == username)
                        return errorReply(409, QStringLiteral("username_taken"));
                QJsonObject answer{{QStringLiteral("member"), addManagedMember(orgId, username, json.value(QStringLiteral("name")).toString(), roles)},
                                   {QStringLiteral("request_id"), requestId()}};
                if (password.isEmpty()) {
                    const QJsonObject setup = issueSetupCode(slugOf(orgId) + QLatin1Char('/') + username);
                    for (auto it = setup.begin(); it != setup.end(); ++it) answer.insert(it.key(), it.value());
                }
                return jsonReply(201, answer);
            }
            const QJsonObject member = byId(m_members.value(orgId), id);
            if (member.isEmpty())
                return errorReply(404, QStringLiteral("not_found"));
            if (method == "POST" && parts.size() == 8 && parts.at(7) == QLatin1String("setup-code")) {
                if (!member.value(QStringLiteral("managed")).toBool())
                    return errorReply(409, QStringLiteral("not_managed"));
                QJsonObject answer = issueSetupCode(slugOf(orgId) + QLatin1Char('/') + member.value(QStringLiteral("username")).toString());
                answer.insert(QStringLiteral("request_id"), requestId());
                return jsonReply(200, answer);
            }
            if (method == "DELETE" && member.value(QStringLiteral("roles")).toArray().contains(QStringLiteral("owner"))
                && owners(orgId) == 1)
                return errorReply(409, QStringLiteral("last_owner"));
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
                const QJsonArray roles = invitedRoles(json);
                if (roles.isEmpty())
                    return errorReply(422, QStringLiteral("invalid_role"));
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
                // Each offered space once, with distinct roles that exist, as a
                // replacement of grants there would be checked.
                const QJsonValue offered = json.value(QStringLiteral("grants"));
                if (!offered.isUndefined() && !offered.isArray())
                    return errorReply(422, QStringLiteral("invalid_request"));
                QStringList spaces;
                for (const QJsonValue &value : offered.toArray()) {
                    const QJsonObject grant = value.toObject();
                    const QJsonArray roleIds = grant.value(QStringLiteral("role_ids")).toArray();
                    QStringList ids;
                    for (const QJsonValue &role : roleIds) ids.append(jsonId(role));
                    const QString space = grant.value(QStringLiteral("space_id")).toString();
                    if (space.isEmpty() || ids.isEmpty() || QStringList(ids).removeDuplicates() > 0 || spaces.contains(space))
                        return errorReply(422, QStringLiteral("invalid_request"));
                    spaces.append(space);
                    if (byId(m_spaces.value(orgId), space).isEmpty())
                        return errorReply(404, QStringLiteral("not_found"));
                    for (const QString &role : std::as_const(ids))
                        if (byId(accessRoles(orgId), role).isEmpty())
                            return errorReply(404, QStringLiteral("not_found"));
                }
                const QJsonObject invitation{{QStringLiteral("id"), QString::number(++m_nextPerson)},
                        {QStringLiteral("email"), email}, {QStringLiteral("roles"), roles},
                        {QStringLiteral("expires_at"), QDateTime::currentDateTimeUtc().addDays(7).toString(Qt::ISODate)},
                        {QStringLiteral("accepted_at"), QJsonValue::Null},
                        {QStringLiteral("canceled_at"), QJsonValue::Null},
                        {QStringLiteral("grants"), offered.isArray() ? offered.toArray() : QJsonArray()},
                        {QStringLiteral("revision"), 1}};
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
            if (kind == QLatin1String("entitlements")) {
                QJsonObject capabilities;
                for (const auto &value : m_addOns.value(orgId)) {
                    const auto product = value.toObject();
                    capabilities.insert(QStringLiteral("addon.") + product.value(QStringLiteral("key")).toString(),
                            !product.value(QStringLiteral("assignments")).toArray().isEmpty());
                }
                return jsonReply(200, {{kind, QJsonObject{{QStringLiteral("limits"), limits}, {QStringLiteral("capabilities"), capabilities},
                        {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("free")}, {QStringLiteral("version"), 1}}}}}});
            }
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

    // The roles a product declares in Core's catalog: `{key, name, actions}`.
    static QJsonArray declaredRoles(const QString &productKey)
    {
        if (productKey != QLatin1String("controlled_docs"))
            return {};
        const auto role = [](const QString &verb, const QString &name, const QStringList &actions) {
            QStringList keys;
            for (const QString &action : actions) keys.append(QStringLiteral("addon.controlled_docs.") + action);
            return QJsonObject{{QStringLiteral("key"), QStringLiteral("addon.controlled_docs.") + verb},
                               {QStringLiteral("name"), name}, {QStringLiteral("actions"), QJsonArray::fromStringList(keys)}};
        };
        return {role(QStringLiteral("reviewer"), QStringLiteral("Controlled documents reviewer"), {QStringLiteral("review_read")}),
                role(QStringLiteral("approver"), QStringLiteral("Controlled documents approver"),
                     {QStringLiteral("review_read"), QStringLiteral("approve")}),
                role(QStringLiteral("manager"), QStringLiteral("Controlled documents manager"),
                     {QStringLiteral("review_read"), QStringLiteral("document_manage")})};
    }

    // Lists the declared roles of every active installation; a paused or uninstalled one's roles are archived.
    void syncAddOnRoles(const QString &orgId)
    {
        QJsonArray &roles = accessRoles(orgId);
        for (qsizetype at = 0; at < roles.size(); ++at)
            if (roles.at(at).toObject().value(QStringLiteral("origin")) == QLatin1String("add_on")) roles.removeAt(at--);
        for (const QJsonValue &value : std::as_const(m_addOns[orgId])) {
            const QJsonObject product = value.toObject();
            if (product.value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")) != QLatin1String("active"))
                continue;
            const QString productKey = product.value(QStringLiteral("key")).toString();
            for (const QJsonValue &declared : declaredRoles(productKey)) {
                QJsonObject role = declared.toObject();
                role.insert(QStringLiteral("id"), QStringLiteral("role-") + role.value(QStringLiteral("key")).toString());
                role.insert(QStringLiteral("origin"), QStringLiteral("add_on"));
                role.insert(QStringLiteral("status"), QStringLiteral("active"));
                role.insert(QStringLiteral("built_in"), true);
                role.insert(QStringLiteral("add_on_installation_id"), QStringLiteral("installation-") + productKey);
                roles.append(role);
            }
        }
    }

    // Core's atomic space roles: what each one adds over the base actions.
    static QList<std::pair<QString, QStringList>> atomicRoles()
    {
        const QStringList base{QStringLiteral("space.read_metadata"), QStringLiteral("event_history.read")};
        const QStringList read = base + QStringList{QStringLiteral("content.list"), QStringLiteral("content.read_metadata"),
                                                    QStringLiteral("content.download")};
        return {{QStringLiteral("content_reader"), read},
                {QStringLiteral("content_contributor"), read + QStringList{QStringLiteral("document.create"), QStringLiteral("upload.create"),
                        QStringLiteral("folder.create"), QStringLiteral("folder.rename"), QStringLiteral("folder.move"),
                        QStringLiteral("folder.delete"), QStringLiteral("document.metadata_update"), QStringLiteral("document.move"),
                        QStringLiteral("document.trash")}},
                {QStringLiteral("content_purger"), read + QStringList{QStringLiteral("document.purge")}},
                {QStringLiteral("content_sharer"), read + QStringList{QStringLiteral("share.create")}},
                {QStringLiteral("access_manager"), base + QStringList{QStringLiteral("resource_grant.read"), QStringLiteral("resource_grant.create"),
                        QStringLiteral("resource_grant.revoke"), QStringLiteral("access.configure")}},
                {QStringLiteral("space_maintainer"), base + QStringList{QStringLiteral("space.update_metadata"), QStringLiteral("space.archive"),
                        QStringLiteral("space.reactivate")}},
                {QStringLiteral("add_on_manager"), base + QStringList{QStringLiteral("add_on.space_activate")}},
                {QStringLiteral("automation_manager"), base + QStringList{QStringLiteral("space_rule.create")}}};
    }

    static QStringList actionsOf(const QStringList &roles)
    {
        QStringList actions;
        for (const auto &[key, held] : atomicRoles())
            if (roles.contains(key))
                for (const QString &action : held)
                    if (!actions.contains(action)) actions.append(action);
        return actions;
    }

    // The organization's roles, the built-in ones seeded on first use.
    QJsonArray &accessRoles(const QString &orgId)
    {
        QJsonArray &roles = m_roles[orgId];
        if (!roles.isEmpty())
            return roles;
        const QStringList contentManager{QStringLiteral("content_contributor"), QStringLiteral("content_purger"),
                                         QStringLiteral("content_sharer")};
        const QStringList spaceOperator{QStringLiteral("access_manager"), QStringLiteral("space_maintainer"),
                                        QStringLiteral("add_on_manager"), QStringLiteral("automation_manager")};
        QList<std::pair<QString, QStringList>> builtIn{
                {QStringLiteral("owner"), {QStringLiteral("membership.list"), QStringLiteral("role.read"), QStringLiteral("billing.manage")}},
                {QStringLiteral("admin"), {QStringLiteral("membership.list"), QStringLiteral("role.read")}},
                {QStringLiteral("member"), {QStringLiteral("membership.list")}},
                {QStringLiteral("billing"), {QStringLiteral("billing.manage")}},
                {QStringLiteral("guest"), {QStringLiteral("organization.list")}}};
        for (const auto &[key, held] : atomicRoles())
            builtIn.append({key, held});
        builtIn.append({QStringLiteral("content_manager"), actionsOf(contentManager)});
        builtIn.append({QStringLiteral("space_operator"), actionsOf(spaceOperator)});
        builtIn.append({QStringLiteral("space_admin"), actionsOf(contentManager + spaceOperator)});
        for (const auto &[key, actions] : builtIn) {
            QString name = key;
            name.replace(QLatin1Char('_'), QLatin1Char(' '));
            name[0] = name.at(0).toUpper();
            roles.append(QJsonObject{{QStringLiteral("id"), QStringLiteral("role-") + key}, {QStringLiteral("key"), key},
                    {QStringLiteral("name"), name}, {QStringLiteral("origin"), QStringLiteral("system")},
                    {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("built_in"), true},
                    {QStringLiteral("actions"), QJsonArray::fromStringList(actions)}});
        }
        return roles;
    }

    // Renaming a space (`PATCH …/spaces/:id`) and archiving it (`POST
    // …/spaces/:id/archive`), as Core does for an active space.
    std::optional<QByteArray> spaceLifecycle(const QByteArray &method, const QStringList &parts, const QJsonObject &json)
    {
        const bool rename = parts.size() == 7 && method == "PATCH";
        const bool archive = parts.size() == 8 && method == "POST" && parts.at(7) == QLatin1String("archive");
        if ((!rename && !archive) || parts.at(3) != QLatin1String("organizations") || parts.at(5) != QLatin1String("spaces"))
            return std::nullopt;
        const QString orgId = parts.at(4), spaceId = parts.at(6);
        const QJsonObject space = byId(m_spaces.value(orgId), spaceId);
        if (space.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (space.value(QStringLiteral("status")) != QLatin1String("active"))
            return errorReply(422, QStringLiteral("archived_read_only"));
        const QString name = json.value(QStringLiteral("name")).toString().trimmed();
        if (rename && name.isEmpty())
            return errorReply(422, QStringLiteral("invalid_request"));
        update(m_spaces[orgId], spaceId, [&](QJsonObject &changed) {
            changed.insert(rename ? QStringLiteral("name") : QStringLiteral("status"), rename ? name : QStringLiteral("archived"));
            changed.insert(QStringLiteral("revision"), changed.value(QStringLiteral("revision")).toInt() + 1);
        });
        return single(QStringLiteral("space"), m_spaces.value(orgId), spaceId);
    }

    // The space-scoped add-ons of `orgId` with their state in space
    // `spaceId`, and turning one on or off there, as Core keeps them: for
    // owners and admins, and whoever holds `add_on.space_activate` on the space.
    std::optional<QByteArray> spaceAddOns(const QByteArray &method, const QStringList &parts, const QJsonObject &json)
    {
        if (parts.size() < 8 || parts.size() > 9 || parts.at(5) != QLatin1String("spaces") || parts.at(7) != QLatin1String("add-ons"))
            return std::nullopt;
        const QString orgId = parts.at(4), spaceId = parts.at(6);
        if (byId(m_spaces.value(orgId), spaceId).isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")}) && !holds(orgId, spaceId, QStringLiteral("add_on.space_activate")))
            return errorReply(403, QStringLiteral("forbidden"));
        if (parts.size() == 8) {
            if (method != "GET")
                return std::nullopt;
            QJsonArray rows;
            for (const QJsonValue &value : m_addOns.value(orgId)) {
                const QString key = value.toObject().value(QStringLiteral("key")).toString();
                const QJsonObject installation = value.toObject().value(QStringLiteral("installation")).toObject();
                const QString status = installation.value(QStringLiteral("status")).toString();
                if (status.isEmpty() || status == QLatin1String("uninstalled") || !spaceScoped(key)) continue;
                rows.append(activationRow(key, installation, m_activations.value(spaceId + QLatin1Char('|') + key)));
            }
            return jsonReply(200, {{QStringLiteral("add_ons"), rows}});
        }
        const QString key = parts.at(8);
        QJsonObject installation;
        for (const QJsonValue &value : m_addOns.value(orgId))
            if (value.toObject().value(QStringLiteral("key")).toString() == key)
                installation = value.toObject().value(QStringLiteral("installation")).toObject();
        const QString slot = spaceId + QLatin1Char('|') + key;
        QJsonObject activation = m_activations.value(slot);
        if (method == "DELETE" && activation.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (!activation.isEmpty()) {
            if (m_lastMatch.isEmpty() && !json.contains(QStringLiteral("revision")))
                return errorReply(428, QStringLiteral("revision_required"));
            const QString revision = m_lastMatch.isEmpty() ? QString::number(json.value(QStringLiteral("revision")).toInt()) : m_lastMatch;
            if (revision != QString::number(activation.value(QStringLiteral("revision")).toInt()))
                return errorReply(409, QStringLiteral("revision_conflict"));
        }
        if (method == "PUT") {
            if (installation.value(QStringLiteral("status")) != QLatin1String("active"))
                return errorReply(409, QStringLiteral("add_on_unavailable"));
            QJsonObject settings = activation.value(QStringLiteral("settings")).toObject();
            const QJsonObject changes = json.value(QStringLiteral("settings")).toObject();
            for (auto it = changes.begin(); it != changes.end(); ++it) {
                if (it.value().isNull()) settings.remove(it.key());
                else settings.insert(it.key(), it.value());
            }
            activation.insert(QStringLiteral("settings"), settings);
            activation.insert(QStringLiteral("status"), QStringLiteral("active"));
        } else if (method == "DELETE") {
            activation.insert(QStringLiteral("status"), QStringLiteral("inactive"));
        } else {
            return std::nullopt;
        }
        activation.insert(QStringLiteral("revision"), activation.value(QStringLiteral("revision")).toInt() + 1);
        m_activations.insert(slot, activation);
        return jsonReply(200, {{QStringLiteral("add_on"), activationRow(key, installation, activation)}});
    }

    // Whether add-on `key` works per space, as Core's products that declare a
    // space action or a trusted webhook do.
    static bool spaceScoped(const QString &key)
    {
        return key == QLatin1String("controlled_docs") || key == QLatin1String("classifier");
    }

    // An add-on's state in a space, as `GET …/add-ons` lists it.
    static QJsonObject activationRow(const QString &key, const QJsonObject &installation, const QJsonObject &activation)
    {
        QJsonObject effective = installation.value(QStringLiteral("settings")).toObject();
        const QJsonObject overrides = activation.value(QStringLiteral("settings")).toObject();
        for (auto it = overrides.begin(); it != overrides.end(); ++it) effective.insert(it.key(), it.value());
        const QString status = activation.value(QStringLiteral("status")).toString(QStringLiteral("inactive"));
        return {{QStringLiteral("product_key"), key},
                {QStringLiteral("installation_id"), installation.value(QStringLiteral("id"))},
                {QStringLiteral("installation_status"), installation.value(QStringLiteral("status"))},
                {QStringLiteral("status"), status},
                {QStringLiteral("active"), status == QLatin1String("active")
                                           && installation.value(QStringLiteral("status")) == QLatin1String("active")},
                {QStringLiteral("settings"), overrides},
                {QStringLiteral("effective_settings"), effective},
                {QStringLiteral("revision"), activation.isEmpty() ? QJsonValue(QJsonValue::Null) : activation.value(QStringLiteral("revision"))}};
    }

    // Whether the add-on `key` of `orgId` is installed, active, and turned on in `spaceId`.
    bool addOnActive(const QString &orgId, const QString &spaceId, const QString &key) const
    {
        for (const QJsonValue &product : m_addOns.value(orgId))
            if (product.toObject().value(QStringLiteral("key")) == key)
                return product.toObject().value(QStringLiteral("installation")).toObject().value(QStringLiteral("status")) == QLatin1String("active")
                       && m_activations.value(spaceId + QLatin1Char('|') + key).value(QStringLiteral("status")) == QLatin1String("active");
        return false;
    }

    // Puts a document under control, as Core checks it: the document, the
    // add-on's document_manage action on its space, its revision, the add-on
    // active in the space, then a published Markdown version.
    QByteArray enableControl(const QString &orgId, const QString &spaceId, const QString &documentId)
    {
        const QJsonObject doc = byId(m_documents.value(spaceId), documentId);
        if (doc.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (!holds(orgId, spaceId, QStringLiteral("addon.controlled_docs.document_manage")))
            return errorReply(403, QStringLiteral("forbidden"));
        if (const std::optional<QByteArray> refused = refuseRevision(doc))
            return *refused;
        if (!addOnActive(orgId, spaceId, QStringLiteral("controlled_docs")))
            return errorReply(409, QStringLiteral("controlled_docs_unavailable"));
        const QJsonObject version = doc.value(QStringLiteral("current_version")).toObject();
        if (version.isEmpty())
            return errorReply(422, QStringLiteral("published_version_required"));
        if (version.value(QStringLiteral("content_type")) != QLatin1String("text/markdown")
            || !version.value(QStringLiteral("filename")).toString().endsWith(QLatin1String(".md"), Qt::CaseInsensitive))
            return errorReply(422, QStringLiteral("unsupported_media_type"));
        update(m_documents[spaceId], documentId, [](QJsonObject &controlled) {
            controlled.insert(QStringLiteral("controlled_docs_enabled"), true);
            controlled.insert(QStringLiteral("revision"), controlled.value(QStringLiteral("revision")).toInt() + 1);
        });
        const QJsonObject enabled = byId(m_documents.value(spaceId), documentId);
        return jsonReply(200, {{QStringLiteral("data"), QJsonObject{{QStringLiteral("document_id"), enabled.value(QStringLiteral("id"))},
                                                                    {QStringLiteral("enabled"), true},
                                                                    {QStringLiteral("revision"), enabled.value(QStringLiteral("revision"))}}},
                               {QStringLiteral("request_id"), requestId()}});
    }

    QString slugOf(const QString &orgId) const
    {
        for (const auto &orgs : m_orgsByUser)
            if (const QJsonObject org = byId(orgs, orgId); !org.isEmpty()) return org.value(QStringLiteral("slug")).toString();
        return {};
    }

    // A managed account of `orgId` signing in as `org-slug/username`, with its
    // active membership holding the built-in `roles`: the member row.
    QJsonObject addManagedMember(const QString &orgId, const QString &username, const QString &name, const QJsonArray &roles)
    {
        const QString slug = slugOf(orgId);
        const QString identifier = slug + QLatin1Char('/') + username;
        m_orgsByUser[identifier].append(QJsonObject{{QStringLiteral("id"), orgId}, {QStringLiteral("name"), orgName(orgId)},
                {QStringLiteral("slug"), slug}, {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}});
        const QJsonObject member{{QStringLiteral("id"), QString::number(++m_nextPerson)},
                {QStringLiteral("user_id"), userIdOf(identifier)}, {QStringLiteral("email"), QJsonValue::Null},
                {QStringLiteral("username"), username}, {QStringLiteral("name"), name.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(name)},
                {QStringLiteral("managed"), true}, {QStringLiteral("roles"), roles},
                {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}};
        m_members[orgId].append(member);
        return member;
    }

    // A new one-time setup code for the managed account `identifier`, revoking
    // its previous one: `{setup_code, setup_code_expires_at}`.
    QJsonObject issueSetupCode(const QString &identifier)
    {
        const QString code = QStringLiteral("mst_%1").arg(++m_nextAccess);
        m_setupCodes.insert(identifier, code);
        return {{QStringLiteral("setup_code"), code},
                {QStringLiteral("setup_code_expires_at"), QDateTime::currentDateTimeUtc().addSecs(72 * 3600).toString(Qt::ISODate)}};
    }

    // The built-in roles an invitation or a created member may hold:
    // distinct, owner excluded, `member` when omitted; empty when refused.
    static QJsonArray invitedRoles(const QJsonObject &json)
    {
        const QJsonArray roles = json.contains(QStringLiteral("roles")) ? json.value(QStringLiteral("roles")).toArray()
                                                                        : QJsonArray{QStringLiteral("member")};
        QStringList keys;
        for (const QJsonValue &role : roles) keys.append(role.toString());
        static const QStringList invitable{QStringLiteral("admin"), QStringLiteral("member"), QStringLiteral("billing"),
                                           QStringLiteral("guest")};
        if (keys.isEmpty() || QStringList(keys).removeDuplicates() > 0
            || std::any_of(keys.begin(), keys.end(), [](const QString &key) { return !invitable.contains(key); }))
            return {};
        return roles;
    }

    // The signed-in user's membership in `orgId`.
    QString membershipIn(const QString &orgId) const
    {
        return myMembership(orgId).value(QStringLiteral("id")).toString();
    }

    // The groups of `orgId` whose members include `membershipId`.
    QStringList groupsOf(const QString &orgId, const QString &membershipId) const
    {
        QStringList ids;
        for (const QJsonValue &group : m_groups.value(orgId)) {
            const QString id = group.toObject().value(QStringLiteral("id")).toString();
            for (const QJsonValue &member : m_groupMembers.value(id))
                if (member.toObject().value(QStringLiteral("organization_membership_id")).toString() == membershipId)
                    ids.append(id);
        }
        return ids;
    }

    // Whether the signed-in user's grants on space `spaceId`, given to them
    // or their groups, carry `action`.
    bool holds(const QString &orgId, const QString &spaceId, const QString &action)
    {
        const QString membership = membershipIn(orgId);
        const QStringList groups = groupsOf(orgId, membership);
        for (const QJsonValue &value : std::as_const(m_grants)) {
            const QJsonObject grant = value.toObject();
            if (!sameResource(grant, grantResource(QStringLiteral("space"), spaceId, {}))
                || (grant.value(QStringLiteral("organization_membership_id")).toString() != membership
                    && !groups.contains(grant.value(QStringLiteral("group_id")).toString())))
                continue;
            if (byId(accessRoles(orgId), grant.value(QStringLiteral("role_id")).toString())
                        .value(QStringLiteral("actions")).toArray().contains(action))
                return true;
        }
        return false;
    }

    // The resource of a grant, as Core stores it: `resource_kind` "space",
    // "folder", "item" (a document), or "tag", and the ids naming it. A
    // document's id is a number, as Core's.
    static QJsonObject grantResource(const QString &kind, const QString &spaceId, const QString &id)
    {
        const QJsonValue none(QJsonValue::Null);
        return {{QStringLiteral("resource_kind"), kind},
                {QStringLiteral("space_id"), kind == QLatin1String("tag") ? none : QJsonValue(spaceId)},
                {QStringLiteral("folder_id"), kind == QLatin1String("folder") ? QJsonValue(id) : none},
                {QStringLiteral("item_id"), kind == QLatin1String("item") ? QJsonValue(id.toLongLong()) : none},
                {QStringLiteral("tag_id"), kind == QLatin1String("tag") ? QJsonValue(id) : none}};
    }

    static bool sameResource(const QJsonObject &grant, const QJsonObject &resource)
    {
        for (auto it = resource.begin(); it != resource.end(); ++it)
            if (grant.value(it.key()) != it.value()) return false;
        return true;
    }

    // "user:…", "group:…", or "role:…": who `grant` names.
    static QString principalOf(const QJsonObject &grant)
    {
        const QString kind = grant.value(QStringLiteral("principal_kind")).toString();
        const QString field = kind == QLatin1String("group") ? QStringLiteral("group_id")
                            : kind == QLatin1String("role") ? QStringLiteral("role_principal_id")
                                                            : QStringLiteral("organization_membership_id");
        return kind + QLatin1Char(':') + jsonId(grant.value(field));
    }

    // Space, folder, and document grants of an archived role are not
    // listed; tag grants do not depend on the role's status.
    bool listedGrant(const QString &orgId, const QJsonObject &grant)
    {
        return grant.value(QStringLiteral("resource_kind")) == QLatin1String("tag")
               || !byId(accessRoles(orgId), grant.value(QStringLiteral("role_id")).toString()).isEmpty();
    }

    QJsonArray grantsOn(const QString &orgId, const QJsonObject &resource)
    {
        QJsonArray rows;
        for (const QJsonValue &value : std::as_const(m_grants))
            if (sameResource(value.toObject(), resource) && listedGrant(orgId, value.toObject())) rows.append(value);
        return rows;
    }

    // Whether the space, folder, document, or tag `resource` exists in `orgId`.
    bool resourceExists(const QString &orgId, const QJsonObject &resource) const
    {
        const QString kind = resource.value(QStringLiteral("resource_kind")).toString();
        const QString spaceId = resource.value(QStringLiteral("space_id")).toString();
        if (kind == QLatin1String("tag"))
            return !byId(m_tags.value(orgId), resource.value(QStringLiteral("tag_id")).toString()).isEmpty();
        if (byId(m_spaces.value(orgId), spaceId).isEmpty())
            return false;
        if (kind == QLatin1String("folder"))
            return !byId(m_folders.value(spaceId), resource.value(QStringLiteral("folder_id")).toString()).isEmpty();
        if (kind == QLatin1String("item"))
            return !byId(m_documents.value(spaceId), jsonId(resource.value(QStringLiteral("item_id")))).isEmpty();
        return true;
    }

    // `PUT …/grants`: leaves exactly `role_ids` granted to the one principal
    // named, its grants of archived roles untouched, and answers its grants
    // there in the listing's shape and order.
    QByteArray replaceGrants(const QString &orgId, const QJsonObject &resource, const QJsonObject &json)
    {
        QStringList named;
        for (const auto &[field, kind] : {std::pair{QStringLiteral("organization_membership_id"), QStringLiteral("user")},
                                          std::pair{QStringLiteral("group_id"), QStringLiteral("group")},
                                          std::pair{QStringLiteral("role_principal_id"), QStringLiteral("role")}})
            if (!json.value(field).isNull() && !json.value(field).isUndefined()) named.append(kind + QLatin1Char(':') + jsonId(json.value(field)));
        if (named.size() != 1)
            return errorReply(422, QStringLiteral("invalid_principal"));
        if (!resourceExists(orgId, resource))
            return errorReply(404, QStringLiteral("not_found"));
        const QJsonArray &roles = accessRoles(orgId);
        if (!json.value(QStringLiteral("role_ids")).isArray())
            return errorReply(422, QStringLiteral("invalid_request"));
        QStringList wanted;
        for (const QJsonValue &value : json.value(QStringLiteral("role_ids")).toArray()) {
            if (byId(roles, jsonId(value)).isEmpty())
                return errorReply(404, QStringLiteral("not_found"));
            wanted.append(jsonId(value));
        }
        if (QStringList(wanted).removeDuplicates() > 0)
            return errorReply(422, QStringLiteral("invalid_request"));
        const QString principal = named.constFirst();
        const QString kind = principal.section(QLatin1Char(':'), 0, 0), id = principal.section(QLatin1Char(':'), 1);
        if (kind == QLatin1String("role") && resource.value(QStringLiteral("resource_kind")) != QLatin1String("tag"))
            return errorReply(422, QStringLiteral("invalid_principal"));
        const QJsonArray &holders = kind == QLatin1String("user") ? m_members[orgId] : kind == QLatin1String("group") ? m_groups[orgId] : roles;
        if (byId(holders, id).isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        QStringList held;
        for (qsizetype at = 0; at < m_grants.size(); ++at) {
            const QJsonObject grant = m_grants.at(at).toObject();
            const QString role = grant.value(QStringLiteral("role_id")).toString();
            if (!sameResource(grant, resource) || principalOf(grant) != principal || byId(roles, role).isEmpty())
                continue;
            if (wanted.contains(role) && !held.contains(role)) held.append(role);
            else m_grants.removeAt(at--);
        }
        const QString field = kind == QLatin1String("group") ? QStringLiteral("group_id")
                            : kind == QLatin1String("role") ? QStringLiteral("role_principal_id")
                                                            : QStringLiteral("organization_membership_id");
        for (const QString &role : std::as_const(wanted)) {
            if (held.contains(role))
                continue;
            QJsonObject grant = resource;
            grant.insert(QStringLiteral("id"), QStringLiteral("access-%1").arg(++m_nextAccess));
            grant.insert(QStringLiteral("role_id"), role);
            grant.insert(QStringLiteral("role_key"), byId(roles, role).value(QStringLiteral("key")));
            grant.insert(QStringLiteral("principal_kind"), kind);
            for (const QString &other : {QStringLiteral("organization_membership_id"), QStringLiteral("group_id"),
                                         QStringLiteral("role_principal_id")})
                grant.insert(other, other == field ? QJsonValue(id) : QJsonValue(QJsonValue::Null));
            grant.insert(QStringLiteral("status"), QStringLiteral("active"));
            m_grants.append(grant);
        }
        QJsonArray mine;
        for (const QJsonValue &value : grantsOn(orgId, resource))
            if (principalOf(value.toObject()) == principal) mine.append(value);
        return jsonReply(200, {{QStringLiteral("grants"), mine}, {QStringLiteral("request_id"), requestId()}});
    }

    // `GET …/access` on a space, folder, or document: the grants on its
    // space, the folders above it outermost first, and itself, each with its
    // `source`, whether it is `inherited`, and its `scope`, paged in that
    // order. Below the deepest folder or document that stops inheriting, a
    // grant above it is listed only when its role manages access. Each page
    // carries the `summary`.
    QByteArray accessOf(const QString &orgId, const QJsonObject &resource)
    {
        if (!resourceExists(orgId, resource))
            return errorReply(404, QStringLiteral("not_found"));
        const QString kind = resource.value(QStringLiteral("resource_kind")).toString();
        const QString spaceId = resource.value(QStringLiteral("space_id")).toString();
        QString folderId = kind == QLatin1String("folder") ? resource.value(QStringLiteral("folder_id")).toString()
                         : kind == QLatin1String("item")
                         ? byId(m_documents.value(spaceId), jsonId(resource.value(QStringLiteral("item_id")))).value(QStringLiteral("folder_id")).toString()
                         : QString();
        QList<QJsonObject> sources;
        for (; !folderId.isEmpty();
             folderId = byId(m_folders.value(spaceId), folderId).value(QStringLiteral("parent_id")).toString())
            sources.prepend(grantResource(QStringLiteral("folder"), spaceId, folderId));
        sources.prepend(grantResource(QStringLiteral("space"), spaceId, {}));
        if (kind == QLatin1String("item"))
            sources.append(resource);
        const auto named = [](const QJsonObject &source) {
            const QString sourceKind = source.value(QStringLiteral("resource_kind")).toString();
            return QJsonObject{{QStringLiteral("kind"), sourceKind == QLatin1String("item") ? QStringLiteral("document") : sourceKind},
                               {QStringLiteral("id"), sourceKind == QLatin1String("space") ? source.value(QStringLiteral("space_id"))
                                                    : sourceKind == QLatin1String("folder") ? source.value(QStringLiteral("folder_id"))
                                                                                            : source.value(QStringLiteral("item_id"))}};
        };
        int breakAt = -1;
        for (int at = 0; at < sources.size(); ++at)
            if (!inheritanceOf(spaceId, sources.at(at)).isEmpty()) breakAt = at;
        static const QStringList managing{QStringLiteral("resource_grant.read"), QStringLiteral("resource_grant.create"),
                                          QStringLiteral("resource_grant.revoke"), QStringLiteral("access.configure")};
        QJsonArray rows;
        for (int at = 0; at < sources.size(); ++at) {
            const QJsonObject &source = sources.at(at);
            for (const QJsonValue &value : grantsOn(orgId, source)) {
                QJsonObject row = value.toObject();
                QString scope = QStringLiteral("full");
                if (breakAt >= 0 && at < breakAt) {
                    const QJsonArray actions = byId(accessRoles(orgId), row.value(QStringLiteral("role_id")).toString())
                                                   .value(QStringLiteral("actions")).toArray();
                    if (std::none_of(actions.begin(), actions.end(), [](const QJsonValue &action) { return managing.contains(action.toString()); }))
                        continue;
                    scope = QStringLiteral("manage");
                }
                row.insert(QStringLiteral("source"), named(source));
                row.insert(QStringLiteral("inherited"), source != sources.constLast());
                row.insert(QStringLiteral("scope"), scope);
                rows.append(row);
            }
        }
        QJsonValue open(QJsonValue::Null);
        for (int at = std::max(breakAt, 0); at < sources.size(); ++at) {
            const QJsonObject &source = sources.at(at);
            const bool isSpace = source.value(QStringLiteral("resource_kind")) == QLatin1String("space");
            if ((isSpace && byId(m_spaces.value(orgId), spaceId).value(QStringLiteral("visibility")) == QLatin1String("public"))
                || inheritanceOf(spaceId, source) == QLatin1String("open"))
                open = named(source);
        }
        const QString own = kind == QLatin1String("space") ? QString() : inheritanceOf(spaceId, sources.constLast());
        const QJsonObject summary{{QStringLiteral("visibility"), byId(m_spaces.value(orgId), spaceId).value(QStringLiteral("visibility")).toString(QStringLiteral("private"))},
                     {QStringLiteral("inheritance"), own.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(own)},
                     {QStringLiteral("break"), breakAt < 0 ? QJsonValue(QJsonValue::Null) : QJsonValue(named(sources.at(breakAt)))},
                     {QStringLiteral("open_to_members"), !open.isNull()},
                     {QStringLiteral("open_source"), open}};
        return listed(QStringLiteral("access"), rows, true, {{QStringLiteral("summary"), summary}});
    }

    // The `inheritance` a folder or document `source` keeps in `spaceId`,
    // empty while it inherits; a space always inherits.
    QString inheritanceOf(const QString &spaceId, const QJsonObject &source) const
    {
        const QString kind = source.value(QStringLiteral("resource_kind")).toString();
        if (kind == QLatin1String("folder"))
            return byId(m_folders.value(spaceId), source.value(QStringLiteral("folder_id")).toString()).value(QStringLiteral("inheritance")).toString();
        if (kind == QLatin1String("item"))
            return byId(m_documents.value(spaceId), jsonId(source.value(QStringLiteral("item_id")))).value(QStringLiteral("inheritance")).toString();
        return {};
    }

    // `PUT …/folders/:id/access` or `…/documents/:id/access`: keeps
    // `inheritance` ("inherit" clears it) and answers the folder or document.
    QByteArray setInheritance(const QString &orgId, const QJsonObject &resource, const QJsonObject &json)
    {
        if (!resourceExists(orgId, resource))
            return errorReply(404, QStringLiteral("not_found"));
        const QString value = json.value(QStringLiteral("inheritance")).toString();
        if (value != QLatin1String("inherit") && value != QLatin1String("open") && value != QLatin1String("restricted"))
            return errorReply(422, QStringLiteral("invalid_inheritance"));
        const QString spaceId = resource.value(QStringLiteral("space_id")).toString();
        const bool folder = resource.value(QStringLiteral("resource_kind")) == QLatin1String("folder");
        QJsonArray &list = folder ? m_folders[spaceId] : m_documents[spaceId];
        const QString id = folder ? resource.value(QStringLiteral("folder_id")).toString() : jsonId(resource.value(QStringLiteral("item_id")));
        update(list, id, [&](QJsonObject &row) {
            row.insert(QStringLiteral("inheritance"), value == QLatin1String("inherit") ? QJsonValue(QJsonValue::Null) : QJsonValue(value));
        });
        return jsonReply(200, {{folder ? QStringLiteral("folder") : QStringLiteral("document"), byId(list, id)}});
    }

    // `GET members/:id/access` and `GET groups/:id/access`: the grants that
    // reach the member (theirs, their groups', and the tag grants of the
    // roles they hold) or the group, each with its `resource` and `via`.
    QByteArray reaching(const QString &orgId, const QString &kind, const QString &id)
    {
        const bool user = kind == QLatin1String("user");
        if (byId(user ? m_members.value(orgId) : m_groups.value(orgId), id).isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        const QStringList groups = user ? groupsOf(orgId, id) : QStringList{id};
        QStringList roles;
        if (user) {
            for (const QJsonValue &key : byId(m_members.value(orgId), id).value(QStringLiteral("roles")).toArray())
                roles.append(QStringLiteral("role-") + key.toString());
            for (const QJsonValue &value : m_principalRoles.value(orgId)) {
                const QJsonObject row = value.toObject();
                if (row.value(QStringLiteral("organization_membership_id")).toString() == id
                    || groups.contains(row.value(QStringLiteral("group_id")).toString()))
                    roles.append(row.value(QStringLiteral("role_id")).toString());
            }
        }
        QJsonArray rows;
        for (const QJsonValue &value : std::as_const(m_grants)) {
            QJsonObject row = value.toObject();
            const QString principal = principalOf(row);
            const QString principalKind = principal.section(QLatin1Char(':'), 0, 0), principalId = principal.section(QLatin1Char(':'), 1);
            const QString resourceKind = row.value(QStringLiteral("resource_kind")).toString();
            const bool reaches = (user && principal == QStringLiteral("user:") + id)
                                 || (principalKind == QLatin1String("group") && groups.contains(principalId))
                                 || (principalKind == QLatin1String("role") && resourceKind == QLatin1String("tag") && roles.contains(principalId));
            if (!reaches || !listedGrant(orgId, row))
                continue;
            const QString resourceId = resourceKind == QLatin1String("space") ? row.value(QStringLiteral("space_id")).toString()
                                     : resourceKind == QLatin1String("folder") ? row.value(QStringLiteral("folder_id")).toString()
                                     : resourceKind == QLatin1String("tag") ? row.value(QStringLiteral("tag_id")).toString()
                                                                             : jsonId(row.value(QStringLiteral("item_id")));
            row.insert(QStringLiteral("resource"), QJsonObject{
                    {QStringLiteral("kind"), resourceKind == QLatin1String("item") ? QStringLiteral("document") : resourceKind},
                    {QStringLiteral("id"), resourceKind == QLatin1String("item") ? row.value(QStringLiteral("item_id")) : QJsonValue(resourceId)},
                    {QStringLiteral("space_id"), row.value(QStringLiteral("space_id"))}});
            row.insert(QStringLiteral("via"), QJsonObject{{QStringLiteral("kind"), principalKind}, {QStringLiteral("id"), principalId}});
            rows.append(row);
        }
        // Members other than guests read the public spaces without a grant.
        QJsonArray open;
        static const QStringList reading{QStringLiteral("owner"), QStringLiteral("admin"), QStringLiteral("member"),
                                         QStringLiteral("billing")};
        const QJsonArray held = user ? byId(m_members.value(orgId), id).value(QStringLiteral("roles")).toArray() : QJsonArray();
        if (std::any_of(held.begin(), held.end(), [](const QJsonValue &key) { return reading.contains(key.toString()); }))
            for (const QJsonValue &value : m_spaces.value(orgId)) {
                const QJsonObject space = value.toObject();
                if (space.value(QStringLiteral("visibility")) == QLatin1String("public"))
                    open.append(QJsonObject{{QStringLiteral("kind"), QStringLiteral("space")}, {QStringLiteral("id"), space.value(QStringLiteral("id"))},
                                            {QStringLiteral("space_id"), space.value(QStringLiteral("id"))}});
            }
        return listed(QStringLiteral("access"), rows, false, {{QStringLiteral("open"), open}});
    }

    // `POST …/grants`: grants `role_id` to the one principal named, once.
    QByteArray createGrant(const QString &orgId, const QJsonObject &resource, QJsonObject json)
    {
        QStringList held;
        for (const QJsonValue &value : grantsOn(orgId, resource)) {
            const QJsonObject grant = value.toObject();
            for (const QString &field : {QStringLiteral("organization_membership_id"), QStringLiteral("group_id"),
                                         QStringLiteral("role_principal_id")})
                if (!json.value(field).isUndefined() && grant.value(field) == json.value(field))
                    held.append(grant.value(QStringLiteral("role_id")).toString());
        }
        const QString role = json.take(QStringLiteral("role_id")).toString();
        if (held.contains(role))
            return errorReply(409, QStringLiteral("already_exists"));
        json.insert(QStringLiteral("role_ids"), QJsonArray::fromStringList(held + QStringList{role}));
        return replaceGrants(orgId, resource, json);
    }

    // `DELETE …/grants/:id`: revokes the grant `grantId` on `resource`.
    QByteArray revokeGrant(const QJsonObject &resource, const QString &grantId)
    {
        for (qsizetype at = 0; at < m_grants.size(); ++at) {
            const QJsonObject grant = m_grants.at(at).toObject();
            if (grant.value(QStringLiteral("id")).toString() == grantId && sameResource(grant, resource)) {
                m_grants.removeAt(at);
                return http(204, {});
            }
        }
        return errorReply(404, QStringLiteral("not_found"));
    }

    // `GET roles/:id/holders`: the role's assignments to members, built-in
    // ones included, and groups, then its listed grants, each with its
    // `kind`, `principal`, and a grant's `resource`.
    QByteArray roleHolders(const QString &orgId, const QString &roleId)
    {
        const QJsonObject role = byId(accessRoles(orgId), roleId);
        if (role.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        QJsonArray rows;
        const auto assignment = [&](QJsonObject row) {
            const bool group = row.value(QStringLiteral("principal_kind")) == QLatin1String("group");
            row.insert(QStringLiteral("kind"), QStringLiteral("assignment"));
            row.insert(QStringLiteral("principal"), QJsonObject{{QStringLiteral("kind"), group ? QStringLiteral("group") : QStringLiteral("user")},
                    {QStringLiteral("id"), row.value(group ? QStringLiteral("group_id") : QStringLiteral("organization_membership_id"))}});
            rows.append(row);
        };
        for (const QJsonValue &value : m_members.value(orgId)) {
            const QJsonObject member = value.toObject();
            const QString id = member.value(QStringLiteral("id")).toString();
            for (const QJsonValue &key : member.value(QStringLiteral("roles")).toArray())
                if (QStringLiteral("role-") + key.toString() == roleId)
                    assignment({{QStringLiteral("id"), QStringLiteral("system-%1-%2").arg(id, key.toString())}, {QStringLiteral("role_id"), roleId},
                                {QStringLiteral("principal_kind"), QStringLiteral("user")}, {QStringLiteral("organization_membership_id"), id},
                                {QStringLiteral("group_id"), QJsonValue::Null}});
        }
        for (const QJsonValue &value : m_principalRoles.value(orgId))
            if (value.toObject().value(QStringLiteral("role_id")).toString() == roleId) assignment(value.toObject());
        for (const QJsonValue &value : std::as_const(m_grants)) {
            QJsonObject row = value.toObject();
            if (row.value(QStringLiteral("role_id")).toString() != roleId || !listedGrant(orgId, row))
                continue;
            const QString principal = principalOf(row);
            const QString resourceKind = row.value(QStringLiteral("resource_kind")).toString();
            row.insert(QStringLiteral("kind"), QStringLiteral("grant"));
            row.insert(QStringLiteral("principal"), QJsonObject{{QStringLiteral("kind"), principal.section(QLatin1Char(':'), 0, 0)},
                                                                {QStringLiteral("id"), principal.section(QLatin1Char(':'), 1)}});
            row.insert(QStringLiteral("resource"), QJsonObject{
                    {QStringLiteral("kind"), resourceKind == QLatin1String("item") ? QStringLiteral("document") : resourceKind},
                    {QStringLiteral("id"), resourceKind == QLatin1String("space") ? row.value(QStringLiteral("space_id"))
                                         : resourceKind == QLatin1String("folder") ? row.value(QStringLiteral("folder_id"))
                                         : resourceKind == QLatin1String("tag") ? row.value(QStringLiteral("tag_id"))
                                                                                 : row.value(QStringLiteral("item_id"))},
                    {QStringLiteral("space_id"), row.value(QStringLiteral("space_id"))}});
            rows.append(row);
        }
        return listed(QStringLiteral("holders"), rows, true);
    }

    // `GET principal-roles` for one member or group: its assignments of
    // active roles, a member's built-in organization roles among them, each
    // with its `role`.
    QByteArray principalRoles(const QString &orgId)
    {
        const QUrlQuery params = query();
        const QString member = params.queryItemValue(QStringLiteral("organization_membership_id"));
        const QString group = params.queryItemValue(QStringLiteral("group_id"));
        if (member.isEmpty() == group.isEmpty())
            return errorReply(422, QStringLiteral("invalid_principal"));
        const QJsonObject membership = byId(m_members.value(orgId), member);
        if (byId(member.isEmpty() ? m_groups.value(orgId) : m_members.value(orgId), member.isEmpty() ? group : member).isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        QJsonArray assigned;
        for (const QJsonValue &key : membership.value(QStringLiteral("roles")).toArray())
            assigned.append(QJsonObject{{QStringLiteral("id"), QStringLiteral("system-%1-%2").arg(member, key.toString())},
                    {QStringLiteral("role_id"), QStringLiteral("role-") + key.toString()},
                    {QStringLiteral("principal_kind"), QStringLiteral("user")},
                    {QStringLiteral("organization_membership_id"), member}, {QStringLiteral("group_id"), QJsonValue::Null}});
        for (const QJsonValue &value : m_principalRoles.value(orgId)) {
            const QJsonObject row = value.toObject();
            if (member.isEmpty() ? row.value(QStringLiteral("group_id")).toString() == group
                                 : row.value(QStringLiteral("organization_membership_id")).toString() == member)
                assigned.append(row);
        }
        QJsonArray rows;
        for (const QJsonValue &value : std::as_const(assigned)) {
            QJsonObject row = value.toObject();
            const QJsonObject role = byId(accessRoles(orgId), row.value(QStringLiteral("role_id")).toString());
            if (role.isEmpty())
                continue;
            row.insert(QStringLiteral("role"), role);
            rows.append(row);
        }
        return listed(QStringLiteral("principal_roles"), rows);
    }

    // The organization actions each built-in organization role holds.
    static QHash<QString, QStringList> organizationActions()
    {
        const QStringList guest{QStringLiteral("organization.list"), QStringLiteral("organization.read"), QStringLiteral("space.list")};
        const QStringList member = guest + QStringList{QStringLiteral("membership.list"), QStringLiteral("role.read"),
                                                       QStringLiteral("group.read"), QStringLiteral("tag.read"), QStringLiteral("space.create")};
        const QStringList billing{QStringLiteral("plan.read"), QStringLiteral("usage.read"), QStringLiteral("add_on.read"),
                                  QStringLiteral("role.read"), QStringLiteral("billing.read"), QStringLiteral("billing.manage")};
        const QStringList admin = member + QStringList{
                QStringLiteral("organization.update_policy"), QStringLiteral("membership.invite"),
                QStringLiteral("membership.invite_cancel"), QStringLiteral("membership.create"),
                QStringLiteral("plan.read"), QStringLiteral("usage.read"), QStringLiteral("billing.read"), QStringLiteral("add_on.read"),
                QStringLiteral("add_on.install"), QStringLiteral("role.create"), QStringLiteral("role.update"), QStringLiteral("role.archive"),
                QStringLiteral("group.create"), QStringLiteral("group.update"), QStringLiteral("group.archive"),
                QStringLiteral("group.membership_change"), QStringLiteral("principal_role.grant"), QStringLiteral("principal_role.revoke"),
                QStringLiteral("tag.create"), QStringLiteral("tag.update"), QStringLiteral("tag.archive"), QStringLiteral("resource_grant.read")};
        return {{QStringLiteral("guest"), guest}, {QStringLiteral("member"), member}, {QStringLiteral("billing"), billing},
                {QStringLiteral("admin"), admin}, {QStringLiteral("owner"), admin + billing}};
    }

    // What the signed-in user holds across `orgId`: their built-in
    // organization roles' actions, and those of the roles given to them or
    // to a group of theirs.
    QSet<QString> heldInOrganization(const QString &orgId)
    {
        QSet<QString> held;
        const QHash<QString, QStringList> builtIn = organizationActions();
        for (const QString &role : rolesIn(orgId))
            for (const QString &action : builtIn.value(role)) held.insert(action);
        const QString membership = membershipIn(orgId);
        const QStringList groups = groupsOf(orgId, membership);
        for (const QJsonValue &value : m_principalRoles.value(orgId)) {
            const QJsonObject row = value.toObject();
            if (row.value(QStringLiteral("organization_membership_id")).toString() != membership
                && !groups.contains(row.value(QStringLiteral("group_id")).toString()))
                continue;
            for (const QJsonValue &action : byId(accessRoles(orgId), row.value(QStringLiteral("role_id")).toString())
                                                .value(QStringLiteral("actions")).toArray())
                held.insert(action.toString());
        }
        return held;
    }

    // What the signed-in user holds in space `spaceId`: their grants on it,
    // and, as an owner or admin, a space operator's actions in every space.
    bool heldInSpace(const QString &orgId, const QString &spaceId, const QString &action)
    {
        if (holds(orgId, spaceId, action))
            return true;
        if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")}))
            return false;
        const QJsonObject operating = byId(accessRoles(orgId), QStringLiteral("role-space_operator"));
        return operating.value(QStringLiteral("actions")).toArray().contains(action);
    }

    // `GET action-catalog`: the actions Core lists, each `allowed` as the
    // signed-in user may use it across the organization or, with `spaceId`,
    // in that space, where an add-on's action also needs the add-on active.
    QByteArray actionCatalog(const QString &orgId, const QString &spaceId)
    {
        QStringList atomic;
        for (const auto &[role, held] : atomicRoles()) atomic.append(role);
        const QStringList spaceKeys = actionsOf(atomic) + QStringList{
                QStringLiteral("addon.controlled_docs.approve"), QStringLiteral("addon.controlled_docs.document_manage"),
                QStringLiteral("addon.controlled_docs.review_read")};
        QStringList organizationKeys{QStringLiteral("organization.transfer_ownership")};
        for (const QStringList &actions : organizationActions())
            for (const QString &action : actions)
                if (!organizationKeys.contains(action) && !spaceKeys.contains(action)) organizationKeys.append(action);
        // The space actions Core reads only from a grant on the place.
        static const QStringList bound{QStringLiteral("content."), QStringLiteral("document."), QStringLiteral("upload."),
                                       QStringLiteral("folder."), QStringLiteral("share."), QStringLiteral("event_history."),
                                       QStringLiteral("addon.")};
        const QSet<QString> organization = spaceId.isEmpty() ? heldInOrganization(orgId) : QSet<QString>();
        QJsonArray actions;
        for (const QString &key : organizationKeys + spaceKeys) {
            const bool space = spaceKeys.contains(key);
            // Space metadata and reading grants work on the organization or a space.
            const QString scope = key.startsWith(QLatin1String("space.")) || key == QLatin1String("resource_grant.read")
                                  ? QStringLiteral("either") : space ? QStringLiteral("space") : QStringLiteral("organization");
            const bool reserved = key == QLatin1String("organization.transfer_ownership");
            const bool addOn = key.startsWith(QLatin1String("addon."));
            const bool allowed = !reserved
                                 && (spaceId.isEmpty() ? scope != QLatin1String("space") && organization.contains(key)
                                                       : scope != QLatin1String("organization") && heldInSpace(orgId, spaceId, key)
                                                         && (!addOn || addOnActive(orgId, spaceId, key.section(QLatin1Char('.'), 1, 1))));
            QJsonObject row{{QStringLiteral("key"), key},
                    {QStringLiteral("axis"), space ? QStringLiteral("space") : QStringLiteral("organization")},
                    {QStringLiteral("token_scope"), scope},
                    {QStringLiteral("resource_grant"), std::any_of(bound.begin(), bound.end(), [&](const QString &prefix) { return key.startsWith(prefix); })},
                    {QStringLiteral("allowed"), allowed},
                    {QStringLiteral("system_only"), reserved}};
            if (addOn)
                row.insert(QStringLiteral("product_key"), key.section(QLatin1Char('.'), 1, 1));
            actions.append(row);
        }
        return jsonReply(200, {{QStringLiteral("catalog_version"), 1}, {QStringLiteral("actions"), actions}});
    }

    // Roles, groups, principal roles, tags, the grants on spaces, folders,
    // documents, and tags, and the access reaching a resource, member, or
    // group, for an owner or admin.
    std::optional<QByteArray> organizationAccess(const QByteArray &method, const QStringList &parts,
                                                const QJsonObject &json)
    {
        if (parts.size() < 6 || parts.at(3) != QLatin1String("organizations"))
            return std::nullopt;
        const QString orgId = parts.at(4);
        const QString kind = parts.at(5);
        QJsonObject resource;
        QString leaf;
        const auto grantLeaf = [](const QString &part) { return part == QLatin1String("grants") || part == QLatin1String("access"); };
        // One grant of a space, folder, document, or tag: `…/grants/:id`.
        const QString grantId = parts.last() != QLatin1String("grants") && parts.size() >= 9 && parts.at(parts.size() - 2) == QLatin1String("grants")
                              ? parts.last() : QString();
        if (!grantId.isEmpty() && method == "DELETE") {
            if (!holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")}))
                return errorReply(403, QStringLiteral("forbidden"));
            if (kind == QLatin1String("tags") && parts.size() == 9)
                return revokeGrant(grantResource(QStringLiteral("tag"), {}, parts.at(6)), grantId);
            if (kind == QLatin1String("spaces") && parts.size() == 9)
                return revokeGrant(grantResource(QStringLiteral("space"), parts.at(6), {}), grantId);
            if (kind == QLatin1String("spaces") && parts.size() == 11)
                return revokeGrant(grantResource(parts.at(7) == QLatin1String("folders") ? QStringLiteral("folder") : QStringLiteral("item"),
                                                 parts.at(6), parts.at(8)), grantId);
            return std::nullopt;
        }
        if (kind == QLatin1String("spaces") && parts.size() == 8 && grantLeaf(parts.at(7))) {
            resource = grantResource(QStringLiteral("space"), parts.at(6), {});
            leaf = parts.at(7);
        } else if (kind == QLatin1String("spaces") && parts.size() == 10 && grantLeaf(parts.at(9))
                   && (parts.at(7) == QLatin1String("folders") || parts.at(7) == QLatin1String("documents"))) {
            resource = grantResource(parts.at(7) == QLatin1String("folders") ? QStringLiteral("folder") : QStringLiteral("item"),
                                     parts.at(6), parts.at(8));
            leaf = parts.at(9);
        } else if (kind == QLatin1String("tags") && parts.size() == 8 && parts.at(7) == QLatin1String("grants")) {
            resource = grantResource(QStringLiteral("tag"), {}, parts.at(6));
            leaf = parts.at(7);
        }
        const bool reach = (kind == QLatin1String("members") || kind == QLatin1String("groups")) && parts.size() == 8
                           && parts.at(7) == QLatin1String("access");
        if (leaf.isEmpty() && kind == QLatin1String("spaces"))
            return std::nullopt;
        static const QStringList kinds{QStringLiteral("action-catalog"), QStringLiteral("roles"), QStringLiteral("groups"),
                                       QStringLiteral("principal-roles"), QStringLiteral("tags")};
        if (leaf.isEmpty() && !reach && !kinds.contains(kind))
            return std::nullopt;
        // Every member reads the catalog, roles, groups and their members, and tags.
        const bool directory = method == "GET" && leaf.isEmpty() && !reach
                               && (kind == QLatin1String("action-catalog")
                                   || (kind != QLatin1String("principal-roles") && parts.size() == 6)
                                   || (kind == QLatin1String("groups") && parts.size() == 8 && parts.at(7) == QLatin1String("members")));
        if (directory ? myMembership(orgId).isEmpty() : !holdsAny(orgId, {QStringLiteral("owner"), QStringLiteral("admin")}))
            return errorReply(403, QStringLiteral("forbidden"));
        QJsonArray &roles = accessRoles(orgId);
        const QString next = QStringLiteral("access-%1").arg(++m_nextAccess);
        const QString name = json.value(QStringLiteral("name")).toString().trimmed();
        if (!leaf.isEmpty()) {
            if (method == "GET" && leaf == QLatin1String("access"))
                return accessOf(orgId, resource);
            if (method == "GET")
                return resourceExists(orgId, resource) ? listed(QStringLiteral("grants"), grantsOn(orgId, resource))
                                                       : errorReply(404, QStringLiteral("not_found"));
            if (method == "PUT" && leaf == QLatin1String("grants"))
                return replaceGrants(orgId, resource, json);
            if (method == "POST" && leaf == QLatin1String("grants"))
                return createGrant(orgId, resource, json);
            if (method == "PUT" && resource.value(QStringLiteral("resource_kind")) != QLatin1String("space"))
                return setInheritance(orgId, resource, json);
            return std::nullopt;
        }
        if (reach && method == "GET")
            return reaching(orgId, kind == QLatin1String("members") ? QStringLiteral("user") : QStringLiteral("group"), parts.at(6));
        const QString id = parts.size() > 6 ? parts.at(6) : QString();
        const QString action = parts.size() > 7 ? parts.at(7) : QString();
        if (kind == QLatin1String("action-catalog"))
            return actionCatalog(orgId, query().queryItemValue(QStringLiteral("space_id")));
        if (kind == QLatin1String("principal-roles")) {
            if (method == "GET")
                return principalRoles(orgId);
            QJsonArray &assigned = m_principalRoles[orgId];
            const bool owner = holdsAny(orgId, {QStringLiteral("owner")});
            // A member's built-in roles live on their membership row.
            if (method == "DELETE" && id.startsWith(QLatin1String("system-"))) {
                const QString member = id.section(QLatin1Char('-'), 1, 1), key = id.section(QLatin1Char('-'), 2);
                const QJsonObject row = byId(m_members.value(orgId), member);
                if (!row.value(QStringLiteral("roles")).toArray().contains(key))
                    return errorReply(404, QStringLiteral("not_found"));
                if (key == QLatin1String("owner") && !owner)
                    return errorReply(403, QStringLiteral("forbidden"));
                if (key == QLatin1String("owner") && owners(orgId) == 1)
                    return errorReply(409, QStringLiteral("last_owner"));
                update(m_members[orgId], member, [&](QJsonObject &changed) {
                    QJsonArray kept;
                    for (const QJsonValue &held : changed.value(QStringLiteral("roles")).toArray())
                        if (held.toString() != key) kept.append(held);
                    changed.insert(QStringLiteral("roles"), kept);
                });
                return http(204, {});
            }
            if (method == "DELETE") {
                if (byId(assigned, id).isEmpty())
                    return errorReply(404, QStringLiteral("not_found"));
                drop(assigned, id);
                return http(204, {});
            }
            const QJsonObject granted = byId(roles, json.value(QStringLiteral("role_id")).toString());
            if (granted.isEmpty())
                return errorReply(404, QStringLiteral("not_found"));
            if (granted.value(QStringLiteral("key")) == QLatin1String("owner") && !owner)
                return errorReply(403, QStringLiteral("forbidden"));
            const bool group = json.contains(QStringLiteral("group_id"));
            static const QStringList builtIn{QStringLiteral("owner"), QStringLiteral("admin"), QStringLiteral("member"),
                                             QStringLiteral("billing"), QStringLiteral("guest")};
            const QString key = granted.value(QStringLiteral("key")).toString();
            if (!group && granted.value(QStringLiteral("origin")) == QLatin1String("system") && builtIn.contains(key)) {
                const QString member = json.value(QStringLiteral("organization_membership_id")).toString();
                if (!update(m_members[orgId], member, [&](QJsonObject &changed) {
                        QJsonArray held = changed.value(QStringLiteral("roles")).toArray();
                        if (!held.contains(key)) held.append(key);
                        changed.insert(QStringLiteral("roles"), held);
                    }))
                    return errorReply(404, QStringLiteral("not_found"));
                return jsonReply(201, {{QStringLiteral("principal_role"), QJsonObject{
                        {QStringLiteral("id"), QStringLiteral("system-%1-%2").arg(member, key)}, {QStringLiteral("role_id"), granted.value(QStringLiteral("id"))},
                        {QStringLiteral("principal_kind"), QStringLiteral("user")}, {QStringLiteral("organization_membership_id"), member},
                        {QStringLiteral("group_id"), QJsonValue::Null}}}});
            }
            QJsonObject row{{QStringLiteral("id"), next}, {QStringLiteral("role_id"), json.value(QStringLiteral("role_id"))},
                    {QStringLiteral("principal_kind"), group ? QStringLiteral("group") : QStringLiteral("user")},
                    {QStringLiteral("organization_membership_id"), group ? QJsonValue(QJsonValue::Null)
                                                                        : json.value(QStringLiteral("organization_membership_id"))},
                    {QStringLiteral("group_id"), group ? json.value(QStringLiteral("group_id")) : QJsonValue(QJsonValue::Null)}};
            assigned.append(row);
            return jsonReply(201, {{QStringLiteral("principal_role"), row}});
        }
        QJsonArray &rows = kind == QLatin1String("roles") ? roles : kind == QLatin1String("groups") ? m_groups[orgId] : m_tags[orgId];
        const QString single = kind.chopped(1);
        if (kind == QLatin1String("roles") && action == QLatin1String("holders") && method == "GET")
            return roleHolders(orgId, id);
        if (kind == QLatin1String("groups") && action == QLatin1String("members")) {
            QJsonArray &members = m_groupMembers[id];
            const QString membership = parts.size() > 8 ? parts.at(8) : json.value(QStringLiteral("organization_membership_id")).toString();
            if (method == "GET")
                return listed(QStringLiteral("members"), members);
            if (method == "DELETE") {
                for (qsizetype at = 0; at < members.size(); ++at)
                    if (members.at(at).toObject().value(QStringLiteral("organization_membership_id")) == membership) members.removeAt(at--);
                return http(204, {});
            }
            const QJsonObject member{{QStringLiteral("id"), next}, {QStringLiteral("group_id"), id},
                    {QStringLiteral("organization_membership_id"), membership}};
            members.append(member);
            return jsonReply(201, {{QStringLiteral("member"), member}});
        }
        if (method == "GET" && id.isEmpty())
            return listed(kind, rows);
        if (method == "POST" && id.isEmpty()) {
            for (const QJsonValue &row : std::as_const(rows))
                if (row.toObject().value(QStringLiteral("name")).toString().compare(name, Qt::CaseInsensitive) == 0)
                    return errorReply(409, QStringLiteral("already_exists"));
            QJsonObject row{{QStringLiteral("id"), next}, {QStringLiteral("name"), name},
                    {QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}};
            if (kind == QLatin1String("roles")) {
                if (json.value(QStringLiteral("key")).toString().startsWith(QLatin1String("addon.")))
                    return errorReply(422, QStringLiteral("reserved_role_key"));
                row.insert(QStringLiteral("key"), json.value(QStringLiteral("key")));
                row.insert(QStringLiteral("origin"), QStringLiteral("organization"));
                row.insert(QStringLiteral("actions"), json.value(QStringLiteral("actions")));
            } else if (kind == QLatin1String("tags")) {
                row.insert(QStringLiteral("access_controlled"), json.value(QStringLiteral("access_controlled")).toBool());
            }
            rows.append(row);
            return jsonReply(201, {{single, row}});
        }
        const QJsonObject row = byId(rows, id);
        if (row.isEmpty())
            return errorReply(404, QStringLiteral("not_found"));
        if (row.value(QStringLiteral("origin")) == QLatin1String("system"))
            return errorReply(409, QStringLiteral("system_role"));
        if (row.value(QStringLiteral("origin")) == QLatin1String("add_on"))
            return errorReply(409, QStringLiteral("add_on_role"));
        if (method == "POST" && action == QLatin1String("archive")) {
            drop(rows, id);
            return jsonReply(200, {{single, row}});
        }
        if (method == "PATCH") {
            update(rows, id, [&](QJsonObject &changed) {
                for (auto it = json.begin(); it != json.end(); ++it) changed.insert(it.key(), it.value());
                changed.insert(QStringLiteral("revision"), changed.value(QStringLiteral("revision")).toInt() + 1);
            });
            return jsonReply(200, {{single, byId(rows, id)}});
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

    QJsonObject addSpace(const QString &orgId, const QString &name, const QString &visibility)
    {
        QJsonObject space;
        space.insert(QStringLiteral("id"), QStringLiteral("space-%1").arg(++m_nextSpace));
        space.insert(QStringLiteral("organization_id"), orgId);
        space.insert(QStringLiteral("name"), name);
        space.insert(QStringLiteral("visibility"), visibility);
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

    // The account signing in as `identifier`: an email, or `org-slug/username`
    // for an account an organization manages.
    QJsonObject user(const QString &identifier) const
    {
        const bool managed = !identifier.contains(QLatin1Char('@'));
        return {{QStringLiteral("id"), userIdOf(identifier)},
                {QStringLiteral("email"), managed ? QJsonValue(QJsonValue::Null) : QJsonValue(identifier)},
                {QStringLiteral("email_confirmed"), !managed && !m_pendingEmails.contains(identifier)},
                {QStringLiteral("pending_email"), QJsonValue::Null},
                {QStringLiteral("identifier"), identifier},
                {QStringLiteral("username"), managed ? QJsonValue(identifier.section(QLatin1Char('/'), 1)) : QJsonValue(QJsonValue::Null)},
                {QStringLiteral("name"), QJsonValue::Null},
                {QStringLiteral("managed"), managed}};
    }

    // The signed-in user's tokens: listed without their secret, made only
    // from a recent sign-in, revoked by id.
    QByteArray apiTokens(const QByteArray &method, const QJsonObject &json)
    {
        if (m_lastAuth != QStringLiteral("Bearer access-%1").arg(m_sessionEpoch))
            return errorReply(401, QStringLiteral("unauthenticated"));
        if (method == "GET")
            return jsonReply(200, {{QStringLiteral("tokens"), m_apiTokens}});
        if (method == "DELETE") {
            const QString id = m_lastPath.section(QLatin1Char('/'), -1);
            for (int i = 0; i < m_apiTokens.size(); ++i) {
                if (QString::number(m_apiTokens.at(i).toObject().value(QStringLiteral("id")).toInt()) != id) continue;
                m_apiTokens.removeAt(i);
                return http(204, {});
            }
            return errorReply(404, QStringLiteral("not_found"));
        }
        if (m_signInStale)
            return errorReply(403, QStringLiteral("forbidden"));
        m_tokenRequest = json;
        if (json.value(QStringLiteral("scopes")).toArray().isEmpty())
            return errorReply(422, QStringLiteral("invalid_scope"));
        const int id = m_apiTokens.size() + 1;
        const QString secret = QStringLiteral("mat_secret%1").arg(id);
        QJsonObject token{{QStringLiteral("id"), id}, {QStringLiteral("name"), json.value(QStringLiteral("name"))},
                          {QStringLiteral("token_prefix"), secret.left(12)},
                          {QStringLiteral("expires_at"), json.value(QStringLiteral("expires_at"))},
                          {QStringLiteral("last_used_at"), QJsonValue::Null},
                          {QStringLiteral("scopes"), json.value(QStringLiteral("scopes"))}};
        m_apiTokens.prepend(token);
        token.insert(QStringLiteral("token"), secret);
        return jsonReply(201, token);
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
    // pages a collection: ordered by id, or kept in its order and keyed by
    // position when `inOrder`, `limit` 1 to 100 (else 50) entries after the
    // key the cursor encodes, under the list's own name and under "data",
    // with the cursor of the next page while there is one. A cursor that
    // does not encode a key is 400 invalid_cursor.
    // A page of `list` under `kind`, each page also carrying `extra`.
    QByteArray listed(const QString &kind, const QJsonArray &list, bool inOrder = false, const QJsonObject &extra = {}) const
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

        QList<std::pair<QString, QJsonValue>> keyed;
        for (qsizetype at = 0; at < list.size(); ++at)
            keyed.append({inOrder ? QString::number(at + 1) : jsonId(list.at(at).toObject().value(QStringLiteral("id"))), list.at(at)});
        if (!inOrder)
            std::sort(keyed.begin(), keyed.end(), [](const auto &a, const auto &b) { return idBefore(a.first, b.first); });
        QJsonArray entries;
        QString last;
        bool more = false;
        for (const auto &[key, value] : std::as_const(keyed)) {
            if (!after.isEmpty() && !idBefore(after, key))
                continue;
            if (entries.size() == limit) {
                more = true;
                break;
            }
            entries.append(value);
            last = key;
        }
        const QJsonValue next = more
                ? QJsonValue(QString::fromLatin1(last.toLatin1().toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals)))
                : QJsonValue(QJsonValue::Null);
        QJsonObject page{{kind, entries},
                         {QStringLiteral("data"), entries},
                         {QStringLiteral("page"),
                          QJsonObject{{QStringLiteral("limit"), limit},
                                      {QStringLiteral("next_cursor"), next},
                                      {QStringLiteral("has_more"), more}}},
                         {QStringLiteral("request_id"), requestId()}};
        for (auto it = extra.begin(); it != extra.end(); ++it) page.insert(it.key(), it.value());
        return jsonReply(200, page);
    }

    static QByteArray single(const QString &kind, const QJsonArray &list, const QString &id)
    {
        return jsonReply(200, QJsonObject{{kind, byId(list, id)}});
    }

    // Creates the organization or space `make` builds from the trimmed
    // `field` of the request, or refuses a blank one. Core answers it under
    // its own name and under "data", beside the creator's membership (`roles`).
    template<typename Make>
    QByteArray created(const QString &kind, const QString &role, const QJsonObject &json,
                              const QString &field, Make make)
    {
        const QString value = json.value(field).toString().trimmed();
        if (value.isEmpty())
            return errorReply(422, QStringLiteral("invalid_request"));
        const QJsonObject item = make(value);
        const QString id = item.value(QStringLiteral("id")).toString();
        const QJsonObject membership{{QStringLiteral("id"), QStringLiteral("membership-") + id},
                                     {kind + QStringLiteral("_id"), id},
                                     {QStringLiteral("roles"), QJsonArray{role}},
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
    QByteArray errorReply(int status, const QString &code, const QJsonObject &details = {}) const
    {
        QJsonObject body{{QStringLiteral("code"), code},
                         {QStringLiteral("error"), code},
                         {QStringLiteral("request_id"), requestId()}};
        if (code == QLatin1String("rate_limited"))
            body.insert(QStringLiteral("retry_after"), retryAfter);
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
    // The setup code each managed account waits on, by identifier.
    QHash<QString, QString> m_setupCodes;
    int m_sessionEpoch = 1;
    QHash<QString, QJsonArray> m_orgsByUser;
    QHash<QString, QJsonArray> m_members;
    QHash<QString, QJsonArray> m_roles;
    QHash<QString, QJsonArray> m_groups;
    QHash<QString, QJsonArray> m_groupMembers;
    QHash<QString, QJsonArray> m_principalRoles;
    QHash<QString, QJsonArray> m_tags;
    QJsonArray m_grants;
    // Each add-on's activation in a space, by "spaceId|product".
    QHash<QString, QJsonObject> m_activations;
    int m_nextAccess = 0;
    QHash<QString, QJsonObject> m_subscriptions;
    QHash<QString, QJsonArray> m_addOns;
    QJsonArray m_catalog;
    QJsonObject m_addOnRequest;
    QJsonArray m_apiTokens;
    QJsonObject m_tokenRequest;
    bool m_signInStale = false;
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
    QHash<QString, QJsonObject> m_references;
};

} // namespace test
} // namespace matome
