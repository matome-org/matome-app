#include "ControlledDocs.h"
#include "Session.h"
#include "JsonList.h"
#include "documents/DocumentView.h"
#include "references/Assets.h"
#include <QPointer>
#include <QStringDecoder>
#include <QUrl>

#include <algorithm>

namespace matome {
ControlledDocs::ControlledDocs(Session &session, DocumentView &view)
    : QObject(&session), m_session(session), m_view(view), m_addOns(*session.addOns()), m_backend(m_addOns.backend())
{
    connect(&view, &DocumentView::opened, this, &ControlledDocs::attach);
    connect(&view, &DocumentView::closed, this, &ControlledDocs::detach);
    // A save that opens or updates a review selects it, so Open review shows it.
    connect(&view, &DocumentView::saved, this, [this](const QString &reviewId) {
        if (m_active && !reviewId.isEmpty()) m_selectedId = reviewId;
        clearProposal();
        refresh();
    });
    // The editor went back to the published text: it holds no proposal now.
    connect(&view, &DocumentView::textChanged, this, &ControlledDocs::clearProposal);
    // The add-on list and the document's own state arrive after the screen
    // opens; either may be what brings the add-on in.
    connect(&view, &DocumentView::changed, this, [this] {
        attach();
        if (m_active) m_view.setExtraTab(QStringLiteral("reviews"), controlled());
        if (!m_review.isEmpty() && m_view.tab() != QLatin1String("reviews")) closeReview();
        emit changed();
    });
    connect(&m_addOns, &AddOnManager::changed, this, [this] {
        attach();
        emit changed();
    });
}

bool ControlledDocs::live(int generation) const { return m_active && generation == m_generation; }
AddOnBackend::Live ControlledDocs::guard() const
{
    const QPointer<const ControlledDocs> self(this);
    const int generation = m_generation;
    return [self, generation] { return self && self->live(generation); };
}
QVariantMap ControlledDocs::availability() const
{
    return m_addOns.state(QStringLiteral("controlled_docs"), m_session.currentSpaceId());
}
bool ControlledDocs::unavailable() const
{
    const auto state = availability();
    return state.value(QStringLiteral("known")).toBool() && !state.value(QStringLiteral("available")).toBool();
}
bool ControlledDocs::installed() const
{
    return !availability().value(QStringLiteral("status")).toString().isEmpty();
}

bool ControlledDocs::controlled() const
{
    return m_view.document().value(QStringLiteral("controlled_docs_enabled")).toBool();
}

bool ControlledDocs::reviewing() const
{
    return m_active && !busy() && !unavailable()
            && m_review.value(QStringLiteral("status")).toString() == QLatin1String("open")
            && !m_membershipId.isEmpty();
}

bool ControlledDocs::canReject() const
{
    return reviewing() && !authored();
}

// A review keeps the settings in effect when it was submitted; Core fills
// those declared since with their defaults.
QVariant ControlledDocs::reviewSetting(const QString &key) const
{
    return m_review.value(QStringLiteral("settings")).toObject().value(key).toVariant();
}

int ControlledDocs::requiredApprovals() const
{
    return std::max(1, reviewSetting(QStringLiteral("required_approvals")).toInt());
}

int ControlledDocs::approvals() const
{
    return int(m_review.value(QStringLiteral("approvals")).toArray().size());
}

bool ControlledDocs::approved() const
{
    if (m_membershipId.isEmpty()) return false;
    const auto rows = m_review.value(QStringLiteral("approvals")).toArray();
    return std::any_of(rows.begin(), rows.end(), [this](const QJsonValue &row) {
        return jsonId(row.toObject().value(QStringLiteral("approving_membership_id"))) == m_membershipId;
    });
}

bool ControlledDocs::authorMayApprove() const
{
    return reviewSetting(QStringLiteral("allow_author_approval")).toBool();
}

// A review Core recorded before merge states reads as `clean`, as Core
// defaults it.
bool ControlledDocs::mergeState(const char *state) const
{
    const QString value = m_review.value(QStringLiteral("merge_state")).toString(QStringLiteral("clean"));
    return value == QLatin1String(state);
}

bool ControlledDocs::canApprove() const
{
    return reviewing() && mergeState("clean") && !approved() && (!authored() || authorMayApprove());
}

bool ControlledDocs::authored() const
{
    return m_active && !m_membershipId.isEmpty() && !m_review.isEmpty()
            && m_review.value(QStringLiteral("author_membership_id")).toString() == m_membershipId;
}

// The rule's effective settings are readable by managers only. Anyone else
// pins when an open review's settings or the organization's require it:
// a pinned link is always accepted, a following one only when allowed.
bool ControlledDocs::pinsLinks() const
{
    if (!m_active || !controlled()) return false;
    const QString key = QStringLiteral("require_version_references");
    const auto effective = m_rule.value(QStringLiteral("effective_settings")).toObject();
    if (effective.contains(key)) return effective.value(key).toBool();
    const bool reviewed = std::any_of(m_reviews.begin(), m_reviews.end(), [&key](const QJsonValue &value) {
        const auto review = value.toObject();
        return review.value(QStringLiteral("status")).toString() == QLatin1String("open")
                && review.value(QStringLiteral("settings")).toObject().value(key).toBool();
    });
    return reviewed || m_addOns.product(QStringLiteral("controlled_docs")).value(QStringLiteral("installation")).toObject()
            .value(QStringLiteral("settings")).toObject().value(key).toBool();
}

int ControlledDocs::openReviews() const
{
    return int(std::count_if(m_reviews.begin(), m_reviews.end(), [](const QJsonValue &value) {
        return value.toObject().value(QStringLiteral("status")).toString() == QLatin1String("open");
    }));
}

QVariantMap ControlledDocs::proposal() const
{
    if (!m_active || !controlled())
        return {};
    if (!m_draftReviewId.isEmpty())
        return {{QStringLiteral("review_id"), m_draftReviewId}, {QStringLiteral("base_version_id"), m_draftBaseId}};
    return {{QStringLiteral("base_version_id"), m_view.versionId()}};
}

void ControlledDocs::clearProposal()
{
    if (m_draftReviewId.isEmpty())
        return;
    m_draftReviewId.clear();
    m_draftBaseId.clear();
    emit changed();
}

QString ControlledDocs::documentPath(const QString &suffix) const
{
    return contentPath(m_orgId, m_spaceId, QStringLiteral("documents/%1%2").arg(m_documentId, suffix));
}
QString ControlledDocs::reviewPath(const QString &suffix) const
{
    return orgPath(m_orgId, QStringLiteral("reviews/%1%2").arg(m_review.value(QStringLiteral("id")).toString(), suffix));
}

void ControlledDocs::attach()
{
    // Only Markdown can be managed: other files never bring the add-on in.
    if (m_active || !m_view.active()
            || !(controlled() || (installed() && m_view.kind() == QLatin1String("markdown")))) return;
    m_active = true;
    m_orgId = m_session.currentOrgId();
    m_spaceId = m_session.currentSpaceId();
    m_documentId = m_view.documentId();
    m_view.setExtraTab(QStringLiteral("reviews"), controlled());
    load();
}

void ControlledDocs::detach()
{
    if (!m_active) return;
    ++m_generation;
    ++m_reviewGeneration;
    m_active = m_saving = m_ruleRead = false;
    m_pending = m_reviewPending = 0;
    m_orgId.clear(); m_spaceId.clear(); m_documentId.clear(); m_membershipId.clear(); m_selectedId.clear();
    m_draftReviewId.clear(); m_draftBaseId.clear();
    m_rule = m_review = m_diffReferences = {};
    m_reviews = m_members = {};
    m_errorCode.clear(); m_reviewsError.clear(); m_notice.clear();
    m_diff.clear(); m_candidate.clear();
    emit changed();
}

bool ControlledDocs::allows(QByteArrayView id) const
{
    if (!m_active) return false;
    const bool idle = !busy();
    if (id == "open-review")
        return idle && m_review.isEmpty() && !m_selectedId.isEmpty() && m_view.tab() == QLatin1String("reviews");
    if (id == "close-review") return !m_review.isEmpty();
    if (id == "download-candidate") return idle && !m_review.isEmpty();
    const bool open = m_review.value(QStringLiteral("status")).toString() == QLatin1String("open");
    if (id == "approve-review") return canApprove();
    if (id == "reject-review") return canReject();
    if (id == "cancel-review") return idle && open;
    // The author's own review: bring it onto the published version, in one
    // step when it merges cleanly, or edit its proposal in the editor.
    const bool mine = idle && open && authored() && !unavailable();
    if (id == "update-review") return mine && mergeState("behind");
    if (id == "resolve-conflicts") return mine && m_view.editable() && mergeState("dirty");
    if (id == "edit-proposal") return mine && m_view.editable() && !mergeState("dirty");
    if (id == "manage-document")
        return idle && !controlled() && !unavailable() && m_rule.value(QStringLiteral("active")).toBool()
                && m_view.kind() == QLatin1String("markdown");
    if (id == "unmanage-document") return idle && controlled() && m_ruleRead;
    return false;
}

void ControlledDocs::perform(QByteArrayView id)
{
    if (!allows(id)) return;
    if (id == "open-review") openReview();
    else if (id == "close-review") closeReview();
    else if (id == "download-candidate") downloadCandidate();
    else if (id == "manage-document") setControlled(true);
    else if (id == "update-review") merge(true);
    else if (id == "resolve-conflicts" || id == "edit-proposal") merge(false);
    else emit requested(QString::fromLatin1(id));
}

void ControlledDocs::refresh()
{
    if (!m_active || busy()) return;
    m_addOns.refresh();
    load();
}

// The space rule (readable by managers only: it decides whether this
// person may manage the document), the reviews, open ones first, and the
// members who wrote or decide them. The opened review stays open with its
// new state, and loads again when its author replaced its candidate.
void ControlledDocs::load()
{
    const int generation = ++m_generation;
    m_pending = 3;
    m_ruleRead = false;
    m_errorCode.clear(); m_reviewsError.clear();
    emit changed();
    const QPointer<ControlledDocs> self(this);
    const auto live = [self, generation] { return self && self->live(generation); };
    m_backend.request("GET", contentPath(m_orgId, m_spaceId, QStringLiteral("controlled-docs-rule")), {}, {},
            [this, live](const Client::Reply &reply) {
        if (!live()) return;
        m_rule = reply.ok ? reply.json.value(QStringLiteral("data")).toObject() : QJsonObject();
        m_ruleRead = reply.ok || reply.status == 404;
        --m_pending;
        emit changed();
    });
    m_backend.list(documentPath(QStringLiteral("/reviews")), QStringLiteral("reviews"), live,
            [this, live](const Client::Reply &reply, const QJsonArray &rows) {
        if (!live()) return;
        QList<QJsonObject> listed;
        for (const auto &row : rows) listed.append(row.toObject());
        std::stable_partition(listed.begin(), listed.end(), [](const QJsonObject &review) {
            return review.value(QStringLiteral("status")).toString() == QLatin1String("open");
        });
        m_reviews = {};
        if (reply.ok)
            for (const auto &review : std::as_const(listed)) m_reviews.append(review);
        if (!reply.ok) m_reviewsError = failCode(reply);
        const auto find = [this](const QString &id) {
            for (const auto &value : std::as_const(m_reviews))
                if (value.toObject().value(QStringLiteral("id")).toString() == id) return value.toObject();
            return QJsonObject();
        };
        if (find(m_selectedId).isEmpty())
            m_selectedId = m_reviews.isEmpty() ? QString() : m_reviews.first().toObject().value(QStringLiteral("id")).toString();
        if (!m_review.isEmpty()) {
            const QJsonObject open = find(m_review.value(QStringLiteral("id")).toString());
            const auto candidate = [](const QJsonObject &review) {
                return review.value(QStringLiteral("candidate_version_id")).toString();
            };
            if (open.isEmpty()) closeReview();
            else if (candidate(open) != candidate(m_review)) { m_review = open; loadReview(); }
            else m_review = open;
        }
        --m_pending;
        emit changed();
    });
    m_backend.list(orgPath(m_orgId, QStringLiteral("members")), QStringLiteral("members"), live,
            [this, live](const Client::Reply &reply, const QJsonArray &rows) {
        if (!live()) return;
        m_members = reply.ok ? rows : QJsonArray();
        m_membershipId.clear();
        for (const auto &value : std::as_const(m_members)) {
            const auto row = value.toObject();
            if (row.value(QStringLiteral("email")).toString().compare(m_session.email(), Qt::CaseInsensitive) == 0)
                m_membershipId = jsonId(row.value(QStringLiteral("id")));
        }
        --m_pending;
        emit changed();
    });
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
        if (!isLive()) return;
        m_saving = false;
        // A conflict or a missing revision also refreshes, keeping the
        // server's explanation for the rejected action.
        if (reply.ok || reply.status == 409 || reply.status == 428) reloadAll();
        // An approval short of the required count leaves the review open.
        const bool pending = notice == QLatin1String("review_approve")
                && reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("status")).toString() == QLatin1String("open");
        if (reply.ok) m_notice = pending ? QStringLiteral("review_approval_added") : notice;
        else m_errorCode = failCode(reply);
        emit changed();
    });
}

void ControlledDocs::reloadAll()
{
    m_addOns.refresh();
    m_session.documents()->reload();
    m_view.refresh();
    load();
}

// Core merges the review over the published version: the review's own
// candidate while it is `clean`, else a three-way line merge that marks
// each conflict with `<<<<<<< published`, `=======` and `>>>>>>> review`.
void ControlledDocs::merge(bool submit)
{
    if (!m_active || busy() || m_review.isEmpty()) return;
    m_reviewPending = 1;
    m_errorCode.clear();
    m_notice.clear();
    const auto isLive = guard();
    const int reviewGeneration = m_reviewGeneration;
    const QString reviewId = m_review.value(QStringLiteral("id")).toString();
    emit changed();
    m_backend.request("GET", reviewPath(QStringLiteral("/merge")), {}, {},
            [this, isLive, reviewGeneration, reviewId, submit](const Client::Reply &reply) {
        if (!isLive() || reviewGeneration != m_reviewGeneration) return;
        m_reviewPending = 0;
        const auto data = reply.json.value(QStringLiteral("data")).toObject();
        const QString target = jsonId(data.value(QStringLiteral("target_version_id")));
        const int conflicts = data.value(QStringLiteral("conflicts")).toInt();
        if (!reply.ok || target.isEmpty()) {
            if (reply.status == 409) reloadAll();
            m_errorCode = reply.ok ? QStringLiteral("candidate_unavailable") : failCode(reply);
            emit changed();
            return;
        }
        const QString content = data.value(QStringLiteral("content")).toString();
        if (submit && conflicts == 0) {
            resubmit(content, target);
            return;
        }
        m_draftReviewId = reviewId;
        m_draftBaseId = target;
        emit changed();
        emit proposalReady(content, conflicts);
    });
}

// Replaces the opened review's candidate with `text`, now based on
// `baseVersionId`; the review keeps its id and summary.
void ControlledDocs::resubmit(const QString &text, const QString &baseVersionId)
{
    const QJsonObject version = QJsonObject::fromVariantMap(m_view.version());
    const QJsonObject descriptor{
        {QStringLiteral("space_id"), m_spaceId}, {QStringLiteral("document_id"), m_documentId},
        {QStringLiteral("filename"), version.value(QStringLiteral("filename"))},
        {QStringLiteral("content_type"), version.value(QStringLiteral("content_type"))},
        {QStringLiteral("reason"), m_review.value(QStringLiteral("reason"))},
        {QStringLiteral("review_id"), m_review.value(QStringLiteral("id"))},
        {QStringLiteral("base_version_id"), baseVersionId},
        {QStringLiteral("references"), Assets::references(text, !pinsLinks())}};
    m_saving = true;
    const auto isLive = guard();
    const QString reviewId = m_review.value(QStringLiteral("id")).toString();
    emit changed();
    m_backend.upload(m_orgId, descriptor, text.toUtf8(), isLive, [this, reviewId](const Client::Reply &reply) {
        m_saving = false;
        if (reply.ok) m_selectedId = reviewId;
        if (reply.ok || reply.status == 409) reloadAll();
        if (reply.ok) m_notice = QStringLiteral("review_updated");
        else m_errorCode = failCode(reply);
        emit changed();
    });
}

void ControlledDocs::setControlled(bool enabled, const QString &reason)
{
    if (!m_active || (enabled && unavailable())) return;
    if (!enabled && !validReason(reason)) { m_errorCode = QStringLiteral("reason_required"); emit changed(); return; }
    QString path = documentPath(QStringLiteral("/controlled-docs"));
    if (!enabled) path += QStringLiteral("?reason=") + QString::fromLatin1(QUrl::toPercentEncoding(reason.trimmed()));
    mutation(enabled ? "PUT" : "DELETE", path, {}, m_view.document().value(QStringLiteral("revision")).toInt(),
             enabled ? QStringLiteral("control_enabled") : QStringLiteral("control_removed"));
}

void ControlledDocs::selectReview(const QString &id)
{
    if (!m_active || id == m_selectedId) return;
    m_selectedId = id;
    emit changed();
}

void ControlledDocs::openReview()
{
    for (const auto &value : std::as_const(m_reviews))
        if (value.toObject().value(QStringLiteral("id")).toString() == m_selectedId) m_review = value.toObject();
    if (!m_review.isEmpty()) loadReview();
}

void ControlledDocs::closeReview()
{
    ++m_reviewGeneration;
    m_review = m_diffReferences = {};
    m_diff.clear();
    m_candidate.clear();
    m_errorCode.clear();
    m_reviewPending = 0;
    emit changed();
}

// The selected review's diff and its candidate Markdown, fetched together.
void ControlledDocs::loadReview()
{
    m_reviewPending = 2;
    m_errorCode.clear();
    const auto isLive = guard();
    const int reviewGeneration = m_reviewGeneration;
    const auto current = [this, isLive, reviewGeneration] { return isLive() && reviewGeneration == m_reviewGeneration; };
    emit changed();
    m_backend.request("GET", reviewPath(QStringLiteral("/diff")), {}, {}, [this, current](const Client::Reply &reply) {
        if (!current()) return;
        --m_reviewPending;
        const auto data = reply.json.value(QStringLiteral("data")).toObject();
        if (reply.ok) {
            m_diff = data.value(QStringLiteral("diff")).toString();
            m_diffReferences = data.value(QStringLiteral("references")).toObject();
        } else m_errorCode = failCode(reply);
        emit changed();
    });
    m_backend.request("GET", reviewPath(QStringLiteral("/candidate/download")), {}, {}, [this, current](const Client::Reply &reply) {
        if (!current()) return;
        if (!reply.ok) { --m_reviewPending; m_errorCode = failCode(reply); emit changed(); return; }
        const QUrl url(reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString());
        m_backend.getFile(url, [this, current](const Client::Reply &file) {
            if (!current()) return;
            --m_reviewPending;
            QStringDecoder utf8(QStringDecoder::Utf8);
            const QString text = utf8(file.bytes);
            if (file.ok && file.bytes.size() <= 1024 * 1024 && !file.bytes.contains('\0') && !utf8.hasError())
                m_candidate = text;
            else m_errorCode = file.ok ? QStringLiteral("candidate_unavailable") : failCode(file);
            emit changed();
        });
    });
}

void ControlledDocs::downloadCandidate()
{
    if (!m_active || busy() || m_review.isEmpty()) return;
    m_reviewPending = 1;
    m_errorCode.clear();
    const auto isLive = guard();
    const int reviewGeneration = m_reviewGeneration;
    emit changed();
    m_backend.request("GET", reviewPath(QStringLiteral("/candidate/download")), {}, {},
            [this, isLive, reviewGeneration](const Client::Reply &reply) {
        if (!isLive() || reviewGeneration != m_reviewGeneration) return;
        m_reviewPending = 0;
        if (!reply.ok) m_errorCode = failCode(reply);
        else emit m_session.downloadReady(QUrl(reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString()));
        emit changed();
    });
}

void ControlledDocs::decide(const QString &action, const QString &comment)
{
    if (!m_active || busy() || m_review.value(QStringLiteral("status")).toString() != QLatin1String("open")) return;
    if (action != QLatin1String("approve") && action != QLatin1String("reject") && action != QLatin1String("cancel")) return;
    if (action == QLatin1String("approve") ? !canApprove() : action == QLatin1String("reject") && !canReject()) return;
    if (comment.toUcs4().size() > 2000 || comment.contains(QChar::Null)) {
        m_errorCode = QStringLiteral("invalid_comment"); emit changed(); return;
    }
    mutation("POST", reviewPath(QLatin1Char('/') + action),
             {{QStringLiteral("candidate_version_id"), m_review.value(QStringLiteral("candidate_version_id"))},
              {QStringLiteral("comment"), comment}}, m_review.value(QStringLiteral("revision")).toInt(),
             QStringLiteral("review_%1").arg(action));
}
}
