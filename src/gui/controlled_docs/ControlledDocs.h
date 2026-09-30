#pragma once

#include "addons/AddOnManager.h"
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class DocumentView;
class Session;

/// The controlled-documents add-on on the open document. It attaches to the
/// document screen when the document is already managed, or is Markdown in
/// a space where the add-on is installed, and adds nothing otherwise: whether the document is
/// managed, its reviews, the one opened with its candidate and diff, the
/// decisions on it, and managing or unmanaging the document. Saving an edit of a managed document is the
/// document screen's own upload, which Core turns into a review.
class ControlledDocs : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool controlled READ controlled NOTIFY changed)
    Q_PROPERTY(bool canDecide READ canDecide NOTIFY changed)
    Q_PROPERTY(bool reviewOpen READ reviewOpen NOTIFY changed)
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
    Q_PROPERTY(QVariantMap availability READ availability NOTIFY changed)

public:
    ControlledDocs(Session &session, DocumentView &view);
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0 || m_reviewPending > 0 || m_saving; }
    bool controlled() const;
    bool canDecide() const;
    bool reviewOpen() const;
    /// Links in this managed document must pin a version: the space rule
    /// requires it, so Core refuses links that follow the current one.
    bool pinsLinks() const;
    QString errorCode() const { return m_errorCode; }
    QString reviewsError() const { return m_reviewsError; }
    QString notice() const { return m_notice; }
    /// The review the list's cursor is on.
    QString selectedReviewId() const { return m_selectedId; }
    /// The review opened from the list, empty while the list shows.
    QVariantMap review() const { return m_review.toVariantMap(); }
    QVariantList reviews() const { return m_reviews.toVariantList(); }
    QVariantList members() const { return m_members.toVariantList(); }
    QString diff() const { return m_diff; }
    QString candidate() const { return m_candidate; }
    /// The review's reference changes: `{added, removed, changed}`.
    QVariantMap diffReferences() const { return m_diffReferences.toVariantMap(); }
    QVariantMap availability() const;
    /// Whether the screen's command `id` (Session's table) can run now.
    bool allows(QByteArrayView id) const;
    /// Runs `id`, or emits `requested` when the screen must first ask for a
    /// comment, a reason, or a confirmation.
    void perform(QByteArrayView id);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setControlled(bool enabled, const QString &reason = {});
    Q_INVOKABLE void selectReview(const QString &id);
    Q_INVOKABLE void downloadCandidate();
    Q_INVOKABLE void decide(const QString &action, const QString &comment);

signals:
    void changed();
    void requested(const QString &id);

private:
    bool live(int generation) const;
    AddOnBackend::Live guard() const;
    bool unavailable() const;
    bool installed() const;
    void attach();
    void detach();
    QString documentPath(const QString &suffix = {}) const;
    QString reviewPath(const QString &suffix = {}) const;
    void load();
    void openReview();
    void closeReview();
    void loadReview();
    void mutation(const QByteArray &method, const QString &path, QJsonObject body,
                  int revision, const QString &notice);
    Session &m_session;
    DocumentView &m_view;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId, m_spaceId, m_documentId, m_membershipId, m_selectedId;
    bool m_active = false, m_saving = false, m_ruleRead = false;
    int m_generation = 0, m_pending = 0, m_reviewGeneration = 0, m_reviewPending = 0;
    QJsonObject m_rule, m_review, m_diffReferences;
    QJsonArray m_reviews, m_members;
    QString m_errorCode, m_reviewsError, m_notice, m_diff, m_candidate;
};
}
