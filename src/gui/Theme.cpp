#include "Theme.h"

#include "Languages.h"

#include <algorithm>

#include <QCoreApplication>
#include <QDir>
#include <QEasingCurve>
#include <QEvent>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QHash>
#include <QKeyEvent>
#include <QLocale>
#include <QProcessEnvironment>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QSettings>
#include <QStyleHints>
#include <QTextStream>
#include <QVariantMap>

#include <cmath>

#include <optional>

#ifdef Q_OS_WASM
#include <emscripten.h>
#endif
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

namespace matome {
namespace {

QString configHome()
{
    const QString config =
        QProcessEnvironment::systemEnvironment().value(QStringLiteral("XDG_CONFIG_HOME"));
    return config.isEmpty() ? QDir::homePath() + QStringLiteral("/.config") : config;
}

QString currentThemePath()
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString state = env.value(QStringLiteral("XDG_STATE_HOME"));
    if (state.isEmpty())
        state = QDir::homePath() + QStringLiteral("/.local/state");
    return state + QStringLiteral("/omarchy/current/theme");
}

QStringList roundingPaths()
{
    QString omarchy = QProcessEnvironment::systemEnvironment().value(QStringLiteral("OMARCHY_PATH"));
    if (omarchy.isEmpty())
        omarchy = QStringLiteral("/usr/share/omarchy");
    return {configHome() + QStringLiteral("/hypr/looknfeel.lua"),
            omarchy + QStringLiteral("/default/hypr/looknfeel.lua")};
}

std::optional<int> readRounding(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return std::nullopt;
    static const QRegularExpression key(QStringLiteral("^rounding\\s*=\\s*(\\d+)"));
    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.startsWith(QLatin1String("--")))
            continue;
        const QRegularExpressionMatch match = key.match(line);
        if (match.hasMatch())
            return match.captured(1).toInt();
    }
    return std::nullopt;
}

#if !defined(Q_OS_WASM) && !defined(Q_OS_ANDROID)
// GTK's switch is what GNOME, Omarchy, and most Linux desktops write when
// the user turns animations off.
std::optional<bool> readAnimations(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return std::nullopt;
    static const QRegularExpression key(QStringLiteral("^gtk-enable-animations\\s*=\\s*(\\S+)"));
    QTextStream stream(&file);
    while (!stream.atEnd()) {
        const QRegularExpressionMatch match = key.match(stream.readLine().trimmed());
        if (match.hasMatch()) {
            const QString value = match.captured(1).toLower();
            return value != QLatin1String("false") && value != QLatin1String("0");
        }
    }
    return std::nullopt;
}
#endif

QHash<QString, QString> readFlatToml(const QString &path)
{
    QHash<QString, QString> values;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return values;
    QTextStream stream(&file);
    while (!stream.atEnd()) {
        QString line = stream.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))
            || line.startsWith(QLatin1Char('[')))
            continue;
        const int equals = line.indexOf(QLatin1Char('='));
        if (equals < 0)
            continue;
        const QString key = line.left(equals).trimmed();
        QString value = line.mid(equals + 1).trimmed();
        if (value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"')))
            value = value.mid(1, value.size() - 2);
        values.insert(key, value);
    }
    return values;
}

QColor colourOr(const QHash<QString, QString> &values, const QString &key,
                const QColor &fallback)
{
    const QColor parsed(values.value(key));
    return parsed.isValid() ? parsed : fallback;
}

qreal luminance(const QColor &of)
{
    const auto channel = [](qreal raw) {
        return raw <= 0.03928 ? raw / 12.92 : std::pow((raw + 0.055) / 1.055, 2.4);
    };
    return 0.2126 * channel(of.redF()) + 0.7152 * channel(of.greenF())
            + 0.0722 * channel(of.blueF());
}

QColor mix(const QColor &from, const QColor &toward, qreal amount)
{
    const auto step = [amount](float a, float b) { return a + (b - a) * amount; };
    return QColor::fromRgbF(step(from.redF(), toward.redF()), step(from.greenF(), toward.greenF()),
                            step(from.blueF(), toward.blueF()),
                            step(from.alphaF(), toward.alphaF()));
}

Theme::Palette blend(const Theme::Palette &from, const Theme::Palette &to, qreal amount)
{
    return {mix(from.accent, to.accent, amount),
            mix(from.accentDark, to.accentDark, amount),
            mix(from.accentSoft, to.accentSoft, amount),
            mix(from.accentText, to.accentText, amount),
            mix(from.accentLine, to.accentLine, amount),
            mix(from.onAccent, to.onAccent, amount),
            mix(from.background, to.background, amount),
            mix(from.surface, to.surface, amount),
            mix(from.border, to.border, amount),
            mix(from.textPrimary, to.textPrimary, amount),
            mix(from.textSecondary, to.textSecondary, amount),
            mix(from.textMuted, to.textMuted, amount),
            mix(from.subtleFill, to.subtleFill, amount),
            mix(from.subtleFillStrong, to.subtleFillStrong, amount),
            mix(from.failed, to.failed, amount),
            mix(from.added, to.added, amount)};
}

constexpr char kLanguageKey[] = "theme/language";

bool speaks(const QString &code)
{
    for (const Language &language : kLanguages) {
        if (code == QLatin1String(language.code))
            return true;
    }
    return false;
}

// The landing's `--ease`: cubic-bezier(0.2, 0.7, 0.1, 1).
constexpr double kEase[] = {0.2, 0.7, 0.1, 1.0};

const QColor kSpaceAccents[8] = {
    QColor(0xC8, 0xA2, 0x4E),
    QColor(0x7E, 0x9B, 0x6E),
    QColor(0x6E, 0x86, 0xA8),
    QColor(0xC6, 0x8A, 0x5E),
    QColor(0xBC, 0x84, 0x97),
    QColor(0x95, 0x87, 0xAE),
    QColor(0x6F, 0xA3, 0x9A),
    QColor(0xC2, 0x70, 0x5F),
};

} // namespace

Theme::Theme(QObject *parent)
    : QObject(parent)
    , m_themePath(currentThemePath())
    , m_roundingPaths(roundingPaths())
{
    registerFonts();

    QEasingCurve curve(QEasingCurve::BezierSpline);
    curve.addCubicBezierSegment(QPointF(kEase[0], kEase[1]), QPointF(kEase[2], kEase[3]),
                                QPointF(1.0, 1.0));
    m_fade.setEasingCurve(curve);
    m_fade.setStartValue(0.0);
    m_fade.setEndValue(1.0);
    connect(&m_fade, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_shown = blend(m_from, m_palette, value.toReal());
        emit paletteChanged();
    });
    connect(&m_fade, &QVariantAnimation::finished, this, [this] {
        m_shown = m_palette;
        emit paletteChanged();
    });

    m_language = resolveLanguage(QSettings().value(kLanguageKey).toString(),
                                 QLocale::system().uiLanguages());
    applyLanguage();
    loadMode();
    reload();

    const auto rearm = [this] {
        watch();
        reload();
    };
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, rearm);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, rearm);
    watch();

    if (qGuiApp) {
        qGuiApp->installEventFilter(this);
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this,
                [this] {
                    if (m_mode == QLatin1String("system") && !m_usingOmarchy)
                        reload();
                });
    }
}

QStringList Theme::registerFonts()
{
    static const QStringList families = [] {
        QStringList added;
        const QDir dir(QStringLiteral(":/fonts"));
        const QStringList files = dir.entryList({QStringLiteral("*.ttf")}, QDir::Files, QDir::Name);
        for (const QString &file : files) {
            const int id = QFontDatabase::addApplicationFont(dir.filePath(file));
            for (const QString &family : QFontDatabase::applicationFontFamilies(id)) {
                if (!added.contains(family))
                    added.append(family);
            }
        }
        return added;
    }();
    return families;
}

void Theme::loadMode()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("theme"));
    const QString stored = settings.value(QStringLiteral("mode"), QStringLiteral("system")).toString();
    settings.endGroup();
    if (stored == QLatin1String("light") || stored == QLatin1String("dark")
        || stored == QLatin1String("system"))
        m_mode = stored;
}

void Theme::persistMode()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("theme"));
    settings.setValue(QStringLiteral("mode"), m_mode);
    settings.endGroup();
}

void Theme::setMode(const QString &mode)
{
    if (mode != QLatin1String("light") && mode != QLatin1String("dark")
        && mode != QLatin1String("system"))
        return;
    if (m_mode == mode)
        return;
    m_mode = mode;
    persistMode();
    watch();
    reload();
}

void Theme::watch()
{
    if (!m_watcher.files().isEmpty())
        m_watcher.removePaths(m_watcher.files());
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());

    // Corners follow looknfeel in every mode; colours only in system mode.
    for (const QString &looknfeel : std::as_const(m_roundingPaths)) {
        if (QFile::exists(looknfeel))
            m_watcher.addPath(looknfeel);
    }
    if (m_mode != QLatin1String("system"))
        return;

    const QString colours = m_themePath + QStringLiteral("/colors.toml");
    if (QFile::exists(colours))
        m_watcher.addPath(colours);
    const QFileInfo pointer(m_themePath);
    if (pointer.dir().exists())
        m_watcher.addPath(pointer.absolutePath());
}

void Theme::readMotion()
{
    bool reduce = false;
#ifdef Q_OS_WASM
    reduce = EM_ASM_INT({ return matchMedia('(prefers-reduced-motion: reduce)').matches ? 1 : 0; });
#elif defined(Q_OS_ANDROID)
    // Accessibility › Remove animations sets the animator scale to 0.
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const QJniObject resolver = context.callObjectMethod("getContentResolver",
                                                         "()Landroid/content/ContentResolver;");
    reduce = QJniObject::callStaticMethod<jfloat>(
                     "android/provider/Settings$Global", "getFloat",
                     "(Landroid/content/ContentResolver;Ljava/lang/String;F)F", resolver.object(),
                     QJniObject::fromString(QStringLiteral("animator_duration_scale")).object<jstring>(),
                     jfloat(1))
            == 0;
#else
    for (const char *version : {"gtk-4.0", "gtk-3.0"}) {
        const QString settings =
            configHome() + QLatin1Char('/') + QLatin1String(version) + QStringLiteral("/settings.ini");
        if (const std::optional<bool> animations = readAnimations(settings)) {
            reduce = !*animations;
            break;
        }
    }
#endif
    if (reduce == m_reduceMotion)
        return;
    m_reduceMotion = reduce;
    emit motionChanged();
}

void Theme::reload()
{
    readMotion();

    const QHash<QString, QString> values = m_mode == QLatin1String("system")
            ? readFlatToml(m_themePath + QStringLiteral("/colors.toml"))
            : QHash<QString, QString>();
    m_usingOmarchy = !values.isEmpty();

    if (m_usingOmarchy) {
        applyOmarchy(values);
    } else {
        m_dark = m_mode == QLatin1String("dark")
                || (m_mode == QLatin1String("system") && qGuiApp
                    && QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark);
        if (m_dark)
            applyEvaDark();
        else
            applyEvaLight();
    }

    // Shape is the desktop's, whatever colours the user picked: on Omarchy
    // its looknfeel rounding (0 unless set), elsewhere soft corners and pills.
    m_omarchyShape = QFileInfo::exists(m_themePath + QStringLiteral("/colors.toml"))
            || std::any_of(m_roundingPaths.cbegin(), m_roundingPaths.cend(),
                           [](const QString &path) { return QFileInfo::exists(path); });
    m_rounding = kSoftCorner;
    if (m_omarchyShape) {
        m_rounding = 0;
        for (const QString &looknfeel : std::as_const(m_roundingPaths)) {
            if (const std::optional<int> found = readRounding(looknfeel)) {
                m_rounding = *found;
                break;
            }
        }
    }

    emit changed();
    show();
}

void Theme::show()
{
    if (!m_painted || slow() == 0) {
        m_painted = true;
        m_fade.stop();
        m_shown = m_palette;
        emit paletteChanged();
        return;
    }
    m_fade.stop();
    m_from = m_shown;
    m_fade.setDuration(slow());
    m_fade.start();
}

void Theme::applyEvaLight()
{
    Palette &p = m_palette;
    p.accent = QColor(0xE1, 0xB3, 0x46);
    p.accentDark = QColor(0xB9, 0x8A, 0x1F);
    p.accentSoft = QColor(0xF6, 0xE8, 0xC0);
    p.accentText = QColor(0x8B, 0x6A, 0x29);
    p.accentLine = p.accentDark;
    p.onAccent = QColor(0x22, 0x1E, 0x16);
    p.background = QColor(0xF6, 0xF4, 0xEF);
    p.surface = QColor(0xFD, 0xFC, 0xF9);
    p.border = QColor(0xE7, 0xE2, 0xD7);
    p.textPrimary = QColor(0x22, 0x1E, 0x16);
    p.textSecondary = QColor(0x58, 0x52, 0x49);
    p.textMuted = QColor(0x65, 0x5D, 0x4F);
    p.subtleFill = mix(p.background, p.textPrimary, 0.08);
    p.subtleFillStrong = mix(p.background, p.textPrimary, 0.14);
    p.failed = QColor(0xB2, 0x3A, 0x2E);
    p.added = QColor(0x2F, 0x7D, 0x4A);
}

void Theme::applyEvaDark()
{
    Palette &p = m_palette;
    p.accent = QColor(0xE1, 0xB3, 0x46);
    p.accentDark = QColor(0xB9, 0x8A, 0x1F);
    p.accentSoft = QColor(0x3A, 0x2D, 0x10);
    p.accentText = QColor(0xE1, 0xB3, 0x46);
    p.accentLine = p.accent;
    p.onAccent = QColor(0x22, 0x1E, 0x16);
    p.background = QColor(0x1A, 0x17, 0x14);
    p.surface = QColor(0x25, 0x21, 0x19);
    p.border = QColor(0x38, 0x32, 0x2A);
    p.textPrimary = QColor(0xF4, 0xF1, 0xE9);
    p.textSecondary = QColor(0xC4, 0xBC, 0xAD);
    p.textMuted = QColor(0xAA, 0xA0, 0x8D);
    p.subtleFill = mix(p.background, p.textPrimary, 0.10);
    p.subtleFillStrong = mix(p.background, p.textPrimary, 0.16);
    p.failed = QColor(0xFF, 0x6B, 0x75);
    p.added = QColor(0x7B, 0xD8, 0x8F);
}

void Theme::applyOmarchy(const QHash<QString, QString> &values)
{
    const QColor omBackground =
        colourOr(values, QStringLiteral("background"), QColor(0x1A, 0x17, 0x14));
    const QColor omForeground =
        colourOr(values, QStringLiteral("foreground"), QColor(0xF4, 0xF1, 0xE9));
    const QColor omAccent = colourOr(values, QStringLiteral("accent"), QColor(0xE1, 0xB3, 0x46));
    const QColor omUrgent = colourOr(values, QStringLiteral("red"), QColor(0xFF, 0x6B, 0x75));
    const QColor omMuted = colourOr(values, QStringLiteral("muted"),
                                    colourOr(values, QStringLiteral("dark_foreground"),
                                             omForeground.darker(160)));

    m_dark = values.value(QStringLiteral("mode"), QStringLiteral("dark"))
            != QLatin1String("light");
    if (!m_dark && luminance(omBackground) < 0.4)
        m_dark = true;
    else if (m_dark && luminance(omBackground) > 0.6)
        m_dark = false;

    Palette &p = m_palette;
    p.background = omBackground;
    p.surface = mix(omBackground, omForeground, 0.05);
    p.textPrimary = omForeground;
    p.textSecondary = readable(mix(omForeground, omBackground, 0.35));
    p.textMuted = readable(omMuted);
    p.accent = omAccent;
    p.accentDark = omAccent.darker(125);
    p.accentSoft = mix(omAccent, omBackground, 0.75);
    p.accentText = readableOn(omBackground, omAccent);
    p.accentLine = m_dark ? p.accent : p.accentDark;
    p.onAccent = readableOn(omAccent, omForeground);
    p.border = mix(omBackground, omForeground, 0.18);
    p.subtleFill = mix(omBackground, omForeground, m_dark ? 0.10 : 0.08);
    p.subtleFillStrong = mix(omBackground, omForeground, m_dark ? 0.16 : 0.14);

    const QColor evaFailed = m_dark ? QColor(0xFF, 0x6B, 0x75) : QColor(0xB2, 0x3A, 0x2E);
    p.failed = contrast(omUrgent, p.background) >= kReadableContrast ? omUrgent : evaFailed;
    const QColor omGreen = colourOr(values, QStringLiteral("green"), QColor(0x7B, 0xD8, 0x8F));
    const QColor evaAdded = m_dark ? QColor(0x7B, 0xD8, 0x8F) : QColor(0x2F, 0x7D, 0x4A);
    p.added = contrast(omGreen, p.background) >= kReadableContrast ? omGreen : evaAdded;
}

QString Theme::resolveLanguage(const QString &saved, const QStringList &preferred)
{
    if (speaks(saved))
        return saved;
    for (const QString &tag : preferred) {
        const QString primary = tag.section(QLatin1Char('-'), 0, 0).section(QLatin1Char('_'), 0, 0);
        for (const Language &language : kLanguages) {
            const QString code = QString::fromLatin1(language.code);
            if (primary.compare(code.section(QLatin1Char('-'), 0, 0), Qt::CaseInsensitive) == 0)
                return code;
        }
    }
    return QString::fromLatin1(kSourceLanguage);
}

QVariantList Theme::languages() const
{
    QVariantList list;
    for (const Language &language : kLanguages) {
        list.append(QVariantMap{{QStringLiteral("code"), QString::fromLatin1(language.code)},
                                {QStringLiteral("mark"), QString::fromUtf8(language.mark)},
                                {QStringLiteral("name"), QString::fromUtf8(language.name)}});
    }
    return list;
}

void Theme::setLanguage(const QString &language)
{
    if (!speaks(language) || m_language == language)
        return;
    m_language = language;
    QSettings().setValue(kLanguageKey, m_language);
    applyLanguage();
    if (QQmlEngine *engine = qmlEngine(this))
        engine->retranslate();
    emit typeChanged();
}

// Sizes and numbers follow the language, then the words: swapping the
// translator tells every listener (Session retitles its commands).
void Theme::applyLanguage()
{
    const QLocale locale(m_language);
    QLocale::setDefault(locale);
    QCoreApplication::removeTranslator(&m_translator);
    if (m_translator.load(locale, QStringLiteral("matome"), QStringLiteral("_"),
                          QStringLiteral(":/i18n")))
        QCoreApplication::installTranslator(&m_translator);
}

// Latin first with the Japanese face behind it for kana in names; Japanese
// first when the interface is Japanese (the landing's `:lang(ja)` swap).
QStringList Theme::sans() const
{
    static const QString inter = QStringLiteral("Inter");
    static const QString noto = QStringLiteral("Noto Sans JP");
    return m_language.startsWith(QLatin1String("ja")) ? QStringList{noto, inter}
                                                      : QStringList{inter, noto};
}

QStringList Theme::serif() const
{
    static const QString newsreader = QStringLiteral("Newsreader");
    static const QString noto = QStringLiteral("Noto Serif JP");
    return m_language.startsWith(QLatin1String("ja")) ? QStringList{noto, newsreader}
                                                      : QStringList{newsreader, noto};
}

QFont Theme::font(const QStringList &families, int pixelSize, QFont::Weight weight) const
{
    QFont made;
    made.setFamilies(families);
    made.setPixelSize(pixelSize);
    made.setWeight(weight);
    return made;
}

QFont Theme::eyebrow() const
{
    QFont made = font(sans(), 11, QFont::Medium);
    made.setCapitalization(QFont::AllUppercase);
    made.setLetterSpacing(QFont::AbsoluteSpacing, 11 * 0.24);
    return made;
}

QFont Theme::caption() const
{
    return font(sans(), 12, QFont::Normal);
}

QFont Theme::body() const
{
    return font(sans(), 14, QFont::Normal);
}

QFont Theme::bodyLarge() const
{
    return font(sans(), 16, QFont::Normal);
}

QFont Theme::mono() const
{
    QFont made = QFontDatabase::systemFont(QFontDatabase::FixedFont);
    made.setPixelSize(13);
    return made;
}

QFont Theme::button() const
{
    QFont made = font(sans(), 14, QFont::Medium);
    made.setLetterSpacing(QFont::AbsoluteSpacing, 14 * 0.06);
    return made;
}

QFont Theme::link() const
{
    QFont made = font(sans(), 12, QFont::Normal);
    const bool japanese = m_language.startsWith(QLatin1String("ja"));
    made.setLetterSpacing(QFont::AbsoluteSpacing, 12 * (japanese ? 0.04 : 0.12));
    return made;
}

QFont Theme::heading() const
{
    return font(serif(), 19, QFont::Normal);
}

QFont Theme::title() const
{
    QFont made = font(serif(), 26, QFont::Light);
    if (m_language.startsWith(QLatin1String("ja")))
        made.setLetterSpacing(QFont::AbsoluteSpacing, 26 * 0.04);
    return made;
}

// Japanese has no italic: the landing sets it upright and spaced instead.
QFont Theme::slogan() const
{
    QFont made = font(serif(), 20, QFont::Light);
    if (m_language.startsWith(QLatin1String("ja")))
        made.setLetterSpacing(QFont::AbsoluteSpacing, 20 * 0.12);
    else
        made.setItalic(true);
    return made;
}

QFont Theme::display() const
{
    QFont made = font(QStringList{QStringLiteral("Cormorant Garamond")} + serif(), 56, QFont::Light);
    made.setLetterSpacing(QFont::AbsoluteSpacing, 56 * 0.02);
    return made;
}

QFont Theme::strong(const QFont &font) const
{
    QFont made = font;
    made.setWeight(QFont::Medium);
    return made;
}

QList<double> Theme::ease() const
{
    return {kEase[0], kEase[1], kEase[2], kEase[3], 1.0, 1.0};
}

void Theme::setFocusVisible(bool visible)
{
    if (m_focusVisible == visible)
        return;
    m_focusVisible = visible;
    emit focusVisibleChanged();
}

// :focus-visible: a key (not a lone modifier) shows the ring, a pointer
// press hides it.
bool Theme::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::KeyPress: {
        const int key = static_cast<QKeyEvent *>(event)->key();
        if (key != Qt::Key_Shift && key != Qt::Key_Control && key != Qt::Key_Alt
            && key != Qt::Key_Meta)
            setFocusVisible(true);
        break;
    }
    case QEvent::MouseButtonPress:
    case QEvent::TouchBegin:
    case QEvent::TabletPress:
        setFocusVisible(false);
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

qreal Theme::contrast(const QColor &a, const QColor &b) const
{
    const qreal one = luminance(a);
    const qreal other = luminance(b);
    return (qMax(one, other) + 0.05) / (qMin(one, other) + 0.05);
}

QColor Theme::readable(const QColor &wanted) const
{
    if (!wanted.isValid())
        return m_palette.textPrimary;
    if (contrast(wanted, m_palette.background) >= kReadableContrast)
        return wanted;

    for (int step = 1; step <= 20; ++step) {
        const QColor tried = mix(wanted, m_palette.textPrimary, step / 20.0);
        if (contrast(tried, m_palette.background) >= kReadableContrast)
            return tried;
    }
    return m_palette.textPrimary;
}

QColor Theme::readableOn(const QColor &surface, const QColor &wanted) const
{
    if (!wanted.isValid())
        return m_palette.textPrimary;
    if (contrast(wanted, surface) >= kReadableContrast)
        return wanted;

    const QColor goal = luminance(surface) > 0.5 ? QColor(0x22, 0x1E, 0x16) : QColor(0xF4, 0xF1, 0xE9);
    for (int step = 1; step <= 20; ++step) {
        const QColor tried = mix(wanted, goal, step / 20.0);
        if (contrast(tried, surface) >= kReadableContrast)
            return tried;
    }
    return goal;
}

QColor Theme::fill(const QColor &role, qreal alpha) const
{
    QColor wash = role;
    wash.setAlphaF(qBound(0.0, alpha, 1.0));
    return wash;
}

QColor Theme::spaceColor(int index) const
{
    return kSpaceAccents[index % 8];
}

} // namespace matome
