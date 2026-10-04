#include "PlaceNames.h"

#include "JsonList.h"
#include "Session.h"

namespace matome {

PlaceNames::PlaceNames(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, [this] {
        const QString org = m_session.signedIn() ? m_session.currentOrgId() : QString();
        if (org == m_orgId) return;
        ++m_generation;
        m_orgId = org;
        m_names.clear();
    });
}

QString PlaceNames::name(const QString &kind, const QString &spaceId, const QString &id) const
{
    if (kind == QLatin1String("space")) return m_session.spaces()->nameOf(id);
    if (kind == QLatin1String("tag")) return m_session.accessDirectory()->tagName(id);
    if (kind == QLatin1String("folder") && spaceId == m_session.currentSpaceId()) {
        const QString listed = m_session.folders()->nameOf(id);
        if (!listed.isEmpty()) return listed;
    }
    return m_names.value(kind + QLatin1Char(':') + id);
}

void PlaceNames::want(const QString &kind, const QString &spaceId, const QString &id)
{
    const QString key = kind + QLatin1Char(':') + id;
    if ((kind != QLatin1String("folder") && kind != QLatin1String("document")) || m_orgId.isEmpty()
        || spaceId.isEmpty() || id.isEmpty() || m_names.contains(key) || !name(kind, spaceId, id).isEmpty())
        return;
    m_names.insert(key, {});
    const int generation = m_generation;
    const bool folder = kind == QLatin1String("folder");
    m_backend.request("GET", contentPath(m_orgId, spaceId, (folder ? QStringLiteral("folders/") : QStringLiteral("documents/")) + id),
                      {}, {}, [this, generation, key, folder](const Client::Reply &reply) {
        if (generation != m_generation || !reply.ok) return;
        const auto row = reply.json.value(folder ? QStringLiteral("folder") : QStringLiteral("document")).toObject();
        m_names.insert(key, row.value(folder ? QStringLiteral("name") : QStringLiteral("title")).toString());
        emit changed();
    });
}
}
