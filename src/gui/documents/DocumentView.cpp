#include "DocumentView.h"

#include "JsonList.h"
#include "Session.h"
#include "references/Assets.h"

#include <QFile>
#include <QFileInfo>
#include <QStringDecoder>
#include <QUrl>

#include <algorithm>

namespace matome {

namespace {

constexpr qint64 kPreviewBytes = 1024 * 1024;

bool isMarkdown(const QString &type, const QString &filename)
{
    return type == QLatin1String("text/markdown") || filename.endsWith(QLatin1String(".md"), Qt::CaseInsensitive);
}

bool isText(const QString &type, const QString &filename)
{
    static const QStringList extensions{QStringLiteral("txt"), QStringLiteral("csv"), QStringLiteral("json"),
                                        QStringLiteral("log"), QStringLiteral("xml"), QStringLiteral("yaml"),
                                        QStringLiteral("yml"), QStringLiteral("toml"), QStringLiteral("ini")};
    return type.startsWith(QLatin1String("text/")) || type == QLatin1String("application/json")
            || extensions.contains(QFileInfo(filename).suffix().toLower());
}

// UTF-8 without NUL, as Core keeps text; empty and false when it is not.
bool decode(const QByteArray &bytes, QString &text)
{
    QStringDecoder utf8(QStringDecoder::Utf8);
    text = utf8(bytes);
    return !utf8.hasError() && !bytes.contains('\0');
}

} // namespace

DocumentView::DocumentView(Session &session, AddOnBackend &backend)
    : QObject(&session), m_session(session), m_backend(backend)
{
    connect(&session, &Session::changed, this, [this] {
        if (m_active && (!m_session.signedIn() || m_orgId != m_session.currentOrgId()
                         || m_spaceId != m_session.currentSpaceId()))
            close();
    });
}

QString DocumentView::title() const
{
    return m_document.value(QStringLiteral("title")).toString();
}

QStringList DocumentView::place() const
{
    if (!m_active)
        return {};
    return QStringList{m_session.spaces()->nameOf(m_spaceId)}
            + m_session.folders()->namesTo(jsonId(m_document.value(QStringLiteral("folder_id"))));
}

QString DocumentView::versionId() const
{
    return jsonId(m_version.value(QStringLiteral("id")));
}

bool DocumentView::latest() const
{
    return m_version.value(QStringLiteral("current")).toBool();
}

QString DocumentView::kind() const
{
    if (m_version.isEmpty())
        return QStringLiteral("none");
    const QString type = m_version.value(QStringLiteral("content_type")).toString();
    const QString filename = m_version.value(QStringLiteral("filename")).toString();
    const QString detected = m_version.value(QStringLiteral("detected_content_type")).toString();
    const bool small = m_version.value(QStringLiteral("byte_size")).toInteger() <= kPreviewBytes;
    if (small && isMarkdown(type, filename))
        return QStringLiteral("markdown");
    if (detected.startsWith(QLatin1String("image/")))
        return QStringLiteral("image");
    if (small && isText(type, filename))
        return QStringLiteral("text");
    return QStringLiteral("none");
}

bool DocumentView::editable() const
{
    const QString shown = kind();
    return m_active && latest() && m_textLoaded && (shown == QLatin1String("markdown") || shown == QLatin1String("text"));
}

void DocumentView::setTab(const QString &tab)
{
    if (tab == m_tab || !allows((tab + QLatin1String("-tab")).toLatin1()))
        return;
    m_tab = tab;
    emit changed();
}

void DocumentView::setExtraTab(const QString &tab, bool shown)
{
    if (shown == m_extraTabs.contains(tab))
        return;
    if (shown)
        m_extraTabs.append(tab);
    else
        m_extraTabs.removeAll(tab);
    if (!shown && m_tab == tab)
        m_tab = QStringLiteral("view");
    emit changed();
}

QString DocumentView::documentPath(const QString &suffix) const
{
    return contentPath(m_orgId, m_spaceId, QStringLiteral("documents/%1%2").arg(m_documentId, suffix));
}

void DocumentView::open(const QString &documentId)
{
    if (!m_session.inSpace() || documentId.isEmpty())
        return;
    close();
    m_active = true;
    m_orgId = m_session.currentOrgId();
    m_spaceId = m_session.currentSpaceId();
    m_documentId = documentId;
    m_tab = QStringLiteral("view");
    load();
    emit opened(documentId);
}

void DocumentView::close()
{
    if (!m_active)
        return;
    ++m_generation;
    m_active = m_textLoaded = false;
    m_pending = 0;
    m_errorIndex = -1;
    m_orgId.clear(); m_spaceId.clear(); m_documentId.clear(); m_tab.clear();
    m_text.clear(); m_errorCode.clear(); m_notice.clear();
    m_document = m_version = {};
    m_versions = {};
    m_extraTabs.clear();
    emit textChanged();
    emit changed();
    emit closed();
}

void DocumentView::refresh()
{
    if (m_active && !busy())
        load();
}

// The document and its published versions; the version shown stays selected
// when it is still there, else the current one is.
void DocumentView::load()
{
    const int generation = ++m_generation;
    const QString shown = versionId();
    m_pending = 2;
    m_errorCode.clear();
    emit changed();
    const auto settle = [this, shown] {
        if (--m_pending > 0) return;
        const auto pick = [this](const QString &id) {
            for (const auto &value : std::as_const(m_versions)) {
                const auto version = value.toObject();
                if (id.isEmpty() ? version.value(QStringLiteral("current")).toBool() : jsonId(version.value(QStringLiteral("id"))) == id)
                    return version;
            }
            return QJsonObject();
        };
        m_version = pick(shown);
        if (m_version.isEmpty()) m_version = pick({});
        if (m_version.isEmpty() && !m_versions.isEmpty()) m_version = m_versions.first().toObject();
        loadText();
    };
    m_backend.request("GET", documentPath(), {}, {}, [this, generation, settle](const Client::Reply &reply) {
        if (!live(generation)) return;
        m_document = reply.json.value(QStringLiteral("document")).toObject();
        if (!reply.ok) m_errorCode = failCode(reply);
        settle();
    });
    m_backend.list(documentPath(QStringLiteral("/versions")), QStringLiteral("data"),
                   [this, generation] { return live(generation); },
                   [this, settle](const Client::Reply &reply, const QJsonArray &rows) {
        QList<QJsonObject> published;
        for (const auto &row : rows) {
            const auto version = row.toObject();
            if (version.value(QStringLiteral("publication_state")).toString() == QLatin1String("published"))
                published.append(version);
        }
        std::sort(published.begin(), published.end(), [](const QJsonObject &a, const QJsonObject &b) {
            return a.value(QStringLiteral("version_number")).toInt() > b.value(QStringLiteral("version_number")).toInt();
        });
        m_versions = {};
        for (const auto &version : std::as_const(published)) m_versions.append(version);
        if (!reply.ok) m_errorCode = failCode(reply);
        settle();
    });
}

void DocumentView::selectVersion(const QString &versionId)
{
    if (!m_active || busy() || versionId == this->versionId())
        return;
    for (const auto &value : std::as_const(m_versions)) {
        if (jsonId(value.toObject().value(QStringLiteral("id"))) == versionId) {
            m_version = value.toObject();
            if (!latest() && m_tab == QLatin1String("edit")) m_tab = QStringLiteral("view");
            loadText();
            return;
        }
    }
}

// The selected version's text, for the kinds that show it.
void DocumentView::loadText()
{
    m_textLoaded = false;
    m_text.clear();
    emit textChanged();
    const QString shown = kind();
    if (shown != QLatin1String("markdown") && shown != QLatin1String("text")) {
        emit changed();
        return;
    }
    const int generation = m_generation;
    ++m_pending;
    emit changed();
    m_backend.request("GET", documentPath(QStringLiteral("/download?version_id=") + versionId()), {}, {},
                      [this, generation](const Client::Reply &reply) {
        if (!live(generation)) return;
        const QUrl url(reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("url")).toString());
        if (!reply.ok || url.isEmpty()) {
            --m_pending;
            fail(reply.ok ? QStringLiteral("not_found") : failCode(reply));
            return;
        }
        m_backend.getFile(url, [this, generation](const Client::Reply &file) {
            if (!live(generation)) return;
            --m_pending;
            QString text;
            if (!file.ok) { fail(failCode(file)); return; }
            if (!decode(file.bytes, text)) { fail(QStringLiteral("invalid_encoding")); return; }
            m_text = text;
            m_textLoaded = true;
            emit textChanged();
            emit changed();
        });
    });
}

void DocumentView::save(const QString &text, const QString &reason)
{
    if (!allows("save-document"))
        return;
    const QByteArray bytes = text.toUtf8();
    const bool markdown = kind() == QLatin1String("markdown");
    QJsonObject descriptor{{QStringLiteral("space_id"), m_spaceId}, {QStringLiteral("document_id"), m_documentId},
                           {QStringLiteral("filename"), m_version.value(QStringLiteral("filename"))},
                           {QStringLiteral("content_type"), m_version.value(QStringLiteral("content_type"))}};
    if (!reason.trimmed().isEmpty())
        descriptor.insert(QStringLiteral("reason"), reason.trimmed());
    if (markdown)
        descriptor.insert(QStringLiteral("references"), Assets::references(text));
    const int generation = m_generation;
    ++m_pending;
    m_errorCode.clear();
    m_errorIndex = -1;
    m_notice.clear();
    emit changed();
    m_backend.upload(m_orgId, descriptor, bytes, [this, generation] { return live(generation); },
                     [this](const Client::Reply &reply) {
        --m_pending;
        if (!reply.ok) {
            fail(failCode(reply), reply.json.value(QStringLiteral("details")).toObject().value(QStringLiteral("index")).toInt(-1));
            return;
        }
        const bool review = reply.json.value(QStringLiteral("data")).toObject().value(QStringLiteral("review")).isObject();
        m_notice = review ? QStringLiteral("review_requested") : QStringLiteral("version_published");
        emit saved();
        m_session.documents()->reload();
        load();
    });
}

void DocumentView::fail(const QString &code, int index)
{
    m_errorCode = code;
    m_errorIndex = index;
    emit changed();
}

QString DocumentView::readDraft(const QUrl &url)
{
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile file(path);
    QString text;
    if (path.endsWith(QLatin1String(".md"), Qt::CaseInsensitive) && file.open(QIODevice::ReadOnly)
            && file.size() <= kPreviewBytes && decode(file.readAll(), text))
        return text;
    fail(QStringLiteral("invalid_markdown"));
    return {};
}

bool DocumentView::allows(QByteArrayView id) const
{
    if (!m_active)
        return false;
    const bool idle = !busy();
    const bool editing = m_tab == QLatin1String("edit") && editable() && idle;
    if (id == "view-tab" || id == "versions-tab") return true;
    if (id == "edit-tab") return editable();
    if (id == "reviews-tab") return m_extraTabs.contains(QStringLiteral("reviews"));
    if (id == "download-version") return idle && !m_version.isEmpty();
    if (id == "save-document" || id == "discard-changes") return editing;
    if (id == "insert-image") return editing && kind() == QLatin1String("markdown");
    return false;
}

void DocumentView::perform(QByteArrayView id)
{
    if (!allows(id))
        return;
    if (id.endsWith("-tab"))
        setTab(QString::fromLatin1(id.chopped(4)));
    else if (id == "download-version")
        m_session.documents()->download(m_documentId, versionId());
    else
        emit requested(QString::fromLatin1(id));
}
}
