#pragma once

#include "Client.h"

#include <QJsonValue>
#include <QUuid>

namespace matome {

inline QString failCode(const Client::Reply &reply)
{
    return reply.code.isEmpty() ? QStringLiteral("network") : reply.code;
}

inline QString jsonId(const QJsonValue &value)
{
    if (value.isString())
        return value.toString();
    if (value.isDouble())
        return QString::number(value.toInteger());
    return {};
}

inline Client::Headers idempotencyHeader()
{
    return {{QByteArrayLiteral("Idempotency-Key"),
             QUuid::createUuid().toString(QUuid::WithoutBraces).toUtf8()}};
}

inline Client::Headers matchHeader(int revision)
{
    return {{QByteArrayLiteral("If-Match"), QByteArray::number(revision)}};
}

inline Client::Headers idempotentMatchHeader(int revision)
{
    return matchHeader(revision) + idempotencyHeader();
}

inline QString orgsPath()
{
    return QStringLiteral("/api/v1/organizations");
}

inline QString orgPath(const QString &orgId, const QString &leaf)
{
    return orgsPath() + QLatin1Char('/') + orgId + QLatin1Char('/') + leaf;
}

inline QString contentPath(const QString &orgId, const QString &spaceId, const QString &leaf)
{
    return orgPath(orgId, QStringLiteral("spaces/%1/%2").arg(spaceId, leaf));
}

} // namespace matome
