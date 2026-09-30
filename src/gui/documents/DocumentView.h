#pragma once

#include "addons/AddOnBackend.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {
class Session;

/// The document screen: one document of the open space, any type. Shows the
/// selected published version (the current one by default) when its type
/// has a preview, lists the versions and the documents it links or that link
/// it, and saves an edited Markdown or text document as a new version.
/// Add-ons extend it; it knows none of them.
class DocumentView : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString documentId READ documentId NOTIFY changed)
    Q_PROPERTY(QString title READ title NOTIFY changed)
    Q_PROPERTY(QStringList place READ place NOTIFY changed)
    Q_PROPERTY(QVariantMap document READ document NOTIFY changed)
    Q_PROPERTY(QVariantList versions READ versions NOTIFY changed)
    Q_PROPERTY(QVariantMap version READ version NOTIFY changed)
    Q_PROPERTY(bool latest READ latest NOTIFY changed)
    Q_PROPERTY(QString kind READ kind NOTIFY changed)
    Q_PROPERTY(QString text READ text NOTIFY textChanged)
    Q_PROPERTY(bool textLoaded READ textLoaded NOTIFY changed)
    Q_PROPERTY(bool editable READ editable NOTIFY changed)
    Q_PROPERTY(QVariantList incoming READ incoming NOTIFY changed)
    Q_PROPERTY(QVariantList outgoing READ outgoing NOTIFY changed)
    Q_PROPERTY(int hiddenCount READ hiddenCount NOTIFY changed)
    Q_PROPERTY(bool relatedLoaded READ relatedLoaded NOTIFY changed)
    Q_PROPERTY(bool incomingMore READ incomingMore NOTIFY changed)
    Q_PROPERTY(bool outgoingMore READ outgoingMore NOTIFY changed)
    Q_PROPERTY(QString tab READ tab WRITE setTab NOTIFY changed)
    Q_PROPERTY(QString errorCode READ errorCode NOTIFY changed)
    Q_PROPERTY(int errorIndex READ errorIndex NOTIFY changed)
    Q_PROPERTY(QString notice READ notice NOTIFY changed)

public:
    DocumentView(Session &session, AddOnBackend &backend);
    bool active() const { return m_active; }
    bool busy() const { return m_pending > 0; }
    QString documentId() const { return m_documentId; }
    QString title() const;
    /// Where the document is: its space's name, then its folders.
    QStringList place() const;
    QVariantMap document() const { return m_document.toVariantMap(); }
    QVariantList versions() const { return m_versions.toVariantList(); }
    QVariantMap version() const { return m_version.toVariantMap(); }
    QString versionId() const;
    bool latest() const;
    /// How the selected version previews: "markdown", "image", "text", or
    /// "none" for every other file.
    QString kind() const;
    QString text() const { return m_text; }
    bool textLoaded() const { return m_textLoaded; }
    bool editable() const;
    /// The active documents whose current version links this one, as Core's
    /// incoming references; readable sources only.
    QVariantList incoming() const { return m_incoming.toVariantList(); }
    /// What the current version links, in order, each with its `target`
    /// resolved now (`state` "ok", "broken", "trashed", "purged", "forbidden").
    QVariantList outgoing() const { return m_outgoing.toVariantList(); }
    /// Sources linking this document that the user may not read.
    int hiddenCount() const { return m_hiddenCount; }
    bool relatedLoaded() const { return m_relatedLoaded; }
    bool incomingMore() const { return !m_incomingCursor.isEmpty(); }
    bool outgoingMore() const { return !m_outgoingCursor.isEmpty(); }
    QString tab() const { return m_tab; }
    void setTab(const QString &tab);
    QString errorCode() const { return m_errorCode; }
    int errorIndex() const { return m_errorIndex; }
    QString notice() const { return m_notice; }

    void open(const QString &documentId);
    Q_INVOKABLE void close();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectVersion(const QString &versionId);
    /// Lists the next page of related documents in `direction`, "incoming"
    /// or "outgoing".
    Q_INVOKABLE void loadMoreRelated(const QString &direction);
    /// Publishes `text` as the document's next version, with the files it
    /// links (its `/` links too unless `paths` is false) and an optional
    /// `reason`. A managed document's `proposal` names the published version
    /// the text was edited from (`base_version_id`) and, to update a review,
    /// that review (`review_id`).
    Q_INVOKABLE void save(const QString &text, const QString &reason, bool paths = true,
                          const QVariantMap &proposal = {});
    /// The UTF-8 Markdown in a dropped local .md file; empty, with an error,
    /// when it is not a file Core would take.
    Q_INVOKABLE QString readDraft(const QUrl &url);
    /// Whether the screen's command `id` (Session's table) can run now.
    bool allows(QByteArrayView id) const;
    /// Runs `id`, or emits `requested` when the screen must ask first.
    void perform(QByteArrayView id);
    /// A tab an add-on adds to the screen, and whether it applies now.
    void setExtraTab(const QString &tab, bool shown);

signals:
    void changed();
    void textChanged();
    void opened(const QString &documentId);
    void closed();
    /// A new version was published, or `reviewId` was opened for it.
    void saved(const QString &reviewId);
    void requested(const QString &id);

private:
    QString documentPath(const QString &suffix = {}) const;
    bool live(int generation) const { return m_active && generation == m_generation; }
    void load();
    void loadText();
    void loadRelated(const QString &direction = {});
    void clearRelated();
    void fail(const QString &code, int index = -1);

    Session &m_session;
    AddOnBackend &m_backend;
    bool m_active = false, m_textLoaded = false, m_relatedAsked = false, m_relatedLoaded = false;
    int m_generation = 0, m_pending = 0, m_errorIndex = -1, m_hiddenCount = 0;
    QString m_orgId, m_spaceId, m_documentId, m_tab, m_text, m_errorCode, m_notice;
    QString m_incomingCursor, m_outgoingCursor;
    QJsonObject m_document, m_version;
    QJsonArray m_versions, m_incoming, m_outgoing;
    QStringList m_extraTabs;
};
}
