#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {

/// Spaces the lines of a TextEdit, which Qt Quick does not: every block of
/// `document` takes `height` percent of its line. New text, typing, and
/// pastes follow it; the format leaves no step of its own to undo.
class LineSpacing : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)

public:
    using QObject::QObject;
    QQuickTextDocument *document() const { return m_document; }
    void setDocument(QQuickTextDocument *document);
    int height() const { return m_height; }
    void setHeight(int height);

signals:
    void documentChanged();
    void heightChanged();

private:
    /// Spaces the blocks between `from` and `to`, once the edit that
    /// changed them is over.
    void schedule(int from, int to);
    void apply();

    QPointer<QQuickTextDocument> m_document;
    QMetaObject::Connection m_changes;
    int m_height = 100;
    int m_from = -1;
    int m_to = -1;
};

}
