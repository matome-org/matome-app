#include "AssetImages.h"

#include "Assets.h"
#include "Session.h"

#include <QBuffer>
#include <QClipboard>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QMimeData>
#include <QPainter>
#include <QPointer>
#include <QQmlEngine>
#include <QQuickAsyncImageProvider>
#include <QUrlQuery>

namespace matome {

namespace {

// What stands in for an image that is missing, forbidden, or not a raster
// image: a quiet frame with a slash.
QImage broken()
{
    QImage image(160, 90, QImage::Format_ARGB32_Premultiplied);
    image.fill(QColor(0, 0, 0, 16));
    QPainter painter(&image);
    painter.setPen(QPen(QColor(0, 0, 0, 90), 1.4));
    painter.drawRect(image.rect().adjusted(0, 0, -1, -1));
    painter.drawLine(QPoint(64, 58), QPoint(96, 32));
    return image;
}

class AssetResponse final : public QQuickImageResponse
{
public:
    AssetResponse(Assets &assets, const QString &id)
    {
        const QString path = id.section(QLatin1Char('?'), 0, 0);
        const QStringList parts = path.split(QLatin1Char('/'));
        const int width = QUrlQuery(id.section(QLatin1Char('?'), 1)).queryItemValue(QStringLiteral("w")).toInt();
        if (parts.size() != 5) {
            deliver({}, width);
            return;
        }
        // "-" stands for no via version: a draft that no published version pins.
        const QString via = parts.at(2) == QLatin1String("-") ? QString() : parts.at(2);
        const Assets::Target target{parts.at(0), parts.at(1), via, parts.at(3), parts.at(4)};
        QPointer<AssetResponse> self(this);
        // Assets lives on the GUI thread; image requests may not.
        QMetaObject::invokeMethod(&assets, [&assets, target, self, width] {
            assets.fetch(target, [self, width](const QByteArray &bytes, const QString &) {
                if (self) self->deliver(bytes, width);
            });
        }, Qt::QueuedConnection);
    }

    QQuickTextureFactory *textureFactory() const override
    {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }

private:
    void deliver(const QByteArray &bytes, int width)
    {
        QImage image;
        if (!isRasterImage(bytes) || !image.loadFromData(bytes))
            image = broken();
        m_image = width > 0 && image.width() > width ? image.scaledToWidth(width, Qt::SmoothTransformation) : image;
        emit finished();
    }

    QImage m_image;
};

class AssetImageProvider final : public QQuickAsyncImageProvider
{
public:
    explicit AssetImageProvider(Assets &assets) : m_assets(assets) {}
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &) override
    {
        return new AssetResponse(m_assets, id);
    }

private:
    Assets &m_assets;
};

} // namespace

void installAssetImages(QQmlEngine &engine, Session &session)
{
    engine.addImageProvider(QStringLiteral("asset"), new AssetImageProvider(*session.assets()));
}

// The first copied local file that holds a raster image.
QString Clipboard::imageFile() const
{
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!data || !data->hasUrls())
        return {};
    for (const QUrl &url : data->urls()) {
        QFile file(url.toLocalFile());
        if (url.isLocalFile() && file.open(QIODevice::ReadOnly) && isRasterImage(file.read(12)))
            return file.fileName();
    }
    return {};
}

bool Clipboard::hasImage() const
{
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    return data && (data->hasImage() || data->hasFormat(QStringLiteral("image/png")) || !imageFile().isEmpty());
}

QByteArray Clipboard::image() const
{
    const QString path = imageFile();
    if (!path.isEmpty()) {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!data)
        return {};
    if (data->hasFormat(QStringLiteral("image/png")))
        return data->data(QStringLiteral("image/png"));
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    qvariant_cast<QImage>(data->imageData()).save(&buffer, "PNG");
    return png;
}

QString Clipboard::imageName() const
{
    // A pasted image WebAssembly stored is always "image.png": name it when
    // it was pasted instead.
    const QString path = imageFile();
    return path.startsWith(QLatin1String("/qt/tmp/")) ? QString() : QFileInfo(path).fileName();
}
}
