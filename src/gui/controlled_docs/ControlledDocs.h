#pragma once

#include "addons/AddOnManager.h"
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class DocumentView;
class Session;

/// The controlled-documents add-on on the open document. It attaches to the
/// document screen when the document is already managed, or is Markdown in
/// an organization where the add-on is installed or a space where the person
/// holds its managing action, and adds nothing otherwise: whether the document is managed, its reviews, the one opened
/// with its candidate and diff, the decisions on it, and managing or
/// unmanaging the document. Core decides whether the document may be
/// managed: the add-on active in the space and the action held there. Saving an edit of a managed document is the
/// document screen's own upload, which Core turns into a review; each save
/// opens its own. The author updates a review that fell behind a later
/// publication, in one step or by resolving its conflicts in the editor.
class ControlledDocs : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool controlled READ controlled NOTIFY changed)
    Q_PROPERTY(bool canReject READ canReject NOTIFY changed)
    Q_PROPERTY(bool canApprove READ canApprove NOTIFY changed)
    Q_PROPERTY(bool authored READ authored NOTIFY changed)
    Q_PROPERTY(bool approved READ approved NOTIFY changed)
    Q_PROPERTY(bool authorMayApprove READ authorMayApprove NOTIFY changed)
    Q_PROPERTY(int approvals READ approvals NOTIFY changed)
    Q_PROPERTY(int requiredApprovals READ requiredApprovals NOTIFY changed)
    Q_PROPERTY(int openReviews READ openReviews NOTIFY changed)
    Q_PROPERTY(QString proposalReviewId READ proposalReviewId NOTIFY changed)
    Q_PROPERTY(bool pinsLinks READ pinsLinks NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString reviewsError READ reviewsError NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QString selectedReviewId READ selectedReviewId NOTIFY changed)
    Q_PROPERTY(QVariantMap review READ review NOTIFY changed)
    Q_PROPERTY(QVariantList reviews READ reviews NOTIFY changed)
    Q_PROPERTY(QVariantList members READ members NOTIFY changed)
    Q_PROPERTY(QString diff READ diff NOTIFY changed)
    Q_PROPERTY(QString candidate READ candidate NOTIFY changed)
    Q_PROPERTY(QVariantMap diffReferences READ diffReferences NOTIFY changed)

public:
    ControlledDocs(Session &session, DocumentView &view);
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0 || m_reviewPending > 0 || m_saving; }
    bool controlled() const;
    /// Whether this person may reject the opened review: never its author.
    bool canReject() const;
    /// Whether this person may approve the opened review: it is `clean`, as
    /// Core approves only a review based on the published version, they
    /// have not approved its candidate yet, and they did not write it
    /// unless the review's settings let authors approve.
    bool canApprove() const;
    /// Whether this person wrote the opened review.
    bool authored() const;
    /// Whether this person already approved the opened review's candidate.
    bool approved() const;
    bool authorMayApprove() const;
    /// The approvals of the opened review's candidate, and how many
    /// distinct approvers publish it.
    int approvals() const;
    int requiredApprovals() const;
    int openReviews() const;
    /// The review whose proposal the editor holds, empty for a new proposal.
    QString proposalReviewId() const { return m_draftReviewId; }
    /// What a save of the editor declares to Core beside the text: the
    /// published version it was edited from and, while the editor holds a
    /// review's proposal, that review. Empty unless the document is managed.
    Q_INVOKABLE QVariantMap proposal() const;
    /// The editor no longer holds a review's proposal.
    Q_INVOKABLE void clearProposal();
    /// Links in this managed document must pin a version: the settings in
    /// effect require it, so Core refuses links that follow the current one.
    bool pinsLinks() const;
    QString errorCode() const { return m_errorCode; }
    QString reviewsError() const { return m_reviewsError; }
    QString notice() const { return m_notice; }
    /// The review the list's cursor is on.
    QString selectedReviewId() const { return m_selectedId; }
    /// The review opened from the list, empty while the list shows.
    QVariantMap review() const { return m_review.toVariantMap(); }
    QVariantList reviews() const { return m_reviews.toVariantList(); }
    /// The organization's members, each with the `label` that names them.
    QVariantList members() const;
    QString diff() const { return m_diff; }
    QString candidate() const { return m_candidate; }
    /// The review's reference changes: `{added, removed, changed}`.
    QVariantMap diffReferences() const { return m_diffReferences.toVariantMap(); }
    /// Whether the screen's command `id` (Session's table) can run now.
    bool allows(QByteArrayView id) const;
    /// Runs `id`, or emits `requested` when the screen must first ask for a
    /// comment, a reason, or a confirmation.
    void perform(QByteArrayView id);
    /// Runs `id` once the document being opened is loaded: how the explorer
    /// manages or unmanages a document it does not show.
    void performWhenLoaded(QByteArrayView id);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setControlled(bool enabled, const QString &reason = {});
    Q_INVOKABLE void selectReview(const QString &id);
    Q_INVOKABLE void downloadCandidate();
    Q_INVOKABLE void decide(const QString &action, const QString &comment);

signals:
    void changed();
    void requested(const QString &id);
    /// The opened review's proposal merged over the published version, for
    /// the editor; `conflicts` blocks are marked in it.
    void proposalReady(const QString &text, int conflicts);

private:
    /// The add-on in the organization, as `AddOnManager::state` reads it.
    QVariantMap availability() const;
    bool live(int generation) const;
    AddOnBackend::Live guard() const;
    bool unavailable() const;
    bool installed() const;
    /// The review is open to this person's decision, author or not.
    bool reviewing() const;
    QVariant reviewSetting(const QString &key) const;
    void attach();
    void detach();
    QString documentPath(const QString &suffix = {}) const;
    QString reviewPath(const QString &suffix = {}) const;
    void load();
    /// One of load()'s replies arrived; the last runs what waited for it.
    void settle();
    void openReview();
    void closeReview();
    void loadReview();
    void mutation(const QByteArray &method, const QString &path, QJsonObject body,
                  int revision, const QString &notice);
    /// Merges the opened review over the published version; a clean merge
    /// becomes its candidate when `submit`, else the editor gets it.
    void merge(bool submit);
    void resubmit(const QString &text, const QString &baseVersionId);
    bool mergeState(const char *state) const;
    void reloadAll();
    Session &m_session;
    DocumentView &m_view;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId, m_spaceId, m_documentId, m_membershipId, m_selectedId;
    QString m_draftReviewId, m_draftBaseId;
    bool m_active = false, m_saving = false;
    int m_generation = 0, m_pending = 0, m_reviewGeneration = 0, m_reviewPending = 0;
    /// The space's activation, read where this person may turn it on.
    QJsonObject m_rule, m_review, m_diffReferences;
    QJsonArray m_reviews, m_members;
    QString m_errorCode, m_reviewsError, m_notice, m_diff, m_candidate;
    QByteArray m_after;
};
}
