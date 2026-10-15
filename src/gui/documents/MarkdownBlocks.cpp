#include "MarkdownBlocks.h"

#include <QHash>
#include <QRegularExpression>

#include <algorithm>
#include <utility>

namespace matome {

namespace {

struct Line {
    QString text;
    int number = 0;
};
using Lines = QList<Line>;

struct Ref {
    QString url;
    QString title;
};
using Refs = QHash<QString, Ref>;

const QRegularExpression &atxHeading()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$)"));
    return re;
}
const QRegularExpression &fenceOpen()
{
    static const QRegularExpression re(QStringLiteral(R"(^( {0,3})(`{3,}|~{3,})(.*)$)"));
    return re;
}
const QRegularExpression &fenceClose()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}(`{3,}|~{3,})[ \t]*$)"));
    return re;
}
const QRegularExpression &thematicBreak()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$)"));
    return re;
}
const QRegularExpression &quoteMarker()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}> ?)"));
    return re;
}
const QRegularExpression &listMarkerRe()
{
    static const QRegularExpression re(QStringLiteral(R"(^( {0,3})([-+*]|(\d{1,9})([.)]))(?=[ \t]|$))"));
    return re;
}
const QRegularExpression &setextUnderline()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}(=+|-+)[ \t]*$)"));
    return re;
}
const QRegularExpression &delimiterRow()
{
    static const QRegularExpression re(
            QStringLiteral(R"(^ {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$)"));
    return re;
}
const QRegularExpression &referenceDefinition()
{
    static const QRegularExpression re(QStringLiteral(
            R"re(^ {0,3}\[((?:[^\]\\]|\\.)+)\]:[ \t]*(<[^<>\n]*>|\S+)(?:[ \t]+("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\((?:[^()\\]|\\.)*\)))?[ \t]*$)re"));
    return re;
}
const QRegularExpression &commentStart()
{
    static const QRegularExpression re(QStringLiteral(R"(^ {0,3}<!--)"));
    return re;
}
const QRegularExpression &taskBox()
{
    static const QRegularExpression re(QStringLiteral(R"(^\[([ xX])\](?:[ \t]+|$))"));
    return re;
}

bool isBlank(const QString &text)
{
    return std::all_of(text.cbegin(), text.cend(), [](QChar c) { return c == u' ' || c == u'\t'; });
}

int indentOf(const QString &text)
{
    int count = 0;
    while (count < text.size() && text.at(count) == u' ')
        ++count;
    return count;
}

// Tabs in the leading whitespace become spaces to the next stop of four.
QString expandTabs(const QString &line)
{
    QString out;
    int at = 0;
    for (; at < line.size(); ++at) {
        if (line.at(at) == u' ')
            out.append(u' ');
        else if (line.at(at) == u'\t')
            out.append(QString(4 - out.size() % 4, u' '));
        else
            break;
    }
    return out + line.mid(at);
}

bool isAsciiPunct(QChar c)
{
    return c.unicode() < 128 && (c.isPunct() || QStringView(u"$+<=>^`|~").contains(c));
}

bool isPunctuation(QChar c)
{
    return c.isPunct() || c.isSymbol();
}

QString escaped(const QString &text)
{
    QString out;
    out.reserve(text.size());
    for (const QChar c : text) {
        if (c == u'&') out += QLatin1String("&amp;");
        else if (c == u'<') out += QLatin1String("&lt;");
        else if (c == u'>') out += QLatin1String("&gt;");
        else if (c == u'"') out += QLatin1String("&quot;");
        else out += c;
    }
    return out;
}

// `text` with backslash escapes of ASCII punctuation resolved.
QString unescaped(const QString &text)
{
    QString out;
    for (int at = 0; at < text.size(); ++at) {
        if (text.at(at) == u'\\' && at + 1 < text.size() && isAsciiPunct(text.at(at + 1)))
            ++at;
        out += text.at(at);
    }
    return out;
}

// A reference label as CommonMark matches it: case-folded, its whitespace
// collapsed.
QString labelKey(const QString &label)
{
    return label.simplified().toCaseFolded();
}

struct Marker {
    bool ok = false;
    bool ordered = false;
    QChar delimiter;
    int start = 0;
    int contentIndent = 0;
    QString first;
    bool empty = false;
};

Marker listMarker(const QString &line)
{
    const auto match = listMarkerRe().match(line);
    if (!match.hasMatch())
        return {};
    Marker marker;
    marker.ok = true;
    marker.ordered = match.hasCaptured(3);
    marker.delimiter = marker.ordered ? match.captured(4).at(0) : match.captured(2).at(0);
    marker.start = marker.ordered ? match.captured(3).toInt() : 0;
    const int end = int(match.capturedEnd(2));
    QString rest;
    int column = end;
    int at = end;
    for (; at < line.size() && (line.at(at) == u' ' || line.at(at) == u'\t'); ++at) {
        const int width = line.at(at) == u'\t' ? 4 - column % 4 : 1;
        rest.append(QString(width, u' '));
        column += width;
    }
    rest += line.mid(at);
    const int spaces = indentOf(rest);
    if (isBlank(rest)) {
        marker.empty = true;
        marker.contentIndent = end + 1;
    } else if (spaces >= 5) {
        marker.contentIndent = end + 1;
        marker.first = rest.mid(1);
    } else {
        marker.contentIndent = end + spaces;
        marker.first = rest.mid(spaces);
    }
    return marker;
}

// Whether `line` opens a fence: backtick fences take no backtick after.
bool opensFence(const QString &line, QRegularExpressionMatch *found = nullptr)
{
    const auto match = fenceOpen().match(line);
    if (!match.hasMatch() || (match.captured(2).startsWith(u'`') && match.captured(3).contains(u'`')))
        return false;
    if (found)
        *found = match;
    return true;
}

// Whether `line` starts a block that ends a paragraph before it.
bool interrupts(const QString &line)
{
    if (isBlank(line))
        return true;
    if (indentOf(line) >= 4)
        return false;
    if (atxHeading().match(line).hasMatch() || opensFence(line) || thematicBreak().match(line).hasMatch()
        || quoteMarker().match(line).hasMatch() || commentStart().match(line).hasMatch())
        return true;
    const Marker marker = listMarker(line);
    return marker.ok && !marker.empty && (!marker.ordered || marker.start == 1);
}

// Whether `line` may take lazy continuation lines: paragraph text.
bool continues(const QString &line)
{
    return !isBlank(line) && indentOf(line) < 4 && !atxHeading().match(line).hasMatch()
            && !opensFence(line) && !thematicBreak().match(line).hasMatch();
}

bool hasPipe(const QString &line)
{
    for (int at = 0; at < line.size(); ++at) {
        if (line.at(at) == u'\\')
            ++at;
        else if (line.at(at) == u'|')
            return true;
    }
    return false;
}

// A table row's cells, without the outer pipes; `\|` stays a pipe.
QStringList cellsOf(const QString &line)
{
    QString row = line.trimmed();
    if (row.startsWith(u'|'))
        row.remove(0, 1);
    if (row.endsWith(u'|') && !row.endsWith(QLatin1String("\\|")))
        row.chop(1);
    QStringList cells;
    QString cell;
    for (int at = 0; at < row.size(); ++at) {
        if (row.at(at) == u'\\' && at + 1 < row.size() && row.at(at + 1) == u'|') {
            cell += u'|';
            ++at;
        } else if (row.at(at) == u'|') {
            cells.append(cell.trimmed());
            cell.clear();
        } else {
            cell += row.at(at);
        }
    }
    cells.append(cell.trimmed());
    return cells;
}

bool tableAt(const Lines &lines, int at)
{
    if (at + 1 >= lines.size() || indentOf(lines.at(at).text) >= 4 || !hasPipe(lines.at(at).text)
        || !delimiterRow().match(lines.at(at + 1).text).hasMatch())
        return false;
    return cellsOf(lines.at(at).text).size() == cellsOf(lines.at(at + 1).text).size();
}

// A leaf block before its inline content renders, which waits for every
// reference definition of the document.
struct Pending {
    MarkdownBlock block;
    QString source;
    QList<QStringList> cells;
};

class BlockParser
{
public:
    QList<Pending> blocks;
    Refs refs;

    void parse(const Lines &lines, int quote, int indent)
    {
        int at = 0;
        const int count = int(lines.size());
        while (at < count) {
            const QString &text = lines.at(at).text;
            QRegularExpressionMatch match;
            if (isBlank(text)) {
                ++at;
            } else if (indentOf(text) >= 4) {
                at = indentedCode(lines, at, quote, indent);
            } else if (opensFence(text, &match)) {
                at = fencedCode(lines, at, match, quote, indent);
            } else if ((match = atxHeading().match(text)).hasMatch()) {
                Pending heading{block(QStringLiteral("heading"), lines.at(at), lines.at(at)), match.captured(2).trimmed(), {}};
                heading.block.level = int(match.capturedLength(1));
                add(std::move(heading), quote, indent);
                ++at;
            } else if (thematicBreak().match(text).hasMatch()) {
                add({block(QStringLiteral("rule"), lines.at(at), lines.at(at)), {}, {}}, quote, indent);
                ++at;
            } else if (quoteMarker().match(text).hasMatch()) {
                at = blockquote(lines, at, quote, indent);
            } else if (listMarker(text).ok) {
                at = list(lines, at, quote, indent);
            } else if (commentStart().match(text).hasMatch()) {
                while (at < count && !lines.at(at).text.contains(QLatin1String("-->")))
                    ++at;
                ++at;
            } else if (tableAt(lines, at)) {
                at = table(lines, at, quote, indent);
            } else {
                at = paragraph(lines, at, quote, indent);
            }
        }
    }

private:
    QString m_marker;

    static MarkdownBlock block(const QString &kind, const Line &first, const Line &last)
    {
        MarkdownBlock made;
        made.kind = kind;
        made.firstLine = first.number;
        made.lastLine = last.number;
        return made;
    }

    void add(Pending &&pending, int quote, int indent)
    {
        pending.block.quote = quote;
        pending.block.indent = indent;
        pending.block.marker = std::exchange(m_marker, {});
        blocks.append(std::move(pending));
    }

    int indentedCode(const Lines &lines, int start, int quote, int indent)
    {
        QStringList body;
        int last = start;
        int at = start;
        for (; at < lines.size() && (isBlank(lines.at(at).text) || indentOf(lines.at(at).text) >= 4); ++at) {
            body.append(lines.at(at).text.mid(4));
            if (!isBlank(lines.at(at).text))
                last = at;
        }
        Pending code{block(QStringLiteral("code"), lines.at(start), lines.at(last)), {}, {}};
        code.block.code = body.mid(0, last - start + 1).join(u'\n');
        add(std::move(code), quote, indent);
        return last + 1;
    }

    int fencedCode(const Lines &lines, int start, const QRegularExpressionMatch &open, int quote, int indent)
    {
        const int shift = int(open.capturedLength(1));
        const QString fence = open.captured(2);
        QStringList body;
        int at = start + 1;
        int last = int(lines.size()) - 1;
        for (; at < lines.size(); ++at) {
            const auto close = fenceClose().match(lines.at(at).text);
            if (close.hasMatch() && close.captured(1).at(0) == fence.at(0) && close.capturedLength(1) >= fence.size()) {
                last = at++;
                break;
            }
            body.append(lines.at(at).text.mid(std::min(shift, indentOf(lines.at(at).text))));
        }
        Pending code{block(QStringLiteral("code"), lines.at(start), lines.at(std::max(start, last))), {}, {}};
        code.block.code = body.join(u'\n');
        code.block.language = unescaped(open.captured(3).trimmed().section(u' ', 0, 0));
        add(std::move(code), quote, indent);
        return at;
    }

    int blockquote(const Lines &lines, int at, int quote, int indent)
    {
        Lines inner;
        for (; at < lines.size(); ++at) {
            const QString &text = lines.at(at).text;
            const auto marker = quoteMarker().match(text);
            if (marker.hasMatch())
                inner.append({expandTabs(text.mid(marker.capturedEnd())), lines.at(at).number});
            else if (!inner.isEmpty() && continues(inner.last().text) && !interrupts(text))
                inner.append(lines.at(at));
            else
                break;
        }
        parse(inner, quote + 1, indent);
        return at;
    }

    int list(const Lines &lines, int at, int quote, int indent)
    {
        const Marker first = listMarker(lines.at(at).text);
        int number = first.start;
        while (at < lines.size()) {
            const Marker marker = listMarker(lines.at(at).text);
            if (!marker.ok || marker.ordered != first.ordered || marker.delimiter != first.delimiter
                || thematicBreak().match(lines.at(at).text).hasMatch())
                break;
            Lines item{{marker.first, lines.at(at).number}};
            for (++at; at < lines.size(); ++at) {
                const QString &text = lines.at(at).text;
                if (isBlank(text))
                    item.append({QString(), lines.at(at).number});
                else if (indentOf(text) >= marker.contentIndent)
                    item.append({text.mid(marker.contentIndent), lines.at(at).number});
                else if (!listMarker(text).ok && continues(item.last().text) && !interrupts(text))
                    item.append(lines.at(at));
                else
                    break;
            }
            while (item.size() > 1 && isBlank(item.last().text))
                item.removeLast();
            m_marker = first.ordered ? QString::number(number) + first.delimiter : QStringLiteral("•");
            const auto task = taskBox().match(item.first().text);
            if (task.hasMatch()) {
                m_marker = task.captured(1) == QLatin1String(" ") ? QStringLiteral("☐") : QStringLiteral("☑");
                item.first().text = item.first().text.mid(task.capturedEnd());
            }
            if (std::all_of(item.cbegin(), item.cend(), [](const Line &line) { return isBlank(line.text); }))
                add({block(QStringLiteral("paragraph"), item.first(), item.first()), {}, {}}, quote, indent + 1);
            else
                parse(item, quote, indent + 1);
            m_marker.clear();
            ++number;
            int next = at;
            while (next < lines.size() && isBlank(lines.at(next).text))
                ++next;
            const Marker following = next < lines.size() ? listMarker(lines.at(next).text) : Marker();
            if (!following.ok || following.ordered != first.ordered || following.delimiter != first.delimiter)
                break;
            at = next;
        }
        return at;
    }

    int table(const Lines &lines, int at, int quote, int indent)
    {
        const QStringList head = cellsOf(lines.at(at).text);
        const qsizetype columns = head.size();
        Pending made{block(QStringLiteral("table"), lines.at(at), lines.at(at + 1)), {}, {head}};
        for (const QString &cell : cellsOf(lines.at(at + 1).text)) {
            const bool left = cell.startsWith(u':'), right = cell.endsWith(u':');
            made.block.align.append(left && right ? QStringLiteral("center") : right ? QStringLiteral("right")
                                                  : left ? QStringLiteral("left") : QString());
        }
        for (at += 2; at < lines.size() && !isBlank(lines.at(at).text)
                      && !(indentOf(lines.at(at).text) < 4 && interrupts(lines.at(at).text)); ++at) {
            QStringList cells = cellsOf(lines.at(at).text);
            cells.resize(columns);
            made.cells.append(cells);
            made.block.lastLine = lines.at(at).number;
        }
        add(std::move(made), quote, indent);
        return at;
    }

    int paragraph(const Lines &lines, int start, int quote, int indent)
    {
        QStringList parts{lines.at(start).text.mid(indentOf(lines.at(start).text))};
        int at = start + 1;
        int level = 0;
        for (; at < lines.size(); ++at) {
            const QString &text = lines.at(at).text;
            if (isBlank(text))
                break;
            if (indentOf(text) < 4) {
                const auto underline = setextUnderline().match(text);
                if (underline.hasMatch()) {
                    level = underline.captured(1).startsWith(u'=') ? 1 : 2;
                    break;
                }
                if (interrupts(text) || tableAt(lines, at))
                    break;
            }
            parts.append(text.mid(indentOf(text)));
        }
        int first = start;
        while (!parts.isEmpty()) {
            const auto definition = referenceDefinition().match(parts.first());
            if (!definition.hasMatch())
                break;
            QString url = definition.captured(2);
            if (url.startsWith(u'<'))
                url = url.mid(1, url.size() - 2);
            const QString key = labelKey(definition.captured(1));
            const QString title = definition.captured(3);
            if (!refs.contains(key))
                refs.insert(key, {unescaped(url), unescaped(title.mid(1, title.size() - 2))});
            parts.removeFirst();
            ++first;
        }
        // An underline below definitions only underlines nothing: it is
        // read again as a block of its own.
        if (parts.isEmpty())
            return at;
        Pending made{block(level > 0 ? QStringLiteral("heading") : QStringLiteral("paragraph"), lines.at(first),
                           lines.at(level > 0 ? at : at - 1)), parts.join(u'\n'), {}};
        made.block.level = level;
        add(std::move(made), quote, indent);
        return level > 0 ? at + 1 : at;
    }
};

// One piece of inline content: text, finished markup, an emphasis
// delimiter run, a `[` or `![` that may open a link, or an image.
struct Node {
    enum Type { Text, Html, Delimiter, Bracket, Image };
    explicit Node(Type type = Text, const QString &html = {}, const QString &plain = {})
        : type(type), html(html), plain(plain) {}
    Type type;
    QString html;
    QString plain;
    bool link = false;
    // Delimiter
    QChar character;
    int count = 0;
    int original = 0;
    bool canOpen = false;
    bool canClose = false;
    QStringList openTags;
    QStringList closeTags;
    // Bracket
    bool image = false;
    bool active = true;
    int start = 0;
    // Image
    QString source;
    QString title;
};

struct Target {
    QString url;
    QString title;
};

class InlineParser
{
public:
    InlineParser(const QString &text, const Refs &refs) : m_text(text), m_refs(refs)
    {
        while (m_at < m_text.size())
            step();
        emphasis(0);
    }

    QList<Node> nodes;

    // The finished markup and text of `from` to `to`; links inside a link
    // keep only their text.
    static std::pair<QString, QString> render(const QList<Node> &nodes, qsizetype from, qsizetype to, bool inLink)
    {
        QString html, plain;
        for (qsizetype at = from; at < to; ++at) {
            const Node &node = nodes.at(at);
            switch (node.type) {
            case Node::Text:
                html += escaped(node.plain);
                plain += node.plain;
                break;
            case Node::Html:
                html += inLink && node.link ? escaped(node.plain) : node.html;
                plain += node.plain;
                break;
            case Node::Delimiter: {
                const QString rest(node.count, node.character);
                html += node.closeTags.join(QString()) + escaped(rest) + node.openTags.join(QString());
                plain += rest;
                break;
            }
            case Node::Bracket:
                html += escaped(node.plain);
                plain += node.plain;
                break;
            case Node::Image:
                html += escaped(node.plain);
                plain += node.plain;
                break;
            }
        }
        return {html, plain};
    }

private:
    const QString &m_text;
    const Refs &m_refs;
    qsizetype m_at = 0;

    QChar at(qsizetype index) const { return index >= 0 && index < m_text.size() ? m_text.at(index) : QChar(u'\n'); }

    void text(const QString &value)
    {
        if (!nodes.isEmpty() && nodes.last().type == Node::Text)
            nodes.last().plain += value;
        else
            nodes.append(Node(Node::Text, {}, value));
    }

    void markup(const QString &html, const QString &plain, bool link = false)
    {
        Node node(Node::Html, html, plain);
        node.link = link;
        nodes.append(node);
    }

    void step()
    {
        const QChar c = m_text.at(m_at);
        if (c == u'\\') {
            if (at(m_at + 1) == u'\n' && m_at + 1 < m_text.size()) {
                markup(QStringLiteral("<br>"), QStringLiteral("\n"));
                m_at += 2;
            } else if (m_at + 1 < m_text.size() && isAsciiPunct(at(m_at + 1))) {
                text(at(m_at + 1));
                m_at += 2;
            } else {
                text(c);
                ++m_at;
            }
        } else if (c == u'`') {
            codeSpan();
        } else if (c == u'*' || c == u'_' || c == u'~') {
            delimiterRun(c);
        } else if (c == u'!' && at(m_at + 1) == u'[') {
            bracket(true);
        } else if (c == u'[') {
            bracket(false);
        } else if (c == u']') {
            closeBracket();
        } else if (c == u'<') {
            if (!autolink()) {
                text(QStringLiteral("<"));
                ++m_at;
            }
        } else if (c == u'&') {
            entity();
        } else if (c == u'\n') {
            lineBreak();
        } else if (!bareLink()) {
            text(c);
            ++m_at;
        }
    }

    void codeSpan()
    {
        qsizetype run = 0;
        while (at(m_at + run) == u'`' && m_at + run < m_text.size())
            ++run;
        for (qsizetype close = m_text.indexOf(u'`', m_at + run); close >= 0; close = m_text.indexOf(u'`', close)) {
            qsizetype length = 0;
            while (close + length < m_text.size() && m_text.at(close + length) == u'`')
                ++length;
            if (length == run) {
                QString code = m_text.mid(m_at + run, close - m_at - run).replace(u'\n', u' ');
                if (code.size() > 1 && code.startsWith(u' ') && code.endsWith(u' ') && !isBlank(code))
                    code = code.mid(1, code.size() - 2);
                markup(QStringLiteral("<code>") + escaped(code) + QStringLiteral("</code>"), code);
                m_at = close + length;
                return;
            }
            close += length;
        }
        text(QString(run, u'`'));
        m_at += run;
    }

    void delimiterRun(QChar c)
    {
        qsizetype end = m_at;
        while (end < m_text.size() && m_text.at(end) == c)
            ++end;
        const int run = int(end - m_at);
        const QChar before = at(m_at - 1), after = at(end);
        m_at = end;
        if (c == u'~' && run != 2) {
            text(QString(run, c));
            return;
        }
        const bool left = !after.isSpace() && (!isPunctuation(after) || before.isSpace() || isPunctuation(before));
        const bool right = !before.isSpace() && (!isPunctuation(before) || after.isSpace() || isPunctuation(after));
        Node node(Node::Delimiter);
        node.character = c;
        node.count = node.original = run;
        node.canOpen = c == u'_' ? left && (!right || isPunctuation(before)) : left;
        node.canClose = c == u'_' ? right && (!left || isPunctuation(after)) : right;
        nodes.append(node);
    }

    void bracket(bool image)
    {
        Node node(Node::Bracket, {}, image ? QStringLiteral("![") : QStringLiteral("["));
        node.image = image;
        m_at += image ? 2 : 1;
        node.start = int(m_at);
        nodes.append(node);
    }

    void closeBracket()
    {
        qsizetype opener = nodes.size() - 1;
        while (opener >= 0 && nodes.at(opener).type != Node::Bracket)
            --opener;
        if (opener < 0 || !nodes.at(opener).active) {
            if (opener >= 0)
                nodes[opener].type = Node::Text;
            text(QStringLiteral("]"));
            ++m_at;
            return;
        }
        Target target;
        qsizetype end = 0;
        if (!inlineLink(m_at + 1, target, end) && !reference(nodes.at(opener).start, m_at + 1, target, end)) {
            nodes[opener].type = Node::Text;
            text(QStringLiteral("]"));
            ++m_at;
            return;
        }
        emphasis(opener + 1);
        const bool image = nodes.at(opener).image;
        const auto [inner, plain] = render(nodes, opener + 1, nodes.size(), true);
        nodes.resize(opener);
        if (image) {
            Node node(Node::Image, {}, plain);
            node.source = target.url;
            node.title = target.title;
            nodes.append(node);
        } else {
            const QString title = target.title.isEmpty() ? QString() : QStringLiteral(" title=\"%1\"").arg(escaped(target.title));
            markup(QStringLiteral("<a href=\"%1\"%2>%3</a>").arg(escaped(target.url), title, inner), plain, true);
            for (Node &node : nodes)
                if (node.type == Node::Bracket && !node.image)
                    node.active = false;
        }
        m_at = end;
    }

    void skipSpaces(qsizetype &index) const
    {
        bool newline = false;
        while (index < m_text.size() && (m_text.at(index) == u' ' || m_text.at(index) == u'\t'
                                         || (m_text.at(index) == u'\n' && !std::exchange(newline, true))))
            ++index;
    }

    bool inlineLink(qsizetype index, Target &target, qsizetype &end) const
    {
        if (at(index) != u'(' || index >= m_text.size())
            return false;
        qsizetype cursor = index + 1;
        skipSpaces(cursor);
        QString destination;
        if (at(cursor) == u'<') {
            const qsizetype close = m_text.indexOf(u'>', cursor);
            const qsizetype newline = m_text.indexOf(u'\n', cursor);
            if (close < 0 || (newline >= 0 && newline < close))
                return false;
            destination = m_text.mid(cursor + 1, close - cursor - 1);
            cursor = close + 1;
        } else {
            const qsizetype start = cursor;
            int depth = 0;
            for (; cursor < m_text.size(); ++cursor) {
                const QChar c = m_text.at(cursor);
                if (c == u'\\' && isAsciiPunct(at(cursor + 1)))
                    ++cursor;
                else if (c.isSpace() || c.unicode() < 0x20)
                    break;
                else if (c == u'(')
                    ++depth;
                else if (c == u')' && depth-- == 0)
                    break;
            }
            destination = m_text.mid(start, cursor - start);
        }
        const qsizetype beforeTitle = cursor;
        skipSpaces(cursor);
        QString title;
        const QChar open = at(cursor);
        if ((open == u'"' || open == u'\'' || open == u'(') && cursor > beforeTitle) {
            const QChar close = open == u'(' ? QChar(u')') : open;
            qsizetype index2 = cursor + 1;
            for (; index2 < m_text.size() && m_text.at(index2) != close; ++index2)
                if (m_text.at(index2) == u'\\')
                    ++index2;
            if (index2 >= m_text.size())
                return false;
            title = m_text.mid(cursor + 1, index2 - cursor - 1);
            cursor = index2 + 1;
            skipSpaces(cursor);
        }
        if (at(cursor) != u')' || cursor >= m_text.size())
            return false;
        target = {unescaped(destination), unescaped(title)};
        end = cursor + 1;
        return true;
    }

    bool reference(qsizetype labelStart, qsizetype index, Target &target, qsizetype &end) const
    {
        QString label = m_text.mid(labelStart, index - 1 - labelStart);
        end = index;
        if (at(index) == u'[') {
            const qsizetype close = m_text.indexOf(u']', index);
            if (close < 0)
                return false;
            const QString second = m_text.mid(index + 1, close - index - 1);
            if (!isBlank(second))
                label = second;
            end = close + 1;
        }
        const auto found = m_refs.constFind(labelKey(label));
        if (found == m_refs.constEnd())
            return false;
        target = {found->url, found->title};
        return true;
    }

    bool autolink()
    {
        static const QRegularExpression uri(QStringLiteral(R"(\G<([A-Za-z][A-Za-z0-9+.-]{1,31}:[^\s<>]*)>)"));
        static const QRegularExpression email(QStringLiteral(
                R"(\G<([A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*)>)"));
        auto match = uri.match(m_text, m_at);
        QString href;
        if (match.hasMatch()) {
            href = match.captured(1);
        } else if ((match = email.match(m_text, m_at)).hasMatch()) {
            href = QStringLiteral("mailto:") + match.captured(1);
        } else {
            return false;
        }
        markup(QStringLiteral("<a href=\"%1\">%2</a>").arg(escaped(href), escaped(match.captured(1))), match.captured(1), true);
        m_at = match.capturedEnd();
        return true;
    }

    // A web address written out: `https://…`, `http://…`, or `www.…` after
    // a space, the start, or an opening delimiter.
    bool bareLink()
    {
        const QChar before = at(m_at - 1);
        if (!(m_at == 0 || before.isSpace() || QStringView(u"*_~(").contains(before)))
            return false;
        const QStringView rest = QStringView(m_text).mid(m_at);
        const bool web = rest.startsWith(QLatin1String("www."), Qt::CaseInsensitive);
        if (!web && !rest.startsWith(QLatin1String("http://"), Qt::CaseInsensitive)
            && !rest.startsWith(QLatin1String("https://"), Qt::CaseInsensitive))
            return false;
        qsizetype end = m_at;
        while (end < m_text.size() && !m_text.at(end).isSpace() && m_text.at(end) != u'<')
            ++end;
        QString url = m_text.mid(m_at, end - m_at);
        for (;;) {
            if (!url.isEmpty() && QStringView(u"?!.,:*_~'\"").contains(url.back()))
                url.chop(1);
            else if (url.endsWith(u')') && url.count(u'(') < url.count(u')'))
                url.chop(1);
            else
                break;
        }
        if (url.size() <= (web ? 4 : 8))
            return false;
        const QString href = web ? QStringLiteral("http://") + url : url;
        markup(QStringLiteral("<a href=\"%1\">%2</a>").arg(escaped(href), escaped(url)), url, true);
        m_at += url.size();
        return true;
    }

    void entity()
    {
        static const QRegularExpression re(QStringLiteral(R"(\G&(?:#([0-9]{1,7})|#[xX]([0-9A-Fa-f]{1,6})|([A-Za-z][A-Za-z0-9]{1,31}));)"));
        static const QHash<QString, QString> named{{QStringLiteral("amp"), QStringLiteral("&")}, {QStringLiteral("lt"), QStringLiteral("<")},
                                                   {QStringLiteral("gt"), QStringLiteral(">")}, {QStringLiteral("quot"), QStringLiteral("\"")},
                                                   {QStringLiteral("apos"), QStringLiteral("'")}, {QStringLiteral("nbsp"), QStringLiteral(" ")}};
        const auto match = re.match(m_text, m_at);
        if (!match.hasMatch()) {
            text(QStringLiteral("&"));
            ++m_at;
            return;
        }
        const uint code = match.hasCaptured(1) ? match.captured(1).toUInt() : match.hasCaptured(2) ? match.captured(2).toUInt(nullptr, 16) : 0;
        if (match.hasCaptured(3) && !named.contains(match.captured(3)))
            markup(match.captured(0), match.captured(0));
        else
            text(match.hasCaptured(3) ? named.value(match.captured(3))
                                      : code > 0 && code <= 0x10FFFF ? QString::fromUcs4(reinterpret_cast<const char32_t *>(&code), 1)
                                                                     : QString(QChar::ReplacementCharacter));
        m_at = match.capturedEnd();
    }

    void lineBreak()
    {
        int spaces = 0;
        if (!nodes.isEmpty() && nodes.last().type == Node::Text) {
            QString &last = nodes.last().plain;
            while (last.endsWith(u' ')) {
                last.chop(1);
                ++spaces;
            }
        }
        if (spaces >= 2)
            markup(QStringLiteral("<br>"), QStringLiteral("\n"));
        else
            text(QStringLiteral(" "));
        ++m_at;
    }

    // Pairs the delimiter runs from `from` on, CommonMark's way: each
    // closer with the nearest opener of its kind, `**` before `*`, and
    // runs whose lengths sum to a multiple of three kept apart.
    void emphasis(qsizetype from)
    {
        for (qsizetype closer = from; closer < nodes.size(); ++closer) {
            if (nodes.at(closer).type != Node::Delimiter || !nodes.at(closer).canClose || nodes.at(closer).count == 0)
                continue;
            Node &close = nodes[closer];
            bool found = false;
            for (qsizetype opener = closer - 1; opener >= from && !found; --opener) {
                Node &open = nodes[opener];
                if (open.type != Node::Delimiter || open.character != close.character || !open.canOpen || open.count == 0)
                    continue;
                if (close.character != u'~' && (open.canClose || close.canOpen) && (open.original + close.original) % 3 == 0
                    && !(open.original % 3 == 0 && close.original % 3 == 0))
                    continue;
                const int use = close.character == u'~' || (open.count >= 2 && close.count >= 2) ? 2 : 1;
                const QString tag = close.character == u'~' ? QStringLiteral("s") : use == 2 ? QStringLiteral("b") : QStringLiteral("i");
                open.count -= use;
                close.count -= use;
                open.openTags.prepend(QStringLiteral("<%1>").arg(tag));
                close.closeTags.append(QStringLiteral("</%1>").arg(tag));
                for (qsizetype between = opener + 1; between < closer; ++between)
                    nodes[between].canOpen = nodes[between].canClose = false;
                found = true;
            }
            if (found && close.count > 0)
                --closer;
            else if (!found && !close.canOpen)
                close.canClose = false;
        }
    }
};

// The paragraph or heading `pending` as blocks: an image outside any
// emphasis or link stands as a block of its own between the text around it.
void finishInline(const Pending &pending, const Refs &refs, QList<MarkdownBlock> &out)
{
    const InlineParser parser(pending.source, refs);
    const QList<Node> &nodes = parser.nodes;
    const auto text = [&](qsizetype from, qsizetype to) {
        auto [html, plain] = InlineParser::render(nodes, from, to, false);
        static const QRegularExpression edges(QStringLiteral(R"(^(?:\s|<br>)+|(?:\s|<br>)+$)"));
        html.remove(edges);
        return std::pair{html, plain.trimmed()};
    };
    bool split = false;
    MarkdownBlock block = pending.block;
    if (block.kind == QLatin1String("paragraph")) {
        int depth = 0;
        qsizetype from = 0;
        for (qsizetype at = 0; at < nodes.size(); ++at) {
            const Node &node = nodes.at(at);
            if (node.type == Node::Delimiter)
                depth += int(node.openTags.size() - node.closeTags.size());
            if (node.type != Node::Image || depth != 0)
                continue;
            const auto [html, plain] = text(from, at);
            if (!plain.isEmpty()) {
                MarkdownBlock before = block;
                before.html = html;
                before.plain = plain;
                out.append(before);
                block.marker.clear();
            }
            MarkdownBlock image = block;
            image.kind = QStringLiteral("image");
            image.source = node.source;
            image.alt = node.plain;
            image.title = node.title;
            image.plain = node.plain;
            out.append(image);
            block.marker.clear();
            from = at + 1;
            split = true;
        }
        const auto [html, plain] = text(from, nodes.size());
        if (split && plain.isEmpty())
            return;
        block.html = html;
        block.plain = plain;
    } else {
        const auto [html, plain] = text(0, nodes.size());
        block.html = html;
        block.plain = plain;
    }
    out.append(block);
}

} // namespace

QList<MarkdownBlock> parseMarkdown(const QString &markdown)
{
    Lines lines;
    int number = 0;
    for (const QStringView line : QStringView(markdown).split(u'\n')) {
        QString text = line.toString();
        if (text.endsWith(u'\r'))
            text.chop(1);
        lines.append({expandTabs(text), ++number});
    }
    BlockParser parser;
    parser.parse(lines, 0, 0);
    QList<MarkdownBlock> blocks;
    for (const Pending &pending : std::as_const(parser.blocks)) {
        if (pending.block.kind == QLatin1String("heading") || pending.block.kind == QLatin1String("paragraph")) {
            finishInline(pending, parser.refs, blocks);
            continue;
        }
        MarkdownBlock block = pending.block;
        if (block.kind == QLatin1String("code")) {
            block.plain = block.code;
        } else if (block.kind == QLatin1String("table")) {
            QStringList text;
            for (const QStringList &row : pending.cells) {
                QStringList html, plain;
                for (const QString &cell : row) {
                    const InlineParser parsed(cell, parser.refs);
                    const auto [markup, text] = InlineParser::render(parsed.nodes, 0, parsed.nodes.size(), false);
                    html.append(markup.trimmed());
                    plain.append(text.trimmed());
                }
                block.rows.append(html);
                text.append(plain.join(u'\t'));
            }
            block.plain = text.join(u'\n');
        }
        blocks.append(block);
    }
    return blocks;
}

void MarkdownBlocks::setMarkdown(const QString &markdown)
{
    if (markdown == m_markdown)
        return;
    m_markdown = markdown;
    QList<MarkdownBlock> next = parseMarkdown(markdown);
    // Only the blocks between the unchanged head and tail change, so the
    // view keeps the delegates and the place of the rest.
    const auto same = [](const MarkdownBlock &a, const MarkdownBlock &b) {
        return a.kind == b.kind && a.html == b.html && a.code == b.code && a.language == b.language && a.level == b.level
                && a.quote == b.quote && a.indent == b.indent && a.marker == b.marker && a.source == b.source
                && a.alt == b.alt && a.title == b.title && a.rows == b.rows && a.align == b.align;
    };
    qsizetype head = 0;
    while (head < m_blocks.size() && head < next.size() && same(m_blocks.at(head), next.at(head)))
        ++head;
    qsizetype tail = 0;
    while (tail < m_blocks.size() - head && tail < next.size() - head
           && same(m_blocks.at(m_blocks.size() - 1 - tail), next.at(next.size() - 1 - tail)))
        ++tail;
    const int oldEnd = int(m_blocks.size() - tail), newEnd = int(next.size() - tail);
    if (oldEnd > head) {
        beginRemoveRows({}, int(head), oldEnd - 1);
        m_blocks.remove(head, oldEnd - head);
        endRemoveRows();
    }
    if (newEnd > head) {
        beginInsertRows({}, int(head), newEnd - 1);
        m_blocks.insert(head, newEnd - head, MarkdownBlock());
        std::copy(next.cbegin() + head, next.cbegin() + newEnd, m_blocks.begin() + head);
        endInsertRows();
    }
    for (qsizetype at = 0; at < m_blocks.size(); ++at) {
        if (m_blocks.at(at).firstLine != next.at(at).firstLine || m_blocks.at(at).lastLine != next.at(at).lastLine) {
            m_blocks[at] = next.at(at);
            emit dataChanged(index(int(at)), index(int(at)), {FirstLineRole, LastLineRole});
        }
    }
    emit markdownChanged();
}

bool externalImage(const MarkdownBlock &block)
{
    static const QRegularExpression web(QStringLiteral("^(?:https?:)?//"), QRegularExpression::CaseInsensitiveOption);
    return block.kind == QLatin1String("image") && web.match(block.source).hasMatch();
}

bool MarkdownBlocks::externalImages() const
{
    return std::any_of(m_blocks.cbegin(), m_blocks.cend(), externalImage);
}

QString MarkdownBlocks::plainAt(int index) const
{
    return index >= 0 && index < m_blocks.size() ? m_blocks.at(index).plain : QString();
}

int MarkdownBlocks::blockAt(int line) const
{
    const auto after = std::upper_bound(m_blocks.cbegin(), m_blocks.cend(), line,
                                        [](int at, const MarkdownBlock &block) { return at < block.firstLine; });
    return m_blocks.isEmpty() ? -1 : std::max(0, int(after - m_blocks.cbegin()) - 1);
}

int MarkdownBlocks::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_blocks.size());
}

QVariant MarkdownBlocks::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_blocks.size())
        return {};
    switch (role) {
    case ChangeRole:
    case MarkedRole: return QString();
    case CountRole: return 0;
    case RowStatesRole: return QStringList();
    }
    return blockData(m_blocks.at(index.row()), role);
}

QVariant MarkdownBlocks::blockData(const MarkdownBlock &block, int role)
{
    switch (role) {
    case KindRole: return block.kind;
    case HtmlRole: return block.html;
    case PlainRole: return block.plain;
    case CodeRole: return block.code;
    case LanguageRole: return block.language;
    case LevelRole: return block.level;
    case QuoteRole: return block.quote;
    case IndentRole: return block.indent;
    case MarkerRole: return block.marker;
    case SourceRole: return block.source;
    case AltRole: return block.alt;
    case TitleRole: return block.title;
    case RowsRole: {
        QVariantList rows;
        for (const QStringList &row : block.rows)
            rows.append(row);
        return rows;
    }
    case AlignRole: return block.align;
    case FirstLineRole: return block.firstLine;
    case LastLineRole: return block.lastLine;
    }
    return {};
}

QHash<int, QByteArray> MarkdownBlocks::roleNames() const
{
    return blockRoles();
}

QHash<int, QByteArray> MarkdownBlocks::blockRoles()
{
    return {{KindRole, "kind"}, {HtmlRole, "html"}, {PlainRole, "plain"}, {CodeRole, "code"},
            {LanguageRole, "language"}, {LevelRole, "level"}, {QuoteRole, "quote"}, {IndentRole, "indent"},
            {MarkerRole, "marker"}, {SourceRole, "source"}, {AltRole, "alt"}, {TitleRole, "title"},
            {RowsRole, "rows"}, {AlignRole, "align"}, {FirstLineRole, "firstLine"},
            {LastLineRole, "lastLine"}, {ChangeRole, "change"}, {MarkedRole, "marked"}, {CountRole, "count"},
            {RowStatesRole, "rowStates"}};
}

}
