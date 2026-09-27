#include "Client.h"

#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>

#include <memory>

namespace matome {
namespace {

constexpr qint64 kMaxJsonBytes = 1024 * 1024;
constexpr qint64 kMaxFileBytes = 32 * 1024 * 1024;

QString mapStatus(int status, const QString &server)
{
    if (status == 401)
        return QStringLiteral("unauthenticated");
    if (status == 403)
        return QStringLiteral("forbidden");
    if (status == 404)
        return QStringLiteral("not_found");
    if (status >= 200 && status < 300)
        return {};
    if (status >= 500)
        return QStringLiteral("server");
    return server.isEmpty() ? QStringLiteral("invalid_request") : server;
}

QUrl join(const QUrl &base, const QString &path)
{
    QUrl url = base;
    const int query = path.indexOf(QLatin1Char('?'));
    url.setPath(query < 0 ? path : path.left(query));
    url.setQuery(query < 0 ? QString() : path.mid(query + 1));
    url.setFragment(QString());
    return url;
}

} // namespace

Client::Client(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
}

void Client::setBaseUrl(const QUrl &url)
{
    m_baseUrl = url;
}

void Client::setAccessToken(const QString &token)
{
    m_accessToken = token;
}

void Client::setTimeoutMs(int ms)
{
    m_timeoutMs = qMax(1, ms);
}

void Client::get(const QString &path, Done done, const Headers &headers)
{
    send("GET", path, {}, headers, std::move(done));
}

void Client::post(const QString &path, const QJsonObject &body, Done done, const Headers &headers)
{
    send("POST", path, body, headers, std::move(done));
}

void Client::patch(const QString &path, const QJsonObject &body, Done done, const Headers &headers)
{
    send("PATCH", path, body, headers, std::move(done));
}

void Client::del(const QString &path, Done done, const Headers &headers)
{
    send("DELETE", path, {}, headers, std::move(done));
}

void Client::putRaw(const QUrl &url, const QByteArray &bytes, const Headers &headers, Done done,
                    const Progress &progress)
{
    sendRaw("PUT", url, bytes, headers, false, std::move(done), progress);
}

void Client::getRaw(const QUrl &url, Done done)
{
    sendRaw("GET", url, {}, {}, false, std::move(done));
}

void Client::abortAll()
{
    ++m_generation;
    const auto replies = m_network->findChildren<QNetworkReply *>();
    for (QNetworkReply *reply : replies)
        reply->abort();
}

void Client::send(const QByteArray &method, const QString &path, const QJsonObject &body,
                  const Headers &headers, Done done)
{
    Headers all = headers;
    if (!m_accessToken.isEmpty())
        all.prepend({QByteArrayLiteral("Authorization"),
                     QByteArrayLiteral("Bearer ") + m_accessToken.toUtf8()});
    QByteArray payload;
    if (method != "GET" && method != "DELETE")
        payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
    sendRaw(method, join(m_baseUrl, path), payload, all, true, std::move(done));
}

void Client::sendRaw(const QByteArray &method, const QUrl &url, const QByteArray &bytes,
                     const Headers &headers, bool json, Done done, const Progress &progress)
{
    const QString scheme = url.scheme();
    if (!url.isValid() || url.host().isEmpty()
        || (scheme != QLatin1String("http") && scheme != QLatin1String("https"))) {
        Reply reply;
        reply.code = QStringLiteral("network");
        done(reply);
        return;
    }

    QNetworkRequest request(url);
    request.setTransferTimeout(m_timeoutMs);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         json ? QNetworkRequest::SameOriginRedirectPolicy
                              : QNetworkRequest::NoLessSafeRedirectPolicy);
    if (json)
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    for (const auto &header : headers)
        request.setRawHeader(header.first, header.second);

    const int generation = m_generation;
    QNetworkReply *reply = m_network->sendCustomRequest(request, method, bytes);
    const qint64 cap = json ? kMaxJsonBytes : kMaxFileBytes;
    reply->setReadBufferSize(cap + 1);
    QTimer::singleShot(m_timeoutMs, reply, [reply] {
        if (!reply->isFinished())
            reply->abort();
    });
    if (progress)
        QObject::connect(reply, &QNetworkReply::uploadProgress, this,
                         [progress](qint64 sent, qint64 total) { progress(sent, total); });

    auto body = std::make_shared<QByteArray>();
    QObject::connect(reply, &QIODevice::readyRead, this, [reply, body, cap] {
        body->append(reply->read(qMax<qint64>(0, cap + 1 - body->size())));
        if (body->size() > cap)
            reply->abort();
    });
    QObject::connect(reply, &QNetworkReply::finished, this,
                     [this, reply, body, generation, done, json, cap] {
                         const int status =
                                 reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                         reply->deleteLater();
                         if (generation != m_generation)
                             return;
                         done(parse(status, *body, body->size() > cap, json));
                     });
}

// Storage bytes are never decoded: only Core speaks JSON, error codes included.
Client::Reply Client::parse(int status, const QByteArray &bytes, bool truncated, bool json)
{
    Reply reply;
    reply.status = status;
    reply.bytes = bytes;
    if (truncated) {
        reply.code = QStringLiteral("invalid_request");
        return reply;
    }
    if (status == 0) {
        reply.code = QStringLiteral("network");
        return reply;
    }

    if (json) {
        QJsonParseError error;
        const QJsonDocument doc = QJsonDocument::fromJson(bytes, &error);
        if (error.error == QJsonParseError::NoError && doc.isObject())
            reply.json = doc.object();
    }

    const QString server = reply.json.value(QStringLiteral("code")).toString();
    reply.code = mapStatus(status, server);
    reply.ok = status >= 200 && status < 300 && reply.code.isEmpty();
    return reply;
}

} // namespace matome
