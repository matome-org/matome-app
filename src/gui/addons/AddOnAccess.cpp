#include "AddOnAccess.h"

#include "JsonList.h"
#include "Session.h"
#include "access/AccessGrants.h"

#include <QHash>
#include <QSet>

#include <memory>

namespace matome {

AddOnAccess::AddOnAccess(Session &session, AddOnManager &addOns)
    : QObject(&session), m_session(session), m_addOns(addOns), m_backend(addOns.backend())
{
    connect(&session, &Session::changed, this, [this] {
        const QString org = m_session.signedIn() ? m_session.currentOrgId() : QString();
        if (org == m_orgId) return;
        ++m_generation;
        m_orgId = org;
        m_pending = 0;
        m_impact.clear();
        emit changed();
    });
}

void AddOnAccess::measure(const QString &key)
{
    if (busy() || m_session.currentOrgId().isEmpty()) return;
    QStringList spaces;
    for (const auto &space : m_addOns.spaces()) spaces.append(space.toMap().value(QStringLiteral("id")).toString());
    m_orgId = m_session.currentOrgId();
    m_pending = 1;
    const int generation = ++m_generation;
    m_impact = {{QStringLiteral("key"), key}, {QStringLiteral("known"), false}};
    emit changed();
    const QString prefix = QStringLiteral("addon.%1.").arg(key);
    struct Count { QSet<QString> holders, spaces; QHash<QString, QSet<QString>> roles; int waiting = 0; bool failed = false; };
    auto count = std::make_shared<Count>();
    count->waiting = int(spaces.size());
    const auto done = [this, count, key] {
        m_pending = 0;
        m_impact = {{QStringLiteral("key"), key}, {QStringLiteral("known"), !count->failed},
                    {QStringLiteral("holders"), count->holders.size()}, {QStringLiteral("spaces"), count->spaces.size()}};
        QVariantMap roles;
        for (auto it = count->roles.cbegin(); it != count->roles.cend(); ++it) roles.insert(it.key(), it.value().size());
        m_impact.insert(QStringLiteral("roles"), roles);
        emit changed();
    };
    if (spaces.isEmpty()) return done();
    for (const QString &space : std::as_const(spaces))
        m_backend.list(contentPath(m_orgId, space, QStringLiteral("grants")), QStringLiteral("grants"),
                       [this, generation] { return live(generation); },
                       [count, done, space, prefix](const Client::Reply &reply, const QJsonArray &rows) {
            count->failed |= !reply.ok;
            for (const auto &value : rows) {
                const auto grant = value.toObject();
                const QString role = grant.value(QStringLiteral("role_key")).toString();
                if (!role.startsWith(prefix)) continue;
                const QString principal = AccessGrants::principalOf(grant);
                count->holders.insert(principal);
                count->spaces.insert(space);
                count->roles[role].insert(principal);
            }
            if (--count->waiting == 0) done();
        });
}
}
