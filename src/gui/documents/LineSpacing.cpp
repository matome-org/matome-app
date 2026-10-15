#include "LineSpacing.h"

#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>

#include <algorithm>

namespace matome {

void LineSpacing::setDocument(QQuickTextDocument *document)
{
    if (document == m_document)
        return;
    disconnect(m_changes);
    m_document = document;
    if (QTextDocument *text = document ? document->textDocument() : nullptr) {
        m_changes = connect(text, &QTextDocument::contentsChange, this,
                            [this](int position, int, int added) { schedule(position, position + added); });
        schedule(0, text->characterCount());
    }
    emit documentChanged();
}

void LineSpacing::setHeight(int height)
{
    if (height == m_height)
        return;
    m_height = height;
    if (QTextDocument *text = m_document ? m_document->textDocument() : nullptr)
        schedule(0, text->characterCount());
    emit heightChanged();
}

void LineSpacing::schedule(int from, int to)
{
    const bool queued = m_from >= 0;
    m_from = queued ? std::min(m_from, from) : from;
    m_to = queued ? std::max(m_to, to) : to;
    if (!queued)
        QMetaObject::invokeMethod(this, &LineSpacing::apply, Qt::QueuedConnection);
}

void LineSpacing::apply()
{
    QTextDocument *text = m_document ? m_document->textDocument() : nullptr;
    const int from = m_from, to = m_to;
    m_from = m_to = -1;
    if (!text)
        return;
    const QTextBlock last = text->findBlock(std::clamp(to, 0, text->characterCount() - 1));
    // A new text has nothing to undo yet: its spacing stays out of the stack.
    const bool fresh = !text->isUndoAvailable() && !text->isRedoAvailable();
    QTextCursor cursor(text);
    bool editing = false;
    for (QTextBlock block = text->findBlock(std::max(0, from)); block.isValid(); block = block.next()) {
        QTextBlockFormat format = block.blockFormat();
        if (format.lineHeightType() != QTextBlockFormat::ProportionalHeight || format.lineHeight() != m_height) {
            if (!editing) {
                if (fresh)
                    cursor.beginEditBlock();
                else
                    cursor.joinPreviousEditBlock();
                editing = true;
            }
            format.setLineHeight(m_height, QTextBlockFormat::ProportionalHeight);
            cursor.setPosition(block.position());
            cursor.setBlockFormat(format);
        }
        if (block == last)
            break;
    }
    if (!editing)
        return;
    cursor.endEditBlock();
    if (fresh)
        text->clearUndoRedoStacks();
}

}
