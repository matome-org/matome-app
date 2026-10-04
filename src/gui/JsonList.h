#pragma once

#include "Client.h"

#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QStringList>
#include <QUuid>
#include <QVector>

#include <algorithm>

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

/// The id of the membership of the account `userId` among Core's member rows.
inline QString membershipOf(const QJsonArray &members, const QString &userId)
{
    for (const auto &value : members) {
        const auto member = value.toObject();
        if (!userId.isEmpty() && jsonId(member.value(QStringLiteral("user_id"))) == userId)
            return jsonId(member.value(QStringLiteral("id")));
    }
    return {};
}

/// How a member or invitation row names its person: the email, else, for an
/// account an organization manages, its name or username.
inline QString memberLabel(const QJsonObject &row)
{
    for (const char *field : {"email", "name", "username"}) {
        const QString value = row.value(QLatin1String(field)).toString();
        if (!value.isEmpty())
            return value;
    }
    return {};
}

/// `rows` grouped by `keyOf` each, in the order their first row comes.
template <typename Key>
QList<QJsonArray> grouped(const QJsonArray &rows, Key keyOf)
{
    QStringList order;
    QHash<QString, QJsonArray> groups;
    for (const auto &value : rows) {
        const QString key = keyOf(value.toObject());
        if (!groups.contains(key)) order.append(key);
        groups[key].append(value);
    }
    QList<QJsonArray> list;
    for (const QString &key : std::as_const(order)) list.append(groups.value(key));
    return list;
}

/// Whether `lists` differ from those last kept in `kept` (as compact JSON),
/// which then holds them: a list property notifies only when this says so,
/// so a reload that brings the same rows keeps the delegates showing them.
inline bool changedSince(QByteArray &kept, const QJsonArray &lists)
{
    const QByteArray now = QJsonDocument(lists).toJson(QJsonDocument::Compact);
    if (now == kept)
        return false;
    kept = now;
    return true;
}

/// Takes `rows` into `current` in place when both list the same ids in the
/// same order, calling `changed(at)` for each row whose values differ, so a
/// model keeps the delegates that show them; false, leaving `current` as it
/// is, when the ids differ.
template <typename Row, typename Changed>
bool updateInPlace(QVector<Row> &current, const QVector<Row> &rows, Changed changed)
{
    if (!std::equal(rows.cbegin(), rows.cend(), current.cbegin(), current.cend(),
                    [](const Row &a, const Row &b) { return a.id == b.id; }))
        return false;
    for (qsizetype at = 0; at < rows.size(); ++at) {
        if (rows.at(at) == current.at(at))
            continue;
        current[at] = rows.at(at);
        changed(int(at));
    }
    return true;
}

inline bool validReason(const QString &text)
{
    const QString reason = text.trimmed();
    return !reason.isEmpty() && reason.toUcs4().size() <= 500 && !reason.contains(QChar::Null);
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
