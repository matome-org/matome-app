#pragma once

#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

class QQmlEngine;

namespace matome {
class Session;

/// Registers `image://asset/<org>/<space>/<via version>/<document>/<version>?w=<px>`:
/// an image a Markdown version pins, signed through `via version`, shown only
/// when its bytes are a raster image and never wider than `w`.
void installAssetImages(QQmlEngine &engine, Session &session);

/// The clipboard's image, for pasting into the Markdown editor: copied
/// pixels, copied PNG bytes, or a copied image file. WebAssembly hands a
/// pasted image over as a file it wrote under /qt/tmp.
class Clipboard : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;
    Q_INVOKABLE bool hasImage() const;
    /// The copied image's bytes: its file's, else PNG.
    Q_INVOKABLE QByteArray image() const;
    /// The copied image file's name; empty for pasted pixels.
    Q_INVOKABLE QString imageName() const;

private:
    QString imageFile() const;
};
}
