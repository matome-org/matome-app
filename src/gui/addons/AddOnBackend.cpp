#include "AddOnBackend.h"
#include "JsonList.h"
#include "Session.h"
#include <QCryptographicHash>
#include <QUrlQuery>

namespace matome {
CoreAddOnBackend::CoreAddOnBackend(Session &session) : AddOnBackend(&session), m_session(session) {}

void CoreAddOnBackend::request(const QByteArray &method, const QString &path,
                              const QJsonObject &body, const Client::Headers &headers, Client::Done done)
{
    if (method == "GET") m_session.authedGet(path, std::move(done));
    else if (method == "PUT") m_session.authedPut(path, body, headers, std::move(done));
    else if (method == "POST") m_session.authedPost(path, body, headers, std::move(done));
    else if (method == "DELETE") m_session.authedDelete(path, headers, std::move(done));
}

void CoreAddOnBackend::putFile(const QUrl &url, const QByteArray &bytes, const Client::Headers &headers,
                             Client::Done done, Client::Progress progress)
{
    m_session.client()->putRaw(url, bytes, headers, std::move(done), std::move(progress));
}

void CoreAddOnBackend::getFile(const QUrl &url, Client::Done done)
{
    m_session.client()->getRaw(url, std::move(done));
}

void AddOnBackend::list(const QString &path, const QString &key, Live live, ListDone done)
{
    page(path, key, {}, {}, std::move(live), std::move(done));
}

void AddOnBackend::page(const QString &path, const QString &key, const QString &cursor,
                       const QJsonArray &rows, Live live, ListDone done)
{
    if (!live()) return;
    QUrl url(path);
    QUrlQuery query(url);
    if (!cursor.isEmpty()) query.addQueryItem(QStringLiteral("cursor"), cursor);
    url.setQuery(query);
    request("GET", url.toString(), {}, {},
            [this, path, key, cursor, rows, live, done](const Client::Reply &reply) {
        if (!live()) return;
        if (!reply.ok) { done(reply, {}); return; }
        QJsonArray all = rows;
        for (const auto &row : reply.json.value(key).toArray()) all.append(row);
        const auto pagination = reply.json.value(QStringLiteral("page")).toObject();
        const QString next = pagination.value(QStringLiteral("next_cursor")).toString();
        if (pagination.value(QStringLiteral("has_more")).toBool()) {
            if (next.isEmpty() || next == cursor) {
                Client::Reply error;
                error.code = QStringLiteral("invalid_request");
                done(error, {});
            } else page(path, key, next, all, live, done);
        } else done(reply, all);
    });
}

void AddOnBackend::upload(const QString &orgId, QJsonObject descriptor, const QByteArray &bytes,
                         Live live, Client::Done done, Client::Progress progress)
{
    descriptor.insert(QStringLiteral("byte_size"), bytes.size());
    descriptor.insert(QStringLiteral("checksum_sha256"), QString::fromLatin1(
            QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex()));
    request("POST", orgPath(orgId, QStringLiteral("uploads")), descriptor, idempotencyHeader(),
            [this, orgId, bytes, live, done, progress](const Client::Reply &created) {
        if (!live()) return;
        if (!created.ok) { done(created); return; }
        const auto data = created.json.value(QStringLiteral("data")).toObject();
        const QString id = data.value(QStringLiteral("upload_id")).toString();
        const auto target = data.value(QStringLiteral("request")).toObject();
        const QUrl url(target.value(QStringLiteral("url")).toString());
        if (id.isEmpty() || !url.isValid() || url.isEmpty()) {
            Client::Reply error;
            error.code = QStringLiteral("invalid_request");
            done(error);
            return;
        }
        Client::Headers headers;
        const auto values = target.value(QStringLiteral("headers")).toObject();
        for (auto it = values.begin(); it != values.end(); ++it)
            headers.append({it.key().toUtf8(), it.value().toString().toUtf8()});
        const QJsonObject body{{QStringLiteral("generation"), data.value(QStringLiteral("generation"))}};
        const auto finish = [this, orgId, id, live, done](const Client::Reply &reply) {
            if (!live()) return;
            if (reply.ok) { done(reply); return; }
            request("POST", orgPath(orgId, QStringLiteral("uploads/%1/abort").arg(id)), {},
                    idempotencyHeader(), [live, done, reply](const Client::Reply &) {
                if (live()) done(reply);
            });
        };
        putFile(url, bytes, headers, [this, orgId, id, body, live, finish](const Client::Reply &stored) {
            if (!live()) return;
            if (!stored.ok) { finish(stored); return; }
            request("POST", orgPath(orgId, QStringLiteral("uploads/%1/complete").arg(id)),
                    body, idempotencyHeader(), [live, finish](const Client::Reply &reply) {
                if (live()) finish(reply);
            });
        }, [live, progress](qint64 sent, qint64 total) {
            if (live() && progress) progress(sent, total);
        });
    });
}
}
