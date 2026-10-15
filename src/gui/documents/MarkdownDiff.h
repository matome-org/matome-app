#pragma once

#include "MarkdownBlocks.h"

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

#include <functional>

namespace matome {

/// One step of aligning two sequences: an item kept, removed from the
/// first, added in the second, or changed (a removed item paired with the
/// added one that replaces it). The index on the side without it is -1.
struct DiffStep {
    enum State { Kept, Removed, Added, Changed };
    State state = Kept;
    int before = -1;
    int after = -1;
};

/// Aligns two sequences by their keys (Myers), then, within each run of
/// removals and additions, pairs each removed item with the next added one
/// `pairs(before, after, oneToOne)` accepts; `oneToOne` says whether the run
/// removes as many items as it adds.
QList<DiffStep> alignSequences(const QStringList &before, const QStringList &after,
                               const std::function<bool(int, int, bool)> &pairs);

/// Two texts compared word by word. Rich text keeps its tags whole and
/// never marks them; plain text comes out escaped. Removed words sit in
/// `<span class="del">`, added ones in `<span class="ins">`.
struct WordDiff {
    /// The removed words, then the added ones, where they changed.
    QString merged;
    /// The first text with its removed words marked.
    QString before;
    /// The second text with its added words marked.
    QString after;
    /// The share of words kept, 0 to 1.
    double similarity = 1;
};
WordDiff diffWords(const QString &before, const QString &after, bool rich);

/// The blocks of two documents aligned: a heading, a paragraph, or a list
/// item rewritten is changed when enough of its words stay; a table when it
/// keeps its columns.
QList<DiffStep> diffBlocks(const QList<MarkdownBlock> &before, const QList<MarkdownBlock> &after);

/// The lines of two texts aligned, a run's removed and added lines paired in
/// order.
QList<DiffStep> diffLines(const QStringList &before, const QStringList &after);

/// The rows of a comparison: its steps, unchanged runs folded into one row
/// each but for the few steps around a change. A fold opens in place.
class DiffRows : public QAbstractListModel
{
    Q_OBJECT
    QML_ANONYMOUS
    /// The row each change starts on, in order.
    Q_PROPERTY(QList<int> changes READ changes NOTIFY changesChanged)

public:
    using QAbstractListModel::QAbstractListModel;
    QList<int> changes() const { return m_changes; }
    /// Opens the fold on `row` into the steps it holds.
    Q_INVOKABLE void expand(int row);
    int rowCount(const QModelIndex &parent = {}) const override;

signals:
    void changesChanged();

protected:
    struct Row {
        int step = 0;
        /// The steps a fold holds from `step`; 0 for a step's own row.
        int folded = 0;
    };
    /// Shows `steps`, `context` unchanged steps kept on each side of a change.
    void show(const QList<DiffStep> &steps, int context);
    const QList<DiffStep> &steps() const { return m_steps; }
    Row rowAt(int row) const { return m_rows.at(row); }

private:
    void count();
    QList<DiffStep> m_steps;
    QList<Row> m_rows;
    QList<int> m_changes;
};

/// The rendered side of a comparison: the blocks of the second document and
/// those removed from the first, each with its state and, changed or
/// removed, its text marked (`marked`; a table's cells and `rowStates`).
/// Its roles are MarkdownBlocks', so the same view shows either.
class DiffBlocks : public DiffRows
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(bool externalImages READ externalImages NOTIFY changesChanged)

public:
    using DiffRows::DiffRows;
    void compare(const QList<MarkdownBlock> &before, const QList<MarkdownBlock> &after, const QList<DiffStep> &steps);
    bool externalImages() const;
    /// What copying row `index` gives.
    Q_INVOKABLE QString plainAt(int index) const;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    struct Shown {
        MarkdownBlock block;
        QString marked;
        QStringList rowStates;
    };
    static void markTable(const MarkdownBlock &from, Shown &shown);
    QList<Shown> m_shown;
};

/// The source side of a comparison: the two texts line by line, side by
/// side, each row with its line numbers (0 where a side has no line) and
/// its text as escaped rich text, changed words marked.
class DiffLines : public DiffRows
{
    Q_OBJECT
    QML_ANONYMOUS

public:
    enum Role { ChangeRole = Qt::UserRole + 1, CountRole, BeforeNumberRole, AfterNumberRole, BeforeTextRole, AfterTextRole };
    using DiffRows::DiffRows;
    void compare(const QStringList &before, const QStringList &after, const QList<DiffStep> &steps);
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    QStringList m_before, m_after;
};

/// Two Markdown texts compared, for a view: the rendered blocks, the source
/// lines, and the summary, the lines added and removed and the sections
/// (headings) the changes touch. Setting either text compares again once
/// control returns to the event loop.
class MarkdownDiff : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString before READ before WRITE setBefore NOTIFY textsChanged)
    Q_PROPERTY(QString after READ after WRITE setAfter NOTIFY textsChanged)
    Q_PROPERTY(matome::DiffBlocks *blocks READ blocks CONSTANT)
    Q_PROPERTY(matome::DiffLines *lines READ lines CONSTANT)
    Q_PROPERTY(int added READ added NOTIFY compared)
    Q_PROPERTY(int removed READ removed NOTIFY compared)
    Q_PROPERTY(int sections READ sections NOTIFY compared)

public:
    explicit MarkdownDiff(QObject *parent = nullptr);
    QString before() const { return m_before; }
    void setBefore(const QString &text);
    QString after() const { return m_after; }
    void setAfter(const QString &text);
    DiffBlocks *blocks() { return &m_blocks; }
    DiffLines *lines() { return &m_lines; }
    int added() const { return m_added; }
    int removed() const { return m_removed; }
    int sections() const { return m_sections; }

signals:
    void textsChanged();
    void compared();

private:
    void schedule();
    void compare();
    QString m_before, m_after;
    DiffBlocks m_blocks;
    DiffLines m_lines;
    int m_added = 0, m_removed = 0, m_sections = 0;
    bool m_scheduled = false;
};

}
