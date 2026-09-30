#pragma once

#include "addons/AddOnManager.h"
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;
class ControlledDocs : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QString section READ section WRITE setSection NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool controlled READ controlled NOTIFY changed)
    Q_PROPERTY(bool hasDocument READ hasDocument NOTIFY changed)
    Q_PROPERTY(bool canManageRule READ canManageRule NOTIFY changed)
    Q_PROPERTY(bool canSubmit READ canSubmit NOTIFY changed)
    Q_PROPERTY(bool canDecide READ canDecide NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(QString ruleError READ ruleError NOTIFY changed)
    Q_PROPERTY(QString reviewsError READ reviewsError NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)
    Q_PROPERTY(QVariantMap rule READ rule NOTIFY changed)
    Q_PROPERTY(QVariantMap review READ review NOTIFY changed)
    Q_PROPERTY(QVariantList reviews READ reviews NOTIFY changed)
    Q_PROPERTY(QVariantList members READ members NOTIFY changed)
    Q_PROPERTY(QVariantList grants READ grants NOTIFY changed)
    Q_PROPERTY(bool canAssign READ canAssign NOTIFY changed)
    Q_PROPERTY(QString accessError READ accessError NOTIFY changed)
    Q_PROPERTY(QString diff READ diff NOTIFY changed)
    Q_PROPERTY(QString candidate READ candidate NOTIFY changed)
    Q_PROPERTY(QString source READ source NOTIFY sourceChanged)
    Q_PROPERTY(bool sourceLoaded READ sourceLoaded NOTIFY changed)
    Q_PROPERTY(bool draftStale READ draftStale NOTIFY changed)
    Q_PROPERTY(QVariantMap availability READ availability NOTIFY changed)

public:
    explicit ControlledDocs(Session &session);
    bool active() const { return m_active; }
    QString section() const { return m_section; }
    void setSection(const QString &section);
    bool busy() const { return m_pending > 0 || m_saving; }
    bool controlled() const { return m_document.value(QStringLiteral("controlled_docs_enabled")).toBool(); }
    bool hasDocument() const { return !m_documentId.isEmpty(); }
    bool canManageRule() const { return m_ruleError.isEmpty() && m_ruleRead; }
    bool canSubmit() const;
    bool canDecide() const;
    QString title() const;
    QString errorCode() const { return m_errorCode; }
    QString ruleError() const { return m_ruleError; }
    QString reviewsError() const { return m_reviewsError; }
    QString notice() const { return m_notice; }
    QVariantMap rule() const { return m_rule.toVariantMap(); }
    QVariantMap review() const { return m_review.toVariantMap(); }
    QVariantList reviews() const { return m_reviews.toVariantList(); }
    QVariantList members() const { return m_members.toVariantList(); }
    QVariantList grants() const;
    bool canAssign() const;
    QString accessError() const { return m_accessError; }
    QVariantMap availability() const;
    QString diff() const { return m_diff; }
    QString candidate() const { return m_candidate; }
    QString source() const { return m_source; }
    bool sourceLoaded() const { return m_sourceLoaded; }
    bool draftStale() const;
    void open(const QString &documentId = {}, const QString &section = {});
    /// Whether the screen's command `id` (Session's table) can run now.
    bool allows(QByteArrayView id) const;
    /// Runs `id`, or emits `requested` when the screen must first ask for a
    /// comment, a reason, a member, or a confirmation.
    void perform(QByteArrayView id);
    /// The UTF-8 Markdown in a dropped local file; empty, with an error, when
    /// it is not an .md file Core would accept.
    Q_INVOKABLE QString readDraft(const QUrl &url);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void saveRule(bool active);
    Q_INVOKABLE void removeRule(const QString &reason);
    Q_INVOKABLE void setControlled(bool enabled, const QString &reason = {});
    Q_INVOKABLE void selectReview(const QString &id);
    Q_INVOKABLE void loadPublished();
    Q_INVOKABLE void downloadCandidate();
    Q_INVOKABLE void submit(const QString &markdown, const QString &reason);
    Q_INVOKABLE void decide(const QString &action, const QString &comment);
    Q_INVOKABLE void grantAccess(const QString &membershipId, bool manage);
    Q_INVOKABLE void revokeAccess(const QString &grantId);

signals:
    void changed();
    void sourceChanged();
    void proposalSubmitted();
    void requested(const QString &id);

private:
    bool live(int generation) const;
    AddOnBackend::Live guard() const;
    bool unavailable() const;
    QString documentPath(const QString &suffix = {}) const;
    QString reviewPath(const QString &suffix = {}) const;
    void load();
    void loadReview();
    void mutation(const QByteArray &method, const QString &path, QJsonObject body,
                  int revision, const QString &notice);
    void finishMutation(const Client::Reply &reply, const QString &notice);
    static QJsonArray accessActions(bool manage);
    static bool roleMatches(const QJsonObject &role, bool manage);
    Session &m_session;
    AddOnManager &m_addOns;
    AddOnBackend &m_backend;
    QString m_orgId, m_spaceId, m_documentId, m_membershipId, m_section;
    bool m_active = false, m_saving = false, m_ruleRead = false, m_sourceLoaded = false;
    int m_generation = 0, m_pending = 0, m_reviewGeneration = 0;
    QJsonObject m_document, m_rule, m_review;
    QJsonArray m_reviews;
    QJsonArray m_members, m_roles, m_grants;
    QString m_accessError;
    QString m_errorCode, m_ruleError, m_reviewsError, m_notice, m_diff, m_candidate, m_source, m_sourceVersion;
};
}
