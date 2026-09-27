#include "SpaceModel.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonObject>

namespace matome {

SpaceModel::SpaceModel(Session &session)
    : QAbstractListModel(&session)
    , m_session(session)
{
}

const SpaceRow *SpaceModel::find(const QString &spaceId) const
{
    for (const SpaceRow &row : m_rows) {
        if (row.id == spaceId)
            return &row;
    }
    return nullptr;
}

QString SpaceModel::nameOf(const QString &spaceId) const
{
    const SpaceRow *row = find(spaceId);
    return row ? row->name : QString();
}

int SpaceModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant SpaceModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const SpaceRow &row = m_rows.at(index.row());
    switch (role) {
    case SpaceIdRole:
        return row.id;
    case NameRole:
        return row.name;
    case StatusRole:
        return row.status;
    case RevisionRole:
        return row.revision;
    case ColorIndexRole:
        return row.colorIndex;
    default:
        return {};
    }
}

QHash<int, QByteArray> SpaceModel::roleNames() const
{
    return {{SpaceIdRole, "spaceId"},
            {NameRole, "name"},
            {StatusRole, "status"},
            {RevisionRole, "revision"},
            {ColorIndexRole, "colorIndex"}};
}

void SpaceModel::reload()
{
    const QString orgId = m_session.currentOrgId();
    if (!m_session.signedIn() || orgId.isEmpty()) {
        clear();
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    const QString path = orgPath(orgId, QStringLiteral("spaces"));
    m_session.authedList(
            path, QStringLiteral("spaces"), [this, generation] { return generation == m_generation; },
            [this](const Client::Reply &reply, const QJsonArray &list) { applyList(reply, list); });
}

void SpaceModel::create(const QString &name)
{
    const QString orgId = m_session.currentOrgId();
    if (m_busy || !m_session.signedIn() || orgId.isEmpty())
        return;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        fail(QStringLiteral("invalid_request"));
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    QJsonObject body;
    body.insert(QStringLiteral("name"), trimmed);
    Client::Headers headers = idempotencyHeader();
    const QString path = orgPath(orgId, QStringLiteral("spaces"));
    m_session.authedPost(path, body, headers, [this, generation](const Client::Reply &reply) {
        if (generation != m_generation)
            return;
        if (!reply.ok) {
            fail(failCode(reply));
            return;
        }
        const QJsonObject space = reply.json.value(QStringLiteral("space")).toObject();
        const QString id = jsonId(space.value(QStringLiteral("id")));
        if (!id.isEmpty())
            m_currentSpaceId = id;
        reload();
    });
}

void SpaceModel::select(const QString &spaceId)
{
    // An unknown id waits for the load in flight; applyList drops it if absent.
    if ((!find(spaceId) && !m_busy) || m_currentSpaceId == spaceId)
        return;
    m_currentSpaceId = spaceId;
    emit changed();
}

void SpaceModel::clearCurrent()
{
    if (m_currentSpaceId.isEmpty())
        return;
    m_currentSpaceId.clear();
    emit changed();
}

void SpaceModel::clear()
{
    ++m_generation;
    if (m_rows.isEmpty() && !m_busy && m_errorCode.isEmpty() && m_currentSpaceId.isEmpty())
        return;
    beginResetModel();
    m_rows.clear();
    endResetModel();
    m_busy = false;
    m_errorCode.clear();
    m_currentSpaceId.clear();
    emit changed();
}

void SpaceModel::setBusy()
{
    m_busy = true;
    m_errorCode.clear();
    emit changed();
}

void SpaceModel::fail(const QString &code)
{
    m_busy = false;
    m_errorCode = code;
    emit changed();
}

void SpaceModel::applyList(const Client::Reply &reply, const QJsonArray &list)
{
    if (!reply.ok) {
        fail(failCode(reply));
        return;
    }

    QVector<SpaceRow> rows;
    rows.reserve(list.size());
    int color = 0;
    for (const QJsonValue &value : list) {
        const SpaceRow row = parseRow(value.toObject(), color++);
        if (!row.id.isEmpty())
            rows.append(row);
    }

    beginResetModel();
    m_rows = rows;
    endResetModel();

    if (!find(m_currentSpaceId))
        m_currentSpaceId.clear();

    m_busy = false;
    m_errorCode.clear();
    emit changed();
}

SpaceRow SpaceModel::parseRow(const QJsonObject &json, int colorIndex)
{
    SpaceRow row;
    row.id = json.value(QStringLiteral("id")).toString();
    row.name = json.value(QStringLiteral("name")).toString();
    row.status = json.value(QStringLiteral("status")).toString();
    row.revision = json.value(QStringLiteral("revision")).toInt(1);
    row.colorIndex = colorIndex;
    return row;
}

} // namespace matome
