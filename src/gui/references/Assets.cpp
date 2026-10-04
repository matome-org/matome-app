#include "Assets.h"

#include "JsonList.h"
#include "LocalFiles.h"
#include "Session.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <QUrl>

#include <algorithm>

namespace matome {

namespace {

// The declared type for bytes isRasterImage accepted.
QString rasterType(const QByteArray &bytes)
{
    if (bytes.startsWith("\x89PNG\r\n\x1a\n")) return QStringLiteral("image/png");
    if (bytes.startsWith("\xff\xd8\xff")) return QStringLiteral("image/jpeg");
    if (bytes.startsWith("GIF87a") || bytes.startsWith("GIF89a")) return QStringLiteral("image/gif");
    if (bytes.size() >= 12 && bytes.startsWith("RIFF") && bytes.mid(8, 4) == "WEBP") return QStringLiteral("image/webp");
    return {};
}

QString extension(const QString &type)
{
    return type == QLatin1String("image/jpeg") ? QStringLiteral("jpg") : type.section(QLatin1Char('/'), 1);
}

// A document title under the naming rule: no separators or control
// characters; a pasted image without one is named for when it was pasted.
QString titleFor(const QString &name, const QString &type)
{
    QString title;
    for (const QChar c : name.trimmed())
        if (c != QLatin1Char('/') && c != QLatin1Char('\\') && c.unicode() >= 0x20 && c.unicode() != 0x7f)
            title.append(c);
    if (title.isEmpty() || title == QLatin1String(".") || title == QLatin1String(".."))
        title = QStringLiteral("image-%1.%2")
                        .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd-HHmmss")), extension(type));
    return title;
}

// A title as a link's text: without the brackets that would end it.
QString linkText(const QString &title)
{
    QString text = title;
    return text.remove(QLatin1Char('[')).remove(QLatin1Char(']'));
}

// `![alt](matome:asset/<document>?version=<version>)`; the alt text is free.
const QRegularExpression &assetLink()
{
    static const QRegularExpression link(QStringLiteral(R"(\]\(matome:asset/(\d+)\?version=([0-9A-Fa-f-]{36})\))"));
    return link;
}

// Any file a document links: `](matome:asset/<document>?version=<version>)`,
// `](matome:doc/<document>)` with the version optional, or `](/<path>)` from
// the space root with an optional title. `//host` is another site; a path
// may hold balanced parentheses, as CommonMark allows.
const QRegularExpression &fileLink()
{
    static const QRegularExpression link(QStringLiteral(
            R"(\]\((?:matome:(asset|doc)/(\d+)(?:\?version=([0-9A-Fa-f-]{36}))?|(/(?:[^/\s()]|\([^\s()]*\))(?:[^\s()]|\([^\s()]*\))*)(?:\s+"[^"]*")?)\))"));
    return link;
}

// The decoded path a `](/<path>)` link names, without its query or
// fragment; empty when Core would refuse it (an empty segment).
QString linkPath(const QString &link)
{
    const QString bare = link.section(QLatin1Char('#'), 0, 0).section(QLatin1Char('?'), 0, 0);
    QStringList segments;
    for (const QString &segment : bare.mid(1).split(QLatin1Char('/'))) {
        const QString name = QUrl::fromPercentEncoding(segment.toUtf8());
        if (name.trimmed().isEmpty())
            return {};
        segments.append(name);
    }
    return QLatin1Char('/') + segments.join(QLatin1Char('/'));
}

struct Link {
    QJsonObject reference;
    qsizetype start = 0;
    qsizetype length = 0;
};

// The references `markdown` declares, in order and once each: a document and
// the version it pins, or a path compared like Core's name keys.
QList<Link> fileLinks(const QString &markdown, bool paths)
{
    QList<Link> links;
    QSet<QString> seen;
    for (auto it = fileLink().globalMatch(markdown); it.hasNext();) {
        const auto match = it.next();
        QJsonObject reference;
        QString key;
        if (match.hasCaptured(4)) {
            const QString path = paths ? linkPath(match.captured(4)) : QString();
            if (path.isEmpty())
                continue;
            reference.insert(QStringLiteral("path"), path);
            key = QStringLiteral("path:") + path.normalized(QString::NormalizationForm_C).toCaseFolded();
        } else {
            reference.insert(QStringLiteral("document_id"), match.captured(2).toLongLong());
            if (!match.captured(3).isEmpty())
                reference.insert(QStringLiteral("version_id"), match.captured(3));
            key = match.captured(2) + QLatin1Char('@') + match.captured(3);
        }
        if (seen.contains(key))
            continue;
        seen.insert(key);
        links.append({reference, match.capturedStart(), match.capturedLength()});
    }
    return links;
}

// An image linked from anywhere else: `![alt](http…)`.
const QRegularExpression &externalImage()
{
    static const QRegularExpression image(QStringLiteral(R"(!\[([^\]]*)\]\(((?:https?:)?//[^)\s]+)[^)]*\))"),
                                          QRegularExpression::CaseInsensitiveOption);
    return image;
}


} // namespace

QJsonArray Assets::references(const QString &markdown, bool paths)
{
    QJsonArray list;
    for (const Link &link : fileLinks(markdown, paths))
        list.append(link.reference);
    return list;
}

QString Assets::markdownLink(const QString &title, const QString &documentId, const QString &versionId, bool image)
{
    const QString text = linkText(title);
    if (image)
        return QStringLiteral("![%1](matome:asset/%2?version=%3)").arg(text, documentId, versionId);
    return versionId.isEmpty() ? QStringLiteral("[%1](matome:doc/%2)").arg(text, documentId)
                               : QStringLiteral("[%1](matome:doc/%2?version=%3)").arg(text, documentId, versionId);
}

QString Assets::pathLink(const QString &title, const QString &path)
{
    QStringList segments;
    for (const QString &segment : path.split(QLatin1Char('/'), Qt::SkipEmptyParts))
        segments.append(QString::fromLatin1(QUrl::toPercentEncoding(segment)));
    return QStringLiteral("[%1](/%2)").arg(linkText(title), segments.join(QLatin1Char('/')));
}

QString Assets::render(const QString &markdown, const QString &orgId, const QString &spaceId,
                       const QString &viaVersionId, int width, bool external) const
{
    QString shown = markdown;
    shown.replace(assetLink(), QStringLiteral("](%1)").arg(source(orgId, spaceId, viaVersionId,
                                                                  QStringLiteral("\\1"), QStringLiteral("\\2"), width)));
    if (!external)
        shown.replace(externalImage(), QStringLiteral("*\\1* ") + tr("(external image not loaded: %1)").arg(QStringLiteral("\\2")));
    return shown;
}

QString Assets::source(const QString &orgId, const QString &spaceId, const QString &viaVersionId,
                       const QString &documentId, const QString &versionId, int width)
{
    return QStringLiteral("image://asset/%1/%2/%3/%4/%5?w=%6")
            .arg(orgId, spaceId, viaVersionId.isEmpty() ? QStringLiteral("-") : viaVersionId, documentId, versionId)
            .arg(width);
}

QVariantMap Assets::referenceAt(const QString &markdown, int index, bool paths) const
{
    const QList<Link> links = fileLinks(markdown, paths);
    if (index < 0 || index >= links.size())
        return {};
    return {{QStringLiteral("start"), links.at(index).start}, {QStringLiteral("length"), links.at(index).length}};
}

bool Assets::linksExternal(const QString &markdown) const
{
    return externalImage().match(markdown).hasMatch();
}

bool isRasterImage(const QByteArray &bytes)
{
    return !rasterType(bytes).isEmpty();
}

Assets::Assets(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
}

void Assets::uploadImage(const QString &name, const QByteArray &bytes)
{
    if (!m_session.inSpace())
        return;
    if (!isRasterImage(bytes)) {
        emit failed({}, QStringLiteral("unsupported_image"));
        return;
    }
    const QString token = QString::number(++m_tokens);
    const bool idle = m_uploads.isEmpty();
    m_uploads.enqueue({token, titleFor(name, rasterType(bytes)), bytes, m_session.currentOrgId(),
                       m_session.currentSpaceId()});
    emit queued(token, m_uploads.last().name);
    if (idle) {
        emit changed();
        next();
    }
}

void Assets::uploadUrls(const QList<QUrl> &urls)
{
    for (const QUrl &url : urls) {
        const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
        QFile file(path);
        if (file.open(QIODevice::ReadOnly))
            uploadImage(QFileInfo(path).fileName(), file.readAll());
        else
            emit failed({}, QStringLiteral("unreadable"));
    }
}

void Assets::pickImages()
{
#ifdef Q_OS_WASM
    pickLocalFiles("image/png,image/jpeg,image/gif,image/webp",
                   [this](const QString &name, const QByteArray &bytes) { uploadImage(name, bytes); });
#else
    emit promptPick();
#endif
}

void Assets::search(const QString &text, const QString &folderId, const QString &excludeId)
{
    if (!m_session.inSpace())
        return;
    const int generation = m_generation;
    const int search = ++m_searches;
    const QString orgId = m_session.currentOrgId(), spaceId = m_session.currentSpaceId();
    const QString path = contentPath(orgId, spaceId, QStringLiteral("documents?limit=25&q="))
            + QString::fromLatin1(QUrl::toPercentEncoding(text.trimmed()));
    m_backend.request("GET", path, {}, {}, [this, generation, search, text, folderId, excludeId, spaceId](const Client::Reply &reply) {
        // Only the latest search answers: typing on overtakes the rest.
        if (!live(generation) || search != m_searches) return;
        const auto *folders = m_session.folders();
        const QString space = m_session.spaces()->nameOf(spaceId);
        QList<QVariantMap> files;
        for (const auto &row : reply.json.value(QStringLiteral("documents")).toArray()) {
            const auto document = row.toObject();
            const QString id = jsonId(document.value(QStringLiteral("id")));
            if (id.isEmpty() || id == excludeId) continue;
            const auto version = document.value(QStringLiteral("current_version")).toObject();
            const QString folder = jsonId(document.value(QStringLiteral("folder_id")));
            const QString title = document.value(QStringLiteral("title")).toString();
            const QStringList names = folders->namesTo(folder);
            files.append({{QStringLiteral("documentId"), id},
                          {QStringLiteral("versionId"), jsonId(version.value(QStringLiteral("id")))},
                          {QStringLiteral("title"), title},
                          {QStringLiteral("folderId"), folder},
                          {QStringLiteral("place"), (QStringList{space} + names).join(QStringLiteral(" › "))},
                          {QStringLiteral("path"), QLatin1Char('/') + (names + QStringList{title}).join(QLatin1Char('/'))},
                          {QStringLiteral("image"), version.value(QStringLiteral("detected_content_type")).toString()
                                                            .startsWith(QLatin1String("image/"))}});
        }
        const QString needle = text.trimmed();
        std::stable_sort(files.begin(), files.end(), [&](const QVariantMap &a, const QVariantMap &b) {
            const auto rank = [&](const QVariantMap &file) {
                return (file.value(QStringLiteral("folderId")).toString() == folderId ? 0 : 2)
                        + (file.value(QStringLiteral("title")).toString().startsWith(needle, Qt::CaseInsensitive) ? 0 : 1);
            };
            if (rank(a) != rank(b)) return rank(a) < rank(b);
            return a.value(QStringLiteral("title")).toString().compare(b.value(QStringLiteral("title")).toString(),
                                                                       Qt::CaseInsensitive) < 0;
        });
        QVariantList list;
        for (const QVariantMap &file : std::as_const(files)) list.append(file);
        emit found(text, list);
    });
}

// Walks the folders the space lists down to the link's last folder, then
// asks for the documents there titled like its last segment.
void Assets::resolve(const QString &link)
{
    QStringList names;
    for (const QString &segment : link.split(QLatin1Char('/'), Qt::SkipEmptyParts))
        names.append(QUrl::fromPercentEncoding(segment.toUtf8()));
    if (!m_session.inSpace() || !link.startsWith(QLatin1Char('/')) || names.isEmpty()) {
        emit resolved(link, {});
        return;
    }
    const QString title = names.takeLast();
    const auto &all = m_session.folders()->all();
    QString folderId;
    for (const QString &name : std::as_const(names)) {
        const auto row = std::find_if(all.begin(), all.end(), [&](const FolderRow &folder) {
            return folder.parentId == folderId && folder.name == name;
        });
        if (row == all.end()) {
            emit resolved(link, {});
            return;
        }
        folderId = row->id;
    }
    const int generation = m_generation;
    const QString path = contentPath(m_session.currentOrgId(), m_session.currentSpaceId(),
                                     QStringLiteral("documents?limit=100&folder_id=%1&q=")
                                             .arg(folderId.isEmpty() ? QStringLiteral("root") : folderId))
            + QString::fromLatin1(QUrl::toPercentEncoding(title));
    m_backend.request("GET", path, {}, {}, [this, generation, link, title](const Client::Reply &reply) {
        if (!live(generation)) return;
        QString documentId;
        for (const auto &row : reply.json.value(QStringLiteral("documents")).toArray()) {
            const auto document = row.toObject();
            if (document.value(QStringLiteral("title")).toString() == title) {
                documentId = jsonId(document.value(QStringLiteral("id")));
                break;
            }
        }
        emit resolved(link, documentId);
    });
}

void Assets::clear()
{
    if (m_uploads.isEmpty() && m_images.isEmpty() && m_folders.isEmpty() && m_pending.isEmpty())
        return;
    ++m_generation;
    m_uploads.clear();
    m_folders.clear();
    m_images.clear();
    m_pending.clear();
    emit changed();
}

// The upload at the head of the queue: reuse a readable document with the
// same bytes, else store a new one in the assets folder.
void Assets::next()
{
    if (m_uploads.isEmpty()) {
        emit changed();
        return;
    }
    const Upload upload = m_uploads.head();
    const int generation = m_generation;
    const QString checksum = QString::fromLatin1(QCryptographicHash::hash(upload.bytes, QCryptographicHash::Sha256).toHex());
    m_backend.request("GET", contentPath(upload.orgId, upload.spaceId, QStringLiteral("documents?checksum_sha256=") + checksum),
                      {}, {}, [this, generation, upload](const Client::Reply &reply) {
        if (!live(generation)) return;
        for (const auto &row : reply.json.value(QStringLiteral("documents")).toArray()) {
            const auto document = row.toObject();
            const QString version = jsonId(document.value(QStringLiteral("current_version")).toObject().value(QStringLiteral("id")));
            if (!version.isEmpty()) {
                finish(markdownLink(upload.name, jsonId(document.value(QStringLiteral("id"))), version, true), {});
                return;
            }
        }
        withFolder(upload, [this, upload](const QString &folderId) { store(upload, folderId, upload.name, false); });
    });
}

void Assets::withFolder(const Upload &upload, std::function<void(const QString &)> done)
{
    const QString key = upload.orgId + QLatin1Char('/') + upload.spaceId;
    if (m_folders.contains(key))
        done(m_folders.value(key));
    else
        findFolder(upload, false, std::move(done));
}

// The assets folder at the root of the space, created once; a name conflict
// is another client creating it at the same time, so it is listed again.
void Assets::findFolder(const Upload &upload, bool created, std::function<void(const QString &)> done)
{
    const int generation = m_generation;
    m_backend.list(contentPath(upload.orgId, upload.spaceId, QStringLiteral("folders")), QStringLiteral("folders"),
                   [this, generation] { return live(generation); },
                   [this, generation, upload, created, done](const Client::Reply &reply, const QJsonArray &rows) {
        if (!reply.ok) { finish({}, failCode(reply)); return; }
        for (const auto &row : rows) {
            const auto folder = row.toObject();
            if (jsonId(folder.value(QStringLiteral("parent_id"))).isEmpty()
                    && folder.value(QStringLiteral("name")).toString().compare(folderName(), Qt::CaseInsensitive) == 0) {
                const QString id = jsonId(folder.value(QStringLiteral("id")));
                m_folders.insert(upload.orgId + QLatin1Char('/') + upload.spaceId, id);
                done(id);
                return;
            }
        }
        if (created) { finish({}, QStringLiteral("assets_unavailable")); return; }
        m_backend.request("POST", contentPath(upload.orgId, upload.spaceId, QStringLiteral("folders")),
                          {{QStringLiteral("name"), folderName()}}, idempotencyHeader(),
                          [this, generation, upload, done](const Client::Reply &made) {
            if (!live(generation)) return;
            if (made.ok) {
                const QString id = jsonId(made.json.value(QStringLiteral("folder")).toObject().value(QStringLiteral("id")));
                m_folders.insert(upload.orgId + QLatin1Char('/') + upload.spaceId, id);
                done(id);
            } else if (made.code == QLatin1String("name_conflict")) {
                findFolder(upload, true, done);
            } else {
                finish({}, failCode(made));
            }
        });
    });
}

// Creates the image's document, then uploads its only version. A title the
// folder already holds is retried once with a short random suffix.
void Assets::store(const Upload &upload, const QString &folderId, const QString &title, bool retried)
{
    const int generation = m_generation;
    m_backend.request("POST", contentPath(upload.orgId, upload.spaceId, QStringLiteral("documents")),
                      {{QStringLiteral("title"), title}, {QStringLiteral("folder_id"), folderId}}, idempotencyHeader(),
                      [this, generation, upload, folderId, title, retried](const Client::Reply &made) {
        if (!live(generation)) return;
        if (!made.ok && made.code == QLatin1String("name_conflict") && !retried) {
            const QFileInfo name(title);
            store(upload, folderId, QStringLiteral("%1-%2.%3").arg(name.completeBaseName())
                          .arg(QRandomGenerator::global()->bounded(0x10000), 4, 16, QLatin1Char('0'))
                          .arg(name.suffix()), true);
            return;
        }
        const QString documentId = jsonId(made.json.value(QStringLiteral("document")).toObject().value(QStringLiteral("id")));
        if (!made.ok || documentId.isEmpty()) { finish({}, made.ok ? QStringLiteral("invalid_request") : failCode(made)); return; }
        m_backend.upload(upload.orgId,
                         {{QStringLiteral("space_id"), upload.spaceId}, {QStringLiteral("document_id"), documentId},
                          {QStringLiteral("filename"), title}, {QStringLiteral("content_type"), rasterType(upload.bytes)}},
                         upload.bytes, [this, generation] { return live(generation); },
                         [this, documentId, title](const Client::Reply &reply) {
            const QString version = jsonId(reply.json.value(QStringLiteral("data")).toObject()
                                                   .value(QStringLiteral("version")).toObject().value(QStringLiteral("id")));
            if (reply.ok && !version.isEmpty()) finish(markdownLink(title, documentId, version, true), {});
            else finish({}, reply.ok ? QStringLiteral("invalid_request") : failCode(reply));
        });
    });
}

void Assets::finish(const QString &link, const QString &code)
{
    const Upload done = m_uploads.dequeue();
    if (code.isEmpty())
        emit uploaded(done.token, link);
    else
        emit failed(done.token, code);
    next();
}

void Assets::fetch(const Target &target, Fetched done)
{
    if (m_images.contains(target.versionId)) {
        done(m_images.value(target.versionId), {});
        return;
    }
    m_pending.append({target, std::move(done)});
    if (!m_flushQueued) {
        m_flushQueued = true;
        QTimer::singleShot(0, this, &Assets::flush);
    }
}

// The images asked for in one event loop turn, signed in one call per
// rendered version, a hundred at most each.
void Assets::flush()
{
    m_flushQueued = false;
    QHash<QString, QList<Pending>> groups;
    for (const Pending &pending : std::as_const(m_pending)) {
        const Target &t = pending.target;
        groups[t.orgId + QLatin1Char('/') + t.spaceId + QLatin1Char('/') + t.viaVersionId].append(pending);
    }
    m_pending.clear();
    for (const QList<Pending> &group : std::as_const(groups))
        for (qsizetype at = 0; at < group.size(); at += 100)
            sign(group.mid(at, 100));
}

void Assets::sign(const QList<Pending> &batch)
{
    const Target &first = batch.constFirst().target;
    QJsonArray items;
    for (const Pending &pending : batch)
        items.append(QJsonObject{{QStringLiteral("document_id"), pending.target.documentId.toLongLong()},
                                 {QStringLiteral("version_id"), pending.target.versionId}});
    QJsonObject body{{QStringLiteral("items"), items}};
    if (!first.viaVersionId.isEmpty())
        body.insert(QStringLiteral("via_version_id"), first.viaVersionId);
    const int generation = m_generation;
    m_backend.request("POST", contentPath(first.orgId, first.spaceId, QStringLiteral("documents/download-urls")), body, {},
                      [this, generation, batch](const Client::Reply &reply) {
        if (!live(generation)) return;
        const QJsonArray data = reply.json.value(QStringLiteral("data")).toArray();
        for (qsizetype at = 0; at < batch.size(); ++at) {
            const Pending &pending = batch.at(at);
            const auto item = data.at(at).toObject();
            const QUrl url(item.value(QStringLiteral("url")).toString());
            if (!reply.ok || url.isEmpty()) {
                const QString error = item.value(QStringLiteral("error")).toString();
                pending.done({}, !reply.ok ? failCode(reply) : error.isEmpty() ? QStringLiteral("not_found") : error);
                continue;
            }
            // Signed URLs carry their own authorization.
            m_backend.getFile(url, [this, generation, pending](const Client::Reply &file) {
                if (!live(generation)) return;
                if (!file.ok) { pending.done({}, failCode(file)); return; }
                m_images.insert(pending.target.versionId, file.bytes);
                pending.done(file.bytes, {});
            });
        }
    });
}
}
