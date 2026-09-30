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
    virtual void request(const QByteArray &method, const QString &path, const QJsonObject &body,
                         const Client::Headers &headers, Client::Done done) = 0;
    virtual void putFile(const QUrl &url, const QByteArray &bytes, const Client::Headers &headers,
                         Client::Done done, Client::Progress progress) = 0;
    virtual void getFile(const QUrl &url, Client::Done done) = 0;
    void list(const QString &path, const QString &key, Live live, ListDone done);
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
