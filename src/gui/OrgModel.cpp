#include "OrgModel.h"

#include "JsonList.h"
#include "Session.h"

#include <QJsonArray>
#include <QJsonObject>

namespace matome {

OrgModel::OrgModel(Session &session)
    : QAbstractListModel(&session)
    , m_session(session)
{
}

const OrgRow *OrgModel::find(const QString &orgId) const
{
    for (const OrgRow &row : m_rows) {
        if (row.id == orgId)
            return &row;
    }
    return nullptr;
}

QString OrgModel::nameOf(const QString &orgId) const
{
    const OrgRow *row = find(orgId);
    return row ? row->name : QString();
}

QStringList OrgModel::ids() const
{
    QStringList ids;
    for (const OrgRow &row : m_rows)
        ids.append(row.id);
    return ids;
}

int OrgModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant OrgModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    const OrgRow &row = m_rows.at(index.row());
    switch (role) {
    case OrgIdRole:
        return row.id;
    case NameRole:
        return row.name;
    case RolesRole:
        return row.roles;
    case RevisionRole:
        return row.revision;
    default:
        return {};
    }
}

QHash<int, QByteArray> OrgModel::roleNames() const
{
    return {{OrgIdRole, "orgId"},
            {NameRole, "name"},
            {RolesRole, "roles"},
            {RevisionRole, "revision"}};
}

void OrgModel::reload()
{
    if (!m_session.signedIn()) {
        clear();
        return;
    }
    const int generation = ++m_generation;
    setBusy();
    m_session.authedList(
            orgsPath(), QStringLiteral("organizations"),
            [this, generation] { return generation == m_generation; },
            [this](const Client::Reply &reply, const QJsonArray &list) { applyList(reply, list); });
}

void OrgModel::create(const QString &name)
{
    if (m_busy || !m_session.signedIn())
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
    m_session.authedPost(orgsPath(), body, headers,
                         [this, generation](const Client::Reply &reply) {
                             if (generation != m_generation)
                                 return;
                             if (!reply.ok) {
                                 fail(failCode(reply));
                                 return;
                             }
                             const QJsonObject org =
                                     reply.json.value(QStringLiteral("organization")).toObject();
                             const QString id = jsonId(org.value(QStringLiteral("id")));
                             if (!id.isEmpty())
                                 m_currentOrgId = id;
                             reload();
                         });
}

void OrgModel::select(const QString &orgId)
{
    if (!find(orgId) || m_currentOrgId == orgId)
        return;
    m_currentOrgId = orgId;
    m_session.setLastOrgId(orgId);
    emit changed();
}

void OrgModel::clearCurrent()
{
    if (m_currentOrgId.isEmpty())
        return;
    m_currentOrgId.clear();
    emit changed();
}

void OrgModel::clear()
{
    ++m_generation;
    if (m_rows.isEmpty() && !m_busy && m_errorCode.isEmpty() && m_currentOrgId.isEmpty())
        return;
    beginResetModel();
    m_rows.clear();
    endResetModel();
    m_busy = false;
    m_errorCode.clear();
    m_currentOrgId.clear();
    emit changed();
}

void OrgModel::setBusy()
{
    m_busy = true;
    m_errorCode.clear();
    emit changed();
}

void OrgModel::fail(const QString &code)
{
    m_busy = false;
    m_errorCode = code;
    emit changed();
}

void OrgModel::applyList(const Client::Reply &reply, const QJsonArray &list)
{
    if (!reply.ok) {
        fail(failCode(reply));
        return;
    }

    QVector<OrgRow> rows;
    rows.reserve(list.size());
    for (const QJsonValue &value : list) {
        const OrgRow row = parseRow(value.toObject());
        if (!row.id.isEmpty())
            rows.append(row);
    }

    // The first list after sign-in reopens the remembered organization; later
    // lists (refresh at the root) leave the location alone.
    const bool first = m_rows.isEmpty();
    // A reload of the same organizations keeps the delegates showing them,
    // with their focus and any press under way.
    if (!updateInPlace(m_rows, rows, [this](int at) { emit dataChanged(index(at), index(at)); })) {
        beginResetModel();
        m_rows = rows;
        endResetModel();
    }

    if (!find(m_currentOrgId)) {
        const QString remembered = first ? m_session.lastOrgId() : QString();
        m_currentOrgId = find(remembered) ? remembered : QString();
    }

    m_busy = false;
    m_errorCode.clear();
    emit changed();
}

OrgRow OrgModel::parseRow(const QJsonObject &json)
{
    OrgRow row;
    row.id = json.value(QStringLiteral("id")).toString();
    row.name = json.value(QStringLiteral("name")).toString();
    for (const QJsonValue &role : json.value(QStringLiteral("roles")).toArray())
        row.roles.append(role.toString());
    row.revision = json.value(QStringLiteral("revision")).toInt(1);
    return row;
}

} // namespace matome
