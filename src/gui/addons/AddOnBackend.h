#pragma once

#include "Client.h"
#include <QJsonArray>

namespace matome {
class Session;

class AddOnBackend : public QObject
{
public:
    using QObject::QObject;
    using Live = std::function<bool()>;
    using ListDone = std::function<void(const Client::Reply &, const QJsonArray &)>;
    /// One request of a batch.
    struct Step {
        QByteArray method;
        QString path;
        QJsonObject body;
    };
    using StepDone = std::function<void(qsizetype step, const Client::Reply &)>;
    using BatchDone = std::function<void(const QString &failure)>;
    virtual void request(const QByteArray &method, const QString &path, const QJsonObject &body,
                         const Client::Headers &headers, Client::Done done) = 0;
    virtual void putFile(const QUrl &url, const QByteArray &bytes, const Client::Headers &headers,
                         Client::Done done, Client::Progress progress) = 0;
    virtual void getFile(const QUrl &url, Client::Done done) = 0;
    void list(const QString &path, const QString &key, Live live, ListDone done);
    /// Sends `steps` at once, each with its own idempotency key. While
    /// `live`, `each` sees every reply, then `done` the code of the first
    /// refusal, empty when every step landed.
    void requestAll(const QList<Step> &steps, Live live, StepDone each, BatchDone done);
    using Landed = std::function<void(const QString &failure, bool landed)>;
    /// `requestAll` whose replies count only together: `done` gets the code
    /// of the first refusal and whether any step landed.
    void requestAll(const QList<Step> &steps, Live live, Landed done);
    void upload(const QString &orgId, QJsonObject descriptor, const QByteArray &bytes,
                Live live, Client::Done done, Client::Progress progress = {});

private:
    void page(const QString &path, const QString &key, const QString &cursor,
              const QJsonArray &rows, Live live, ListDone done);
};

class CoreAddOnBackend final : public AddOnBackend
{
public:
    explicit CoreAddOnBackend(Session &session);
    void request(const QByteArray &method, const QString &path, const QJsonObject &body,
                 const Client::Headers &headers, Client::Done done) override;
    void putFile(const QUrl &url, const QByteArray &bytes, const Client::Headers &headers,
                 Client::Done done, Client::Progress progress) override;
    void getFile(const QUrl &url, Client::Done done) override;

private:
    Session &m_session;
};
}
