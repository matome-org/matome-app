#pragma once

#include "addons/AddOnBackend.h"

#include <QHash>
#include <QJsonArray>
#include <QList>
#include <QQueue>
#include <QUrl>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include <functional>

namespace matome {
class Session;

/// Images linked from Markdown. Uploads pasted or dropped images as ordinary
/// documents into the space's `assets` folder and answers the version
/// reference to write; signs and downloads the images a rendered version
/// pins, batched per version and cached by version id (a version never
/// changes).
class Assets : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool uploading READ uploading NOTIFY changed)

public:
    /// One image of a rendered Markdown version.
    struct Target {
        QString orgId;
        QString spaceId;
        QString viaVersionId;
        QString documentId;
        QString versionId;
    };
    using Fetched = std::function<void(const QByteArray &bytes, const QString &error)>;

    Assets(Session &session, AddOnBackend &backend);
    bool uploading() const { return !m_uploads.isEmpty(); }

    /// The folder every pasted image goes to, at the root of the space.
    static QString folderName() { return QStringLiteral("assets"); }
    /// Queues image bytes for the current space; `queued` announces it.
    Q_INVOKABLE void uploadImage(const QString &name, const QByteArray &bytes);
    /// Queues the images among local files (a drop or the picker).
    Q_INVOKABLE void uploadUrls(const QList<QUrl> &urls);
    /// Opens the platform's picker for images to upload.
    Q_INVOKABLE void pickImages();
    /// Drops queued uploads and cached images (sign-out, another space).
    void clear();
    void fetch(const Target &target, Fetched done);

    /// The `version` references `markdown` links, in order and once each,
    /// as `POST /uploads` declares them.
    static QJsonArray references(const QString &markdown);
    /// `markdown` ready for a TextEdit: pinned images come from the image
    /// provider no wider than `width`, signed through `viaVersionId`; other
    /// remote images become a line naming them unless `external`.
    Q_INVOKABLE QString render(const QString &markdown, const QString &orgId, const QString &spaceId,
                               const QString &viaVersionId, int width, bool external) const;
    /// The image provider source of one pinned image, signed through
    /// `viaVersionId` (empty: a draft no version pins) and no wider than `width`.
    Q_INVOKABLE static QString source(const QString &orgId, const QString &spaceId, const QString &viaVersionId,
                                      const QString &documentId, const QString &versionId, int width);
    /// Where the reference at `index` of references(markdown) is linked
    /// first: `{start, length}` of its link, empty when there is none.
    Q_INVOKABLE QVariantMap referenceAt(const QString &markdown, int index) const;
    /// Whether `markdown` links an image that render() would block.
    Q_INVOKABLE bool linksExternal(const QString &markdown) const;

signals:
    void changed();
    /// An upload took `token`; the editor shows a placeholder for it.
    void queued(const QString &token, const QString &name);
    /// The image is stored: `link` is the Markdown target to write.
    void uploaded(const QString &token, const QString &link);
    void failed(const QString &token, const QString &code);
    /// The desktop and Android picker lives in QML.
    void promptPick();

private:
    struct Upload {
        QString token;
        QString name;
        QByteArray bytes;
        QString orgId;
        QString spaceId;
    };
    struct Pending {
        Target target;
        Fetched done;
    };
    void next();
    void withFolder(const Upload &upload, std::function<void(const QString &folderId)> done);
    void findFolder(const Upload &upload, bool created, std::function<void(const QString &folderId)> done);
    void store(const Upload &upload, const QString &folderId, const QString &title, bool retried);
    void finish(const QString &link, const QString &code);
    void flush();
    void sign(const QList<Pending> &batch);
    bool live(int generation) const { return generation == m_generation; }

    Session &m_session;
    AddOnBackend &m_backend;
    int m_generation = 0;
    int m_tokens = 0;
    QQueue<Upload> m_uploads;
    QHash<QString, QString> m_folders;
    QHash<QString, QByteArray> m_images;
    QList<Pending> m_pending;
    bool m_flushQueued = false;
};

/// Whether `bytes` start with a PNG, JPEG, GIF, or WebP signature: the only
/// images rendered inline, whatever type a file declares.
bool isRasterImage(const QByteArray &bytes);
}
