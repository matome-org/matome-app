#pragma once

#include "addons/AddOnBackend.h"
#include <QHash>
#include <QQueue>
#include <QTimer>

namespace matome::test {
class MockAddOnBackend final : public AddOnBackend
{
public:
    struct Call {
        QByteArray method;
        QString path;
        QJsonObject body;
        Client::Headers headers;
        QByteArray bytes;
    };
    using AddOnBackend::AddOnBackend;
    QVector<Call> calls;
    int delayMs = 0;

    void respond(const QByteArray &method, const QString &path, const QJsonObject &json,
                 int status = 200, const QString &code = {})
    {
        Client::Reply reply;
        reply.ok = status >= 200 && status < 300;
        reply.status = status;
        reply.code = code;
        reply.json = json;
        m_replies.insert(method + ' ' + path.toUtf8(), reply);
    }

    void queue(const QByteArray &method, const QString &path, const Client::Reply &reply)
    {
        m_queued[method + ' ' + path.toUtf8()].enqueue(reply);
    }

    void file(const QUrl &url, const QByteArray &bytes)
    {
        Client::Reply reply;
        reply.ok = true;
        reply.status = 200;
        reply.bytes = bytes;
        m_replies.insert("GETFILE " + url.toEncoded(), reply);
    }

    void request(const QByteArray &method, const QString &path, const QJsonObject &body,
                 const Client::Headers &headers, Client::Done done) override
    {
        calls.append({method, path, body, headers, {}});
        deliver(method + ' ' + path.toUtf8(), std::move(done));
    }

    void putFile(const QUrl &url, const QByteArray &bytes, const Client::Headers &headers,
                 Client::Done done, Client::Progress progress) override
    {
        calls.append({"PUTFILE", url.toString(), {}, headers, bytes});
        Client::Reply reply;
        reply.ok = true;
        reply.status = 200;
        QTimer::singleShot(delayMs, this, [done, progress, reply, bytes] {
            if (progress) progress(bytes.size(), bytes.size());
            done(reply);
        });
    }

    void getFile(const QUrl &url, Client::Done done) override
    {
        calls.append({"GETFILE", url.toString(), {}, {}, {}});
        deliver("GETFILE " + url.toEncoded(), std::move(done));
    }

private:
    void deliver(const QByteArray &key, Client::Done done)
    {
        Client::Reply missing;
        missing.status = 404;
        missing.code = QStringLiteral("not_found");
        const auto reply = m_queued[key].isEmpty() ? m_replies.value(key, missing) : m_queued[key].dequeue();
        QTimer::singleShot(delayMs, this, [done, reply] { done(reply); });
    }
    QHash<QByteArray, Client::Reply> m_replies;
    QHash<QByteArray, QQueue<Client::Reply>> m_queued;
};
}
