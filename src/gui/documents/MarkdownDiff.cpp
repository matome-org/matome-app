#include "MarkdownDiff.h"

#include <QHash>
#include <QSet>
#include <QTimer>

#include <algorithm>
#include <vector>

namespace matome {

namespace {

enum class Op { Equal, Remove, Add };

// Past this many edits the middle of two sequences is compared no further:
// it is all removed, then all added.
constexpr int kMaxEdits = 2000;
// How far ahead a removed item looks for the added one it pairs with.
constexpr int kPairWindow = 16;

// Where the furthest path on diagonal `k` after `d` edits comes from:
// `prev` holds the furthest x on each diagonal after d - 1 edits (-1 where
// none reaches), the diagonal -(d - 1) first. Returns that x and whether
// the last edit added (moved down) rather than removed; x is -1 when no
// path inside the n × m grid reaches the diagonal.
std::pair<int, bool> reach(const std::vector<int> &prev, int d, int k, int n, int m)
{
    int best = -1;
    bool down = false;
    if (k < d) {
        const int x = prev[k + 1 + d - 1];
        if (x >= 0 && x - k <= m) {
            best = x;
            down = true;
        }
    }
    if (k > -d) {
        const int x = prev[k - 1 + d - 1] + 1;
        if (x > 0 && x <= n && x > best) {
            best = x;
            down = false;
        }
    }
    return {best, down};
}

// The shortest edit script from `a` to `b` (Myers), one operation per item,
// after their common head and tail.
QList<Op> editScript(const std::vector<int> &a, const std::vector<int> &b)
{
    const int total = int(a.size()), totalAfter = int(b.size());
    int head = 0;
    while (head < total && head < totalAfter && a[head] == b[head])
        ++head;
    int tail = 0;
    while (tail < total - head && tail < totalAfter - head && a[total - 1 - tail] == b[totalAfter - 1 - tail])
        ++tail;
    const int n = total - head, m = totalAfter - head;
    const int *x0 = a.data() + head, *y0 = b.data() + head;
    const int width = n - tail, height = m - tail;

    QList<Op> ops(head, Op::Equal);
    std::vector<std::vector<int>> trace;
    int end = -1;
    if (width > 0 && height > 0) {
        for (int d = 0; d <= std::min(width + height, kMaxEdits) && end < 0; ++d) {
            std::vector<int> v(2 * d + 1, -1);
            for (int k = -d; k <= d; k += 2) {
                int x = d == 0 ? 0 : reach(trace.back(), d, k, width, height).first;
                if (x < 0)
                    continue;
                int y = x - k;
                while (x < width && y < height && x0[x] == y0[y]) {
                    ++x;
                    ++y;
                }
                v[k + d] = x;
                if (x >= width && y >= height) {
                    end = d;
                    break;
                }
            }
            trace.push_back(std::move(v));
        }
    }
    QList<Op> middle;
    if (width == 0 || height == 0 || end < 0) {
        middle.fill(Op::Remove, width);
        middle.append(QList<Op>(height, Op::Add));
    } else {
        int x = width, y = height;
        for (int d = end; d > 0; --d) {
            const int k = x - y;
            const bool down = reach(trace[d - 1], d, k, width, height).second;
            const int from = down ? k + 1 : k - 1;
            const int fromX = trace[d - 1][from + d - 1];
            const int startX = down ? fromX : fromX + 1;
            for (; x > startX; --x, --y)
                middle.append(Op::Equal);
            middle.append(down ? Op::Add : Op::Remove);
            x = fromX;
            y = fromX - from;
        }
        for (; x > 0; --x)
            middle.append(Op::Equal);
        std::reverse(middle.begin(), middle.end());
    }
    ops.append(middle);
    ops.append(QList<Op>(tail, Op::Equal));
    return ops;
}

// The edit script between two lists of keys, equal keys equal items.
QList<Op> editScript(const QStringList &before, const QStringList &after)
{
    QHash<QString, int> ids;
    const auto intern = [&ids](const QStringList &keys) {
        std::vector<int> out;
        out.reserve(keys.size());
        for (const QString &key : keys)
            out.push_back(*ids.tryEmplace(key, int(ids.size())).iterator);
        return out;
    };
    const std::vector<int> a = intern(before);
    const std::vector<int> b = intern(after);
    return editScript(a, b);
}

bool ideograph(QChar c)
{
    const QChar::Script script = c.script();
    return script == QChar::Script_Han || script == QChar::Script_Hiragana || script == QChar::Script_Katakana;
}

bool wordChar(QChar c)
{
    return (c.isLetterOrNumber() || c.isMark() || c == u'_') && !ideograph(c);
}

// Words, runs of whitespace, and single other characters; each ideograph
// is a word of its own. Rich text keeps each tag and entity whole.
QStringList words(const QString &text, bool rich)
{
    QStringList out;
    const qsizetype size = text.size();
    for (qsizetype at = 0; at < size;) {
        const QChar c = text.at(at);
        qsizetype end = at + 1;
        if (rich && c == u'<') {
            const qsizetype close = text.indexOf(u'>', at);
            end = close < 0 ? size : close + 1;
        } else if (rich && c == u'&') {
            const qsizetype semicolon = text.indexOf(u';', at);
            if (semicolon > at && semicolon - at <= 10)
                end = semicolon + 1;
        } else if (c.isSpace()) {
            while (end < size && text.at(end).isSpace())
                ++end;
        } else if (wordChar(c)) {
            while (end < size && wordChar(text.at(end)))
                ++end;
        } else if (c.isHighSurrogate() && end < size) {
            ++end;
        }
        out.append(text.mid(at, end - at));
        at = end;
    }
    return out;
}

bool isTag(const QString &word, bool rich)
{
    return rich && word.startsWith(u'<');
}

bool counts(const QString &word, bool rich)
{
    return !isTag(word, rich) && !word.at(0).isSpace();
}

// Marks `items` as `kind` ("ins" or "del"): the words in one span per run,
// tags left between spans, or dropped unless `tags`.
void mark(QString &into, const QStringList &items, bool rich, QLatin1StringView kind, bool tags)
{
    bool open = false;
    for (const QString &item : items) {
        if (isTag(item, rich)) {
            if (open)
                into += QLatin1String("</span>");
            open = false;
            if (tags)
                into += item;
            continue;
        }
        if (!open) {
            into += QLatin1String("<span class=\"");
            into += kind;
            into += QLatin1String("\">");
        }
        open = true;
        into += rich ? item : item.toHtmlEscaped();
    }
    if (open)
        into += QLatin1String("</span>");
}

QString struck(const QString &html)
{
    return html.isEmpty() ? QString() : QLatin1String("<s>") + html + QLatin1String("</s>");
}

// What a block is compared by: two blocks with the same key are the same.
QString blockKey(const MarkdownBlock &block)
{
    QStringList parts{block.kind, QString::number(block.level), QString::number(block.quote),
                      QString::number(block.indent), block.marker};
    if (block.kind == QLatin1String("code")) {
        parts << block.language << block.code;
    } else if (block.kind == QLatin1String("image")) {
        parts << block.source << block.alt << block.title;
    } else if (block.kind == QLatin1String("table")) {
        parts << block.align.join(u',');
        for (const QStringList &row : block.rows)
            parts << row.join(u'\t');
    } else {
        parts << block.html;
    }
    return parts.join(QChar(0x1f));
}

QString wordsOf(const MarkdownBlock &block)
{
    return block.kind == QLatin1String("code") ? block.code : block.plain;
}

QStringList splitLines(const QString &text)
{
    if (text.isEmpty())
        return {};
    QStringList lines = text.split(u'\n');
    if (text.endsWith(u'\n'))
        lines.removeLast();
    return lines;
}

} // namespace

QList<DiffStep> alignSequences(const QStringList &before, const QStringList &after,
                               const std::function<bool(int, int, bool)> &pairs)
{
    const QList<Op> ops = editScript(before, after);
    QList<DiffStep> steps;
    int i = 0, j = 0;
    for (qsizetype at = 0; at < ops.size();) {
        if (ops.at(at) == Op::Equal) {
            steps.append({DiffStep::Kept, i++, j++});
            ++at;
            continue;
        }
        QList<int> removed, added;
        for (; at < ops.size() && ops.at(at) != Op::Equal; ++at) {
            if (ops.at(at) == Op::Remove)
                removed.append(i++);
            else
                added.append(j++);
        }
        const bool oneToOne = removed.size() == added.size();
        qsizetype next = 0;
        for (const int item : std::as_const(removed)) {
            qsizetype match = -1;
            for (qsizetype t = next; t < std::min(added.size(), next + kPairWindow) && match < 0; ++t) {
                if (pairs(item, added.at(t), oneToOne))
                    match = t;
            }
            if (match < 0) {
                steps.append({DiffStep::Removed, item, -1});
                continue;
            }
            for (; next < match; ++next)
                steps.append({DiffStep::Added, -1, added.at(next)});
            steps.append({DiffStep::Changed, item, added.at(match)});
            next = match + 1;
        }
        for (; next < added.size(); ++next)
            steps.append({DiffStep::Added, -1, added.at(next)});
    }
    return steps;
}

WordDiff diffWords(const QString &before, const QString &after, bool rich)
{
    const QStringList a = words(before, rich), b = words(after, rich);
    const QList<Op> ops = editScript(a, b);
    WordDiff out;
    int kept = 0, i = 0, j = 0;
    for (qsizetype at = 0; at < ops.size();) {
        if (ops.at(at) == Op::Equal) {
            const QString shown = rich ? a.at(i) : a.at(i).toHtmlEscaped();
            out.merged += shown;
            out.before += shown;
            out.after += rich ? b.at(j) : b.at(j).toHtmlEscaped();
            kept += counts(a.at(i), rich) ? 1 : 0;
            ++i;
            ++j;
            ++at;
            continue;
        }
        QStringList removed, added;
        for (; at < ops.size() && ops.at(at) != Op::Equal; ++at) {
            if (ops.at(at) == Op::Remove)
                removed.append(a.at(i++));
            else
                added.append(b.at(j++));
        }
        mark(out.before, removed, rich, QLatin1StringView("del"), true);
        mark(out.merged, removed, rich, QLatin1StringView("del"), false);
        mark(out.after, added, rich, QLatin1StringView("ins"), true);
        mark(out.merged, added, rich, QLatin1StringView("ins"), true);
    }
    const auto wordCount = [rich](const QStringList &items) {
        return std::count_if(items.cbegin(), items.cend(), [rich](const QString &item) { return counts(item, rich); });
    };
    const auto total = wordCount(a) + wordCount(b);
    out.similarity = total == 0 ? 1.0 : 2.0 * kept / double(total);
    return out;
}

QList<DiffStep> diffBlocks(const QList<MarkdownBlock> &before, const QList<MarkdownBlock> &after)
{
    QStringList beforeKeys, afterKeys;
    for (const MarkdownBlock &block : before)
        beforeKeys.append(blockKey(block));
    for (const MarkdownBlock &block : after)
        afterKeys.append(blockKey(block));
    return alignSequences(beforeKeys, afterKeys, [&before, &after](int i, int j, bool oneToOne) {
        const MarkdownBlock &from = before.at(i), &to = after.at(j);
        if (from.kind != to.kind)
            return false;
        if (from.kind == QLatin1String("table"))
            return from.align.size() == to.align.size();
        if (from.kind == QLatin1String("image") || from.kind == QLatin1String("rule"))
            return true;
        return diffWords(wordsOf(from), wordsOf(to), false).similarity >= (oneToOne ? 0.25 : 0.5);
    });
}

QList<DiffStep> diffLines(const QStringList &before, const QStringList &after)
{
    return alignSequences(before, after, [](int, int, bool) { return true; });
}

// DiffRows

int DiffRows::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

void DiffRows::show(const QList<DiffStep> &steps, int context)
{
    beginResetModel();
    m_steps = steps;
    m_rows.clear();
    const int size = int(steps.size());
    for (int at = 0; at < size;) {
        if (steps.at(at).state != DiffStep::Kept) {
            m_rows.append({at, 0});
            ++at;
            continue;
        }
        int end = at;
        while (end < size && steps.at(end).state == DiffStep::Kept)
            ++end;
        // Nothing changed: the whole document folds.
        const bool alone = at == 0 && end == size;
        const int head = at == 0 || alone ? 0 : context;
        const int tail = end == size || alone ? 0 : context;
        const int folded = end - at - head - tail;
        if (folded < 2) {
            for (int step = at; step < end; ++step)
                m_rows.append({step, 0});
        } else {
            for (int step = at; step < at + head; ++step)
                m_rows.append({step, 0});
            m_rows.append({at + head, folded});
            for (int step = end - tail; step < end; ++step)
                m_rows.append({step, 0});
        }
        at = end;
    }
    endResetModel();
    count();
}

void DiffRows::expand(int row)
{
    if (row < 0 || row >= m_rows.size() || m_rows.at(row).folded == 0)
        return;
    const Row fold = m_rows.at(row);
    beginRemoveRows({}, row, row);
    m_rows.removeAt(row);
    endRemoveRows();
    beginInsertRows({}, row, row + fold.folded - 1);
    for (int at = 0; at < fold.folded; ++at)
        m_rows.insert(row + at, {fold.step + at, 0});
    endInsertRows();
    count();
}

void DiffRows::count()
{
    m_changes.clear();
    bool inside = false;
    for (int row = 0; row < m_rows.size(); ++row) {
        const Row &at = m_rows.at(row);
        const bool changed = at.folded == 0 && m_steps.at(at.step).state != DiffStep::Kept;
        if (changed && !inside)
            m_changes.append(row);
        inside = changed;
    }
    emit changesChanged();
}

namespace {

QString stateName(DiffStep::State state)
{
    switch (state) {
    case DiffStep::Removed: return QStringLiteral("removed");
    case DiffStep::Added: return QStringLiteral("added");
    case DiffStep::Changed: return QStringLiteral("changed");
    case DiffStep::Kept: break;
    }
    return {};
}

} // namespace

// DiffBlocks

// A changed table row by row: rows aligned by their cells, a changed row's
// cells compared word by word, a removed one struck.
void DiffBlocks::markTable(const MarkdownBlock &from, Shown &shown)
{
    QStringList fromRows, toRows;
    for (const QStringList &row : from.rows)
        fromRows.append(row.join(u'\t'));
    for (const QStringList &row : std::as_const(shown.block.rows))
        toRows.append(row.join(u'\t'));
    QList<QStringList> rows;
    for (const DiffStep &line : diffLines(fromRows, toRows)) {
        QStringList row = line.after >= 0 ? shown.block.rows.at(line.after) : from.rows.at(line.before);
        if (line.state == DiffStep::Removed) {
            for (QString &cell : row)
                cell = struck(cell);
        } else if (line.state == DiffStep::Changed) {
            for (qsizetype cell = 0; cell < row.size(); ++cell)
                row[cell] = diffWords(from.rows.at(line.before).value(cell), row.at(cell), true).merged;
        }
        rows.append(row);
        shown.rowStates.append(stateName(line.state));
    }
    shown.block.rows = rows;
}

void DiffBlocks::compare(const QList<MarkdownBlock> &before, const QList<MarkdownBlock> &after,
                         const QList<DiffStep> &steps)
{
    m_shown.clear();
    m_shown.reserve(steps.size());
    for (const DiffStep &step : steps) {
        Shown shown{step.after >= 0 ? after.at(step.after) : before.at(step.before), {}, {}};
        MarkdownBlock &block = shown.block;
        const bool code = block.kind == QLatin1String("code");
        const bool prose = block.kind == QLatin1String("heading") || block.kind == QLatin1String("paragraph");
        if (step.state == DiffStep::Removed) {
            shown.marked = prose ? struck(block.html) : code ? struck(block.code.toHtmlEscaped()) : QString();
            for (QStringList &row : block.rows) {
                for (QString &cell : row)
                    cell = struck(cell);
            }
        } else if (step.state == DiffStep::Changed) {
            const MarkdownBlock &from = before.at(step.before);
            if (prose)
                shown.marked = diffWords(from.html, block.html, true).merged;
            else if (code)
                shown.marked = diffWords(from.code, block.code, false).merged;
            else if (block.kind == QLatin1String("table"))
                markTable(from, shown);
        }
        m_shown.append(shown);
    }
    show(steps, 1);
}

bool DiffBlocks::externalImages() const
{
    return std::any_of(m_shown.cbegin(), m_shown.cend(), [](const Shown &shown) { return externalImage(shown.block); });
}

QString DiffBlocks::plainAt(int index) const
{
    if (index < 0 || index >= rowCount() || rowAt(index).folded > 0)
        return {};
    return m_shown.at(rowAt(index).step).block.plain;
}

QVariant DiffBlocks::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const Row row = rowAt(index.row());
    if (row.folded > 0) {
        switch (role) {
        case MarkdownBlocks::ChangeRole: return QStringLiteral("fold");
        case MarkdownBlocks::CountRole: return row.folded;
        case MarkdownBlocks::MarkedRole: return QString();
        case MarkdownBlocks::RowStatesRole: return QStringList();
        }
        MarkdownBlock fold;
        fold.kind = QStringLiteral("fold");
        return MarkdownBlocks::blockData(fold, role);
    }
    const Shown &shown = m_shown.at(row.step);
    switch (role) {
    case MarkdownBlocks::ChangeRole: return stateName(steps().at(row.step).state);
    case MarkdownBlocks::CountRole: return 0;
    case MarkdownBlocks::MarkedRole: return shown.marked;
    case MarkdownBlocks::RowStatesRole: return shown.rowStates;
    }
    return MarkdownBlocks::blockData(shown.block, role);
}

QHash<int, QByteArray> DiffBlocks::roleNames() const
{
    return MarkdownBlocks::blockRoles();
}

// DiffLines

void DiffLines::compare(const QStringList &before, const QStringList &after, const QList<DiffStep> &steps)
{
    m_before = before;
    m_after = after;
    for (const DiffStep &step : steps) {
        if (step.state == DiffStep::Changed) {
            const WordDiff marked = diffWords(before.at(step.before), after.at(step.after), false);
            m_before[step.before] = marked.before;
            m_after[step.after] = marked.after;
        } else {
            if (step.before >= 0)
                m_before[step.before] = before.at(step.before).toHtmlEscaped();
            if (step.after >= 0)
                m_after[step.after] = after.at(step.after).toHtmlEscaped();
        }
    }
    show(steps, 3);
}

QVariant DiffLines::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const Row row = rowAt(index.row());
    if (row.folded > 0) {
        switch (role) {
        case ChangeRole: return QStringLiteral("fold");
        case CountRole: return row.folded;
        case BeforeNumberRole:
        case AfterNumberRole: return 0;
        case BeforeTextRole:
        case AfterTextRole: return QString();
        }
        return {};
    }
    const DiffStep &step = steps().at(row.step);
    switch (role) {
    case ChangeRole: return stateName(step.state);
    case CountRole: return 0;
    case BeforeNumberRole: return step.before + 1;
    case AfterNumberRole: return step.after + 1;
    case BeforeTextRole: return step.before >= 0 ? m_before.at(step.before) : QString();
    case AfterTextRole: return step.after >= 0 ? m_after.at(step.after) : QString();
    }
    return {};
}

QHash<int, QByteArray> DiffLines::roleNames() const
{
    return {{ChangeRole, "change"}, {CountRole, "count"}, {BeforeNumberRole, "beforeNumber"},
            {AfterNumberRole, "afterNumber"}, {BeforeTextRole, "beforeText"}, {AfterTextRole, "afterText"}};
}

// MarkdownDiff

MarkdownDiff::MarkdownDiff(QObject *parent)
    : QObject(parent), m_blocks(this), m_lines(this)
{
}

void MarkdownDiff::setBefore(const QString &text)
{
    if (text == m_before)
        return;
    m_before = text;
    emit textsChanged();
    schedule();
}

void MarkdownDiff::setAfter(const QString &text)
{
    if (text == m_after)
        return;
    m_after = text;
    emit textsChanged();
    schedule();
}

void MarkdownDiff::schedule()
{
    if (m_scheduled)
        return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this] {
        m_scheduled = false;
        compare();
    });
}

void MarkdownDiff::compare()
{
    const QStringList before = splitLines(m_before), after = splitLines(m_after);
    const QList<DiffStep> lines = diffLines(before, after);
    m_lines.compare(before, after, lines);
    m_added = int(std::count_if(lines.cbegin(), lines.cend(), [](const DiffStep &step) { return step.after >= 0 && step.state != DiffStep::Kept; }));
    m_removed = int(std::count_if(lines.cbegin(), lines.cend(), [](const DiffStep &step) { return step.before >= 0 && step.state != DiffStep::Kept; }));

    const QList<MarkdownBlock> from = parseMarkdown(m_before), to = parseMarkdown(m_after);
    const QList<DiffStep> blocks = diffBlocks(from, to);
    m_blocks.compare(from, to, blocks);
    // Each block's section: the heading at or above it, "" above the first.
    const auto sectionsOf = [](const QList<MarkdownBlock> &list) {
        QStringList sections;
        QString current;
        for (const MarkdownBlock &block : list) {
            if (block.kind == QLatin1String("heading"))
                current = QString::number(block.level) + block.plain;
            sections.append(current);
        }
        return sections;
    };
    const QStringList fromSections = sectionsOf(from), toSections = sectionsOf(to);
    QSet<QString> touched;
    for (const DiffStep &step : blocks) {
        if (step.state != DiffStep::Kept)
            touched.insert(step.after >= 0 ? toSections.at(step.after) : fromSections.at(step.before));
    }
    m_sections = int(touched.size());
    emit compared();
}

}
