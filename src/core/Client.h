#pragma once

#include <QByteArray>
#include <QJsonObject>
#include <QObject>
#include <QPair>
#include <QString>
#include <QUrl>
#include <QVector>
#include <functional>

class QNetworkAccessManager;

namespace matome {

/// HTTP to one Core origin. QML never calls this; Session does.
class Client : public QObject
{
    Q_OBJECT

public:
    struct Reply {
        bool ok = false;
        int status = 0;
        QString code;
        QJsonObject json;
        QByteArray bytes;
    };

    using Done = std::function<void(const Reply &)>;
    using Headers = QVector<QPair<QByteArray, QByteArray>>;
    using Progress = std::function<void(qint64 sent, qint64 total)>;
    explicit Client(QObject *parent = nullptr);

    void setBaseUrl(const QUrl &url);
    QUrl baseUrl() const { return m_baseUrl; }

    void setAccessToken(const QString &token);

    void setTimeoutMs(int ms);

    void get(const QString &path, Done done, const Headers &headers = {});
    void post(const QString &path, const QJsonObject &body, Done done,
              const Headers &headers = {});
    void patch(const QString &path, const QJsonObject &body, Done done,
               const Headers &headers = {});
    void put(const QString &path, const QJsonObject &body, Done done,
             const Headers &headers = {});
    /// A DELETE carries `body` only when it is not empty.
    void del(const QString &path, Done done, const Headers &headers = {}, const QJsonObject &body = {});

    /// Signed storage PUT/GET: the URL is used as given, without the access
    /// token; a PUT sends the headers its signature names.
    void putRaw(const QUrl &url, const QByteArray &bytes, const Headers &headers, Done done,
                const Progress &progress = {});
    void getRaw(const QUrl &url, Done done);

    void abortAll();

private:
    /// A Core call; a rate limit asking for a short wait is retried `retries` times.
    void send(const QByteArray &method, const QString &path, const QJsonObject &body,
              const Headers &headers, Done done, int retries = 2);
    /// `json`: a Core call (a JSON body both ways, capped small) rather than
    /// storage bytes.
    void sendRaw(const QByteArray &method, const QUrl &url, const QByteArray &bytes,
                 const Headers &headers, bool json, Done done, const Progress &progress = {});
    static Reply parse(int status, const QByteArray &bytes, bool truncated, bool json);

    QNetworkAccessManager *m_network = nullptr;
    QUrl m_baseUrl;
    QString m_accessToken;
    int m_generation = 0;
    int m_timeoutMs = 15000;
};

} // namespace matome
