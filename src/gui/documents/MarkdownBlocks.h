#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {

/// One leaf block of a Markdown document, in reading order. Containers do
/// not nest: a block inside a quote or a list item carries how deep it sits
/// (`quote`, `indent`), and the first block of a list item its `marker`.
struct MarkdownBlock {
    /// "heading", "paragraph", "code", "table", "image", or "rule".
    QString kind;
    /// Inline content as rich text (`<b>`, `<i>`, `<s>`, `<code>`, `<a>`,
    /// `<br>`): headings and paragraphs.
    QString html;
    /// What copying the block gives: its text without markup; a table's
    /// rows by line, cells by tab.
    QString plain;
    /// A code block's text, verbatim, and its fence's language.
    QString code;
    QString language;
    /// A heading's level, 1 to 6.
    int level = 0;
    /// How many quotes and list items hold the block.
    int quote = 0;
    int indent = 0;
    /// "•", "1.", "☐", or "☑" on the first block of a list item.
    QString marker;
    /// An image's link as written, its alternative text, and its title.
    QString source;
    QString alt;
    QString title;
    /// A table's cells as rich text, its header row first, every row as
    /// wide as the header, and each column's "left", "center", "right", or
    /// "".
    QList<QStringList> rows;
    QStringList align;
    /// The source lines the block comes from, 1-based and inclusive.
    int firstLine = 0;
    int lastLine = 0;
};

/// CommonMark with GitHub's tables, strikethrough, task items, and bare
/// links, as leaf blocks. Raw HTML stays text; comments are left out.
QList<MarkdownBlock> parseMarkdown(const QString &markdown);

/// Whether `block` is an image from another site, which a view loads only
/// once the reader asks.
bool externalImage(const MarkdownBlock &block);

/// The blocks of `markdown` as a list model, a role per field of
/// MarkdownBlock, for a view that builds only the blocks it shows. The
/// roles a comparison adds (DiffBlocks: `change`, `marked`, `count`,
/// `rowStates`) are empty here.
class MarkdownBlocks : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString markdown READ markdown WRITE setMarkdown NOTIFY markdownChanged)
    Q_PROPERTY(bool externalImages READ externalImages NOTIFY markdownChanged)

public:
    enum Role {
        KindRole = Qt::UserRole + 1,
        HtmlRole,
        PlainRole,
        CodeRole,
        LanguageRole,
        LevelRole,
        QuoteRole,
        IndentRole,
        MarkerRole,
        SourceRole,
        AltRole,
        TitleRole,
        RowsRole,
        AlignRole,
        FirstLineRole,
        LastLineRole,
        ChangeRole,
        MarkedRole,
        CountRole,
        RowStatesRole,
    };

    /// `block`'s value for one of the roles of its own fields.
    static QVariant blockData(const MarkdownBlock &block, int role);
    static QHash<int, QByteArray> blockRoles();

    using QAbstractListModel::QAbstractListModel;
    QString markdown() const { return m_markdown; }
    void setMarkdown(const QString &markdown);
    /// Whether an image links another site, which the view loads only once
    /// the reader asks.
    bool externalImages() const;
    /// What copying block `index` gives.
    Q_INVOKABLE QString plainAt(int index) const;
    /// The last block that starts at or before source line `line` (1-based),
    /// -1 without blocks.
    Q_INVOKABLE int blockAt(int line) const;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void markdownChanged();

private:
    QString m_markdown;
    QList<MarkdownBlock> m_blocks;
};

}
