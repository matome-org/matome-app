#include "ControlledDocs.h"
#include "Session.h"
#include "JsonList.h"
#include <QPointer>
#include <QCryptographicHash>

namespace matome {
ControlledDocs::ControlledDocs(Session &session)
    : QObject(&session), m_session(session), m_addOns(*session.addOns()), m_backend(m_addOns.backend())
{
    connect(&session, &Session::changed, this, [this] {
        if (m_active && (!m_session.signedIn() || m_orgId != m_session.currentOrgId()
                         || m_spaceId != m_session.currentSpaceId())) close();
    });
    connect(&m_addOns, &AddOnManager::changed, this, &ControlledDocs::changed);
}

bool ControlledDocs::live(int generation) const { return m_active && generation == m_generation; }
AddOnBackend::Live ControlledDocs::guard() const
{
    const QPointer<const ControlledDocs> self(this);
    const int generation = m_generation;
    return [self, generation] { return self && self->live(generation); };
}
QVariantMap ControlledDocs::availability() const { return m_addOns.state(QStringLiteral("controlled_docs"), m_spaceId); }
bool ControlledDocs::unavailable() const
{
    const auto state = availability();
    return state.value(QStringLiteral("known")).toBool() && !state.value(QStringLiteral("available")).toBool();
}

QString ControlledDocs::title() const
{
    return m_documentId.isEmpty() ? m_session.spaces()->nameOf(m_spaceId)
                                 : m_document.value(QStringLiteral("title")).toString();
}

bool ControlledDocs::canSubmit() const
{
    if (!m_active || busy() || m_document.isEmpty() || !controlled() || unavailable() || draftStale()) return false;
    for (const auto &value : m_reviews)
        if (value.toObject().value(QStringLiteral("status")).toString() == QLatin1String("open")) return false;
    return m_reviewsError.isEmpty();
}

bool ControlledDocs::draftStale() const
{
    return m_sourceLoaded && m_sourceVersion != m_document.value(QStringLiteral("current_version")).toObject().value(QStringLiteral("id")).toString();
}

bool ControlledDocs::canDecide() const
{
    return m_active && !busy() && !unavailable()
            && m_review.value(QStringLiteral("status")).toString() == QLatin1String("open")
            && !m_membershipId.isEmpty()
            && m_review.value(QStringLiteral("author_membership_id")).toString() != m_membershipId;
}

QString ControlledDocs::documentPath(const QString &suffix) const
{
    return contentPath(m_orgId, m_spaceId, QStringLiteral("documents/%1%2").arg(m_documentId, suffix));
}
QString ControlledDocs::reviewPath(const QString &suffix) const
{
    return orgPath(m_orgId, QStringLiteral("reviews/%1%2").arg(m_review.value(QStringLiteral("id")).toString(), suffix));
}

void ControlledDocs::open(const QString &documentId, bool controlTab)
{
    if (!m_session.inSpace()) return;
    close();
    m_controlTab = controlTab;
    m_active = true;
    m_orgId = m_session.currentOrgId();
    m_spaceId = m_session.currentSpaceId();
    m_documentId = documentId;
    m_addOns.refresh();
    load();
}

void ControlledDocs::close()
{
    ++m_generation;
    ++m_reviewGeneration;
    m_active = m_controlTab = m_saving = m_ruleRead = m_sourceLoaded = false;
    m_pending = 0;
    m_orgId.clear(); m_spaceId.clear(); m_documentId.clear(); m_membershipId.clear();
    m_document = m_rule = m_review = {};
    m_reviews = m_members = m_roles = m_grants = {};
    m_accessError.clear();
    m_errorCode.clear(); m_ruleError.clear(); m_reviewsError.clear(); m_notice.clear();
    m_diff.clear(); m_source.clear(); m_sourceVersion.clear();
    emit sourceChanged();
    emit changed();
}

void ControlledDocs::refresh()
{
    if (!m_active || busy()) return;
    m_addOns.refresh();
    load();
}

void ControlledDocs::load()
{
    const int generation = ++m_generation;
    ++m_reviewGeneration;
    const bool admin = m_session.organizations()->canAdminister(m_orgId);
    m_pending = (m_documentId.isEmpty() ? 2 : 4) + (admin ? 2 : 0);
    m_ruleRead = false;
    m_errorCode.clear(); m_ruleError.clear(); m_reviewsError.clear();
    m_accessError.clear();
    m_review = {};
    m_reviews = {};
    m_diff.clear();
    emit changed();
    const QPointer<ControlledDocs> self(this);
    const auto live = [self, generation] { return self && self->live(generation); };
    m_backend.request("GET", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule")), {}, {},
            [this, live](const Client::Reply &reply) {
        if (!live()) return;
        m_rule = reply.ok ? reply.json.value(QStringLiteral("data")).toObject() : QJsonObject();
        m_ruleRead = reply.ok || reply.status == 404;
        if (!m_ruleRead) m_ruleError = failCode(reply);
        --m_pending;
        emit changed();
    });
    if (!m_documentId.isEmpty()) {
        m_backend.request("GET", documentPath(), {}, {}, [this, live](const Client::Reply &reply) {
            if (!live()) return;
            m_document = reply.ok ? reply.json.value(QStringLiteral("document")).toObject() : QJsonObject();
            if (!reply.ok) m_errorCode = failCode(reply);
            --m_pending;
            emit changed();
        });
        m_backend.list(documentPath(QStringLiteral("/reviews")), QStringLiteral("reviews"), live,
                [this, live](const Client::Reply &reply, const QJsonArray &rows) {
            if (!live()) return;
            m_reviews = reply.ok ? rows : QJsonArray();
            if (!reply.ok) m_reviewsError = failCode(reply);
            --m_pending;
            emit changed();
        });
    }
    m_backend.list(orgPath(m_orgId, QStringLiteral("members")), QStringLiteral("members"), live,
            [this, live](const Client::Reply &reply, const QJsonArray &rows) {
        if (!live()) return;
        m_members = reply.ok ? rows : QJsonArray();
        if (!reply.ok && m_session.organizations()->canAdminister(m_orgId)) m_accessError = failCode(reply);
        m_membershipId.clear();
        if (reply.ok) for (const auto &value : rows) {
            const auto row = value.toObject();
            if (row.value(QStringLiteral("email")).toString().compare(m_session.email(), Qt::CaseInsensitive) == 0)
                m_membershipId = jsonId(row.value(QStringLiteral("id")));
        }
        --m_pending;
        emit changed();
    });
    if (admin) {
        const auto list = [this, live](const QString &path, const QString &key, QJsonArray &target) {
            m_backend.list(path, key, live, [this, live, &target](const Client::Reply &reply, const QJsonArray &rows) {
                if (!live()) return;
                target = reply.ok ? rows : QJsonArray();
                if (!reply.ok) m_accessError = failCode(reply);
                --m_pending;
                emit changed();
            });
        };
        list(orgPath(m_orgId, QStringLiteral("roles")), QStringLiteral("roles"), m_roles);
        list(contentPath(m_orgId, m_spaceId, QStringLiteral("grants")), QStringLiteral("grants"), m_grants);
    }
}

bool ControlledDocs::canAssign() const
{
    return m_active && !busy() && m_session.organizations()->canAdminister(m_orgId) && m_accessError.isEmpty();
}

QJsonArray ControlledDocs::accessActions(bool manage)
{
    QJsonArray actions{QStringLiteral("document.review_read")};
    if (manage) { actions.append(QStringLiteral("document.controlled_docs_manage")); actions.append(QStringLiteral("space.controlled_docs_manage")); }
    else actions.append(QStringLiteral("document.approve"));
    return actions;
}

bool ControlledDocs::roleMatches(const QJsonObject &role, bool manage)
{
    const auto expected = accessActions(manage);
    const auto actions = role.value(QStringLiteral("actions")).toArray();
    if (expected.size() != actions.size()) return false;
    for (const auto &action : expected) if (!actions.contains(action)) return false;
    return true;
}

QVariantList ControlledDocs::grants() const
{
    QVariantList result;
    for (const auto &value : m_grants) {
        auto grant = value.toObject();
        for (const auto &roleValue : m_roles) {
            const auto role = roleValue.toObject();
            if (role.value(QStringLiteral("id")) != grant.value(QStringLiteral("role_id"))) continue;
            if (roleMatches(role, true) || roleMatches(role, false)) {
                grant.insert(QStringLiteral("name"), role.value(QStringLiteral("name")));
                for (const auto &member : m_members)
                    if (member.toObject().value(QStringLiteral("id")) == grant.value(QStringLiteral("organization_membership_id")))
                        grant.insert(QStringLiteral("email"), member.toObject().value(QStringLiteral("email")));
                result.append(grant.toVariantMap());
            }
        }
    }
    return result;
}

void ControlledDocs::grantAccess(const QString &membershipId, bool manage)
{
    if (!canAssign()) return;
    bool found = false;
    for (const auto &member : m_members) found |= jsonId(member.toObject().value(QStringLiteral("id"))) == membershipId;
    if (!found) return;
    const auto actions = accessActions(manage);
    const auto isLive = guard();
    const QString path = contentPath(m_orgId, m_spaceId, QStringLiteral("grants"));
    const auto grant = [this, isLive, path, membershipId](const QString &roleId) {
        if (!isLive()) return;
        m_backend.request("POST", path, {{QStringLiteral("organization_membership_id"), membershipId}, {QStringLiteral("role_id"), roleId}},
                idempotencyHeader(), [this, isLive](const Client::Reply &reply) {
            if (isLive()) finishMutation(reply, QStringLiteral("access_saved"));
        });
    };
    m_saving = true;
    m_errorCode.clear(); m_notice.clear();
    emit changed();
    for (const auto &value : m_roles) {
        const auto role = value.toObject();
        if (roleMatches(role, manage)) { grant(role.value(QStringLiteral("id")).toString()); return; }
    }
    m_backend.request("POST", orgPath(m_orgId, QStringLiteral("roles")),
            {{QStringLiteral("key"), QStringLiteral("controlled-docs-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces))},
             {QStringLiteral("name"), manage ? QStringLiteral("Document control managers") : QStringLiteral("Document reviewers")},
             {QStringLiteral("actions"), actions}}, idempotencyHeader(),
            [this, isLive, grant](const Client::Reply &reply) {
        if (!isLive()) return;
        if (!reply.ok) { finishMutation(reply, {}); return; }
        const auto role = reply.json.value(QStringLiteral("role")).toObject();
        const QString id = role.value(QStringLiteral("id")).toString();
        if (id.isEmpty()) { m_saving = false; m_errorCode = QStringLiteral("invalid_request"); emit changed(); return; }
        m_roles.append(role);
        grant(id);
    });
}

void ControlledDocs::revokeAccess(const QString &grantId)
{
    if (!canAssign()) return;
    bool found = false;
    for (const auto &grant : grants()) found |= grant.toMap().value(QStringLiteral("id")).toString() == grantId;
    if (!found) return;
    mutation("DELETE", contentPath(m_orgId, m_spaceId, QStringLiteral("grants/%1").arg(grantId)), {}, 0, QStringLiteral("access_removed"));
}

void ControlledDocs::mutation(const QByteArray &method, const QString &path, QJsonObject body,
                              int revision, const QString &notice)
{
    if (!m_active || busy()) return;
    m_saving = true;
    m_errorCode.clear();
    m_notice.clear();
    const auto isLive = guard();
    emit changed();
    m_backend.request(method, path, body, idempotentMatchHeader(revision),
            [this, isLive, notice](const Client::Reply &reply) {
        if (isLive()) finishMutation(reply, notice);
    });
}

void ControlledDocs::finishMutation(const Client::Reply &reply, const QString &notice)
{
    m_saving = false;
    if (!reply.ok) {
        const QString code = failCode(reply);
        // Conflict refreshes preserve the server's explanation for the rejected action.
        if (reply.status == 409 || reply.status == 428) {
            m_addOns.refresh();
            load();
        }
        m_errorCode = code;
        emit changed();
        return;
    }
    m_notice = notice;
    if (notice == QLatin1String("review_requested")) emit proposalSubmitted();
    m_session.documents()->reload();
    load();
}

void ControlledDocs::saveRule(bool active)
{
    if (!canManageRule() || unavailable()) return;
    mutation("PUT", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule")),
             {{QStringLiteral("active"), active}}, m_rule.value(QStringLiteral("revision")).toInt(),
             QStringLiteral("rule_saved"));
}

void ControlledDocs::removeRule(const QString &reason)
{
    if (!canManageRule() || m_rule.isEmpty()) return;
    if (!validReason(reason)) { m_errorCode = QStringLiteral("reason_required"); emit changed(); return; }
    const QString path = contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule?reason="))
            + QString::fromLatin1(QUrl::toPercentEncoding(reason.trimmed()));
    mutation("DELETE", path, {}, m_rule.value(QStringLiteral("revision")).toInt(), QStringLiteral("rule_removed"));
}

void ControlledDocs::setControlled(bool enabled, const QString &reason)
{
    if (m_document.isEmpty() || (enabled && unavailable())) return;
    if (!enabled && !validReason(reason)) { m_errorCode = QStringLiteral("reason_required"); emit changed(); return; }
    QString path = documentPath(QStringLiteral("/controlled-docs"));
    if (!enabled) path += QStringLiteral("?reason=") + QString::fromLatin1(QUrl::toPercentEncoding(reason.trimmed()));
    mutation(enabled ? "PUT" : "DELETE", path, {}, m_document.value(QStringLiteral("revision")).toInt(),
             enabled ? QStringLiteral("control_enabled") : QStringLiteral("control_removed"));
}

void ControlledDocs::selectReview(const QString &id)
{
    if (!m_active || busy()) return;
    ++m_reviewGeneration;
    m_review = {};
    m_diff.clear();
    for (const auto &value : m_reviews)
        if (value.toObject().value(QStringLiteral("id")).toString() == id) m_review = value.toObject();
    emit changed();
}

void ControlledDocs::loadDiff()
{
    if (!m_active || busy() || m_review.isEmpty()) return;
    m_pending = 1;
    m_errorCode.clear();
    m_diff.clear();
    const auto isLive = guard();
    const int reviewGeneration = m_reviewGeneration;
    emit changed();
    m_backend.request("GET", reviewPath(QStringLiteral("/diff")), {}, {},
            [this, isLive, reviewGeneration](const Client::Reply &reply) {
        if (!isLive() || reviewGeneration != m_reviewGeneration) return;
        m_pending = 0;
        if (reply.ok) m_diff = reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("diff")).toString();
        else m_errorCode = failCode(reply);
        emit changed();
    });
}

void ControlledDocs::loadPublished()
{
    if (!m_active || busy() || m_document.isEmpty()) return;
    const auto version = m_document.value(QStringLiteral("current_version")).toObject();
    if (version.value(QStringLiteral("content_type")).toString() != QLatin1String("text/markdown")
            || version.value(QStringLiteral("byte_size")).toInteger() > 1024 * 1024) {
        m_errorCode = QStringLiteral("invalid_markdown"); emit changed(); return;
    }
    m_pending = 1;
    m_errorCode.clear();
    const auto isLive = guard();
    emit changed();
    m_backend.request("GET", documentPath(QStringLiteral("/download")), {}, {},
            [this, isLive, version](const Client::Reply &reply) {
        if (!isLive()) return;
        if (!reply.ok) { m_pending = 0; m_errorCode = failCode(reply); emit changed(); return; }
        const QUrl url(reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString());
        m_backend.getFile(url, [this, isLive, version](const Client::Reply &file) {
            if (!isLive()) return;
            m_pending = 0;
            if (file.ok && file.bytes.size() <= 1024 * 1024 && !file.bytes.contains('\0')
                    && QString::fromUtf8(file.bytes).toUtf8() == file.bytes
                    && QString::fromLatin1(QCryptographicHash::hash(file.bytes, QCryptographicHash::Sha256).toHex())
                        == version.value(QStringLiteral("checksum_sha256")).toString()) {
                m_source = QString::fromUtf8(file.bytes);
                m_sourceVersion = version.value(QStringLiteral("id")).toString();
                m_sourceLoaded = true;
                emit sourceChanged();
            } else m_errorCode = file.ok ? QStringLiteral("invalid_markdown") : failCode(file);
            emit changed();
        });
    });
}

void ControlledDocs::downloadCandidate()
{
    if (!m_active || busy() || m_review.isEmpty()) return;
    m_pending = 1;
    m_errorCode.clear();
    const auto isLive = guard();
    const int reviewGeneration = m_reviewGeneration;
    emit changed();
    m_backend.request("GET", reviewPath(QStringLiteral("/candidate/download")), {}, {},
            [this, isLive, reviewGeneration](const Client::Reply &reply) {
        if (!isLive() || reviewGeneration != m_reviewGeneration) return;
        m_pending = 0;
        if (!reply.ok) m_errorCode = failCode(reply);
        else emit m_session.downloadReady(QUrl(reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString()));
        emit changed();
    });
}

void ControlledDocs::submit(const QString &markdown, const QString &reason)
{
    if (!canSubmit()) return;
    const QByteArray bytes = markdown.toUtf8();
    if (!validReason(reason)) { m_errorCode = QStringLiteral("reason_required"); emit changed(); return; }
    if (bytes.size() > 1024 * 1024 || bytes.contains('\0')) {
        m_errorCode = QStringLiteral("invalid_markdown"); emit changed(); return;
    }
    const auto version = m_document.value(QStringLiteral("current_version")).toObject();
    const QString filename = version.value(QStringLiteral("filename")).toString();
    if (!filename.endsWith(QLatin1String(".md"), Qt::CaseInsensitive)) {
        m_errorCode = QStringLiteral("invalid_markdown"); emit changed(); return;
    }
    m_saving = true;
    m_errorCode.clear(); m_notice.clear();
    const auto isLive = guard();
    emit changed();
    m_backend.upload(m_orgId, {{QStringLiteral("space_id"), m_spaceId}, {QStringLiteral("document_id"), m_documentId},
                      {QStringLiteral("filename"), filename}, {QStringLiteral("content_type"), QStringLiteral("text/markdown")},
                      {QStringLiteral("reason"), reason.trimmed()}}, bytes, isLive,
            [this, isLive](const Client::Reply &reply) {
        if (!isLive()) return;
        const auto review = reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("review"));
        finishMutation(reply, review.isObject() ? QStringLiteral("review_requested") : QStringLiteral("version_published"));
    });
}

void ControlledDocs::decide(const QString &action, const QString &comment)
{
    if (!m_active || busy() || m_review.value(QStringLiteral("status")).toString() != QLatin1String("open")) return;
    if (action != QLatin1String("approve") && action != QLatin1String("reject") && action != QLatin1String("cancel")) return;
    if (action != QLatin1String("cancel") && !canDecide()) return;
    if (comment.toUcs4().size() > 2000 || comment.contains(QChar::Null)) {
        m_errorCode = QStringLiteral("invalid_comment"); emit changed(); return;
    }
    mutation("POST", reviewPath(QLatin1Char('/') + action),
             {{QStringLiteral("candidate_version_id"), m_review.value(QStringLiteral("candidate_version_id"))},
              {QStringLiteral("comment"), comment}}, m_review.value(QStringLiteral("revision")).toInt(),
             QStringLiteral("review_%1").arg(action));
}
}
