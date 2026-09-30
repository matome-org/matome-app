#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QFont>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTranslator>
#include <QVariantAnimation>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

namespace matome {

/// Every design token QML may use: colour roles, type, motion, spacing,
/// shape, and when the focus ring shows. QML binds these; it never spells a
/// colour, a font, a size, a radius, or a duration itself.
class Theme : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)

    // Colour roles. A mode switch walks them to the new table over `slow`.
    Q_PROPERTY(QColor accent READ accent NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentDark READ accentDark NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentSoft READ accentSoft NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentText READ accentText NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentLine READ accentLine NOTIFY paletteChanged)
    Q_PROPERTY(QColor onAccent READ onAccent NOTIFY paletteChanged)
    Q_PROPERTY(QColor background READ background NOTIFY paletteChanged)
    Q_PROPERTY(QColor surface READ surface NOTIFY paletteChanged)
    Q_PROPERTY(QColor border READ border NOTIFY paletteChanged)
    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY paletteChanged)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY paletteChanged)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY paletteChanged)
    Q_PROPERTY(QColor subtleFill READ subtleFill NOTIFY paletteChanged)
    Q_PROPERTY(QColor subtleFillStrong READ subtleFillStrong NOTIFY paletteChanged)
    Q_PROPERTY(QColor failed READ failed NOTIFY paletteChanged)
    Q_PROPERTY(QColor added READ added NOTIFY paletteChanged)

    // The interface language (persisted): it picks the words, the locale
    // numbers and sizes follow, and the families (Japanese puts Noto JP
    // first). `languages` lists the choices as {code, mark, name}.
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY typeChanged)
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)

    // Type.
    Q_PROPERTY(QFont eyebrow READ eyebrow NOTIFY typeChanged)
    Q_PROPERTY(QFont caption READ caption NOTIFY typeChanged)
    Q_PROPERTY(QFont body READ body NOTIFY typeChanged)
    Q_PROPERTY(QFont bodyLarge READ bodyLarge NOTIFY typeChanged)
    Q_PROPERTY(QFont mono READ mono NOTIFY typeChanged)
    Q_PROPERTY(QFont button READ button NOTIFY typeChanged)
    Q_PROPERTY(QFont link READ link NOTIFY typeChanged)
    Q_PROPERTY(QFont heading READ heading NOTIFY typeChanged)
    Q_PROPERTY(QFont title READ title NOTIFY typeChanged)
    Q_PROPERTY(QFont slogan READ slogan NOTIFY typeChanged)
    Q_PROPERTY(QFont display READ display NOTIFY typeChanged)

    // Motion: the landing's curve and three durations, all 0 when the
    // platform asks for reduced motion.
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY motionChanged)
    Q_PROPERTY(int fast READ fast NOTIFY motionChanged)
    Q_PROPERTY(int base READ base NOTIFY motionChanged)
    Q_PROPERTY(int slow READ slow NOTIFY motionChanged)
    Q_PROPERTY(QList<double> ease READ ease CONSTANT)

    // Spacing scale, in logical pixels.
    Q_PROPERTY(int gapXs READ gapXs CONSTANT)
    Q_PROPERTY(int gapS READ gapS CONSTANT)
    Q_PROPERTY(int gapM READ gapM CONSTANT)
    Q_PROPERTY(int gapL READ gapL CONSTANT)
    Q_PROPERTY(int gapXl READ gapXl CONSTANT)
    Q_PROPERTY(int gapXxl READ gapXxl CONSTANT)

    // Sizes, in logical pixels: icons, controls, and list rows.
    Q_PROPERTY(int iconS READ iconS CONSTANT)
    Q_PROPERTY(int iconM READ iconM CONSTANT)
    Q_PROPERTY(int iconL READ iconL CONSTANT)
    Q_PROPERTY(int controlS READ controlS CONSTANT)
    Q_PROPERTY(int controlM READ controlM CONSTANT)
    Q_PROPERTY(int controlL READ controlL CONSTANT)
    Q_PROPERTY(int controlXl READ controlXl CONSTANT)
    Q_PROPERTY(int rowDense READ rowDense CONSTANT)
    Q_PROPERTY(int rowTouch READ rowTouch CONSTANT)
    Q_PROPERTY(int measure READ measure CONSTANT)
    Q_PROPERTY(int column READ column CONSTANT)

    // Shape follows the desktop in every colour mode: on Omarchy its
    // looknfeel rounding for everything, else soft surfaces and pill buttons.
    Q_PROPERTY(int rounding READ rounding NOTIFY changed)
    Q_PROPERTY(bool pill READ pill NOTIFY changed)
    Q_PROPERTY(int inset READ inset NOTIFY changed)

    // The focus ring shows only while the keyboard drives.
    Q_PROPERTY(bool focusVisible READ focusVisible NOTIFY focusVisibleChanged)

public:
    struct Palette
    {
        QColor accent;
        QColor accentDark;
        QColor accentSoft;
        QColor accentText;
        QColor accentLine;
        QColor onAccent;
        QColor background;
        QColor surface;
        QColor border;
        QColor textPrimary;
        QColor textSecondary;
        QColor textMuted;
        QColor subtleFill;
        QColor subtleFillStrong;
        QColor failed;
        /// Ink for what a change adds; `failed` marks what it removes.
        QColor added;
    };

    explicit Theme(QObject *parent = nullptr);

    /// Registers the bundled fonts once per process; the families it added.
    static QStringList registerFonts();

    QString mode() const { return m_mode; }
    void setMode(const QString &mode);
    bool dark() const { return m_dark; }

    QColor accent() const { return m_shown.accent; }
    QColor accentDark() const { return m_shown.accentDark; }
    QColor accentSoft() const { return m_shown.accentSoft; }
    QColor accentText() const { return m_shown.accentText; }
    /// Gold as a thin line on the background: focus ring, focused field, fold.
    QColor accentLine() const { return m_shown.accentLine; }
    QColor onAccent() const { return m_shown.onAccent; }
    QColor background() const { return m_shown.background; }
    QColor surface() const { return m_shown.surface; }
    QColor border() const { return m_shown.border; }
    QColor textPrimary() const { return m_shown.textPrimary; }
    QColor textSecondary() const { return m_shown.textSecondary; }
    QColor textMuted() const { return m_shown.textMuted; }
    QColor subtleFill() const { return m_shown.subtleFill; }
    QColor subtleFillStrong() const { return m_shown.subtleFillStrong; }
    QColor failed() const { return m_shown.failed; }
    QColor added() const { return m_shown.added; }

    QString language() const { return m_language; }
    void setLanguage(const QString &language);
    QVariantList languages() const;
    /// The saved choice when it is one of ours, else the first of the
    /// system's (or browser's) preferred languages we speak, else English.
    static QString resolveLanguage(const QString &saved, const QStringList &preferred);
    QFont eyebrow() const;
    QFont caption() const;
    QFont body() const;
    QFont bodyLarge() const;
    /// Fixed-width text for diffs and source: the platform fixed font,
    /// which WebAssembly provides too.
    QFont mono() const;
    QFont button() const;
    QFont link() const;
    QFont heading() const;
    QFont title() const;
    QFont slogan() const;
    QFont display() const;
    /// `font` one step heavier (Medium): selection, the current crumb.
    Q_INVOKABLE QFont strong(const QFont &font) const;

    bool reduceMotion() const { return m_reduceMotion; }
    int fast() const { return m_reduceMotion ? 0 : kFast; }
    int base() const { return m_reduceMotion ? 0 : kBase; }
    int slow() const { return m_reduceMotion ? 0 : kSlow; }
    QList<double> ease() const;

    int gapXs() const { return 4; }
    int gapS() const { return 8; }
    int gapM() const { return 12; }
    int gapL() const { return 16; }
    int gapXl() const { return 24; }
    int gapXxl() const { return 40; }

    int iconS() const { return 12; }
    int iconM() const { return 16; }
    int iconL() const { return 20; }
    int controlS() const { return 28; }
    int controlM() const { return 32; }
    int controlL() const { return 40; }
    int controlXl() const { return 48; }
    int rowDense() const { return 32; }
    int rowTouch() const { return 48; }
    /// The widest a centred column of words runs: the sign-in form, a
    /// list's empty state.
    int measure() const { return 360; }
    /// A side column's width: the sidebar at rest, a menu, the filter.
    int column() const { return 248; }

    int rounding() const { return m_rounding; }
    bool pill() const { return !m_omarchyShape; }
    /// How far a row's wash stands in from its panel's edges: clear of them
    /// while corners are round, flush when they are square.
    int inset() const { return m_rounding > 0 ? gapS() : 0; }

    bool focusVisible() const { return m_focusVisible; }

    Q_INVOKABLE QColor fill(const QColor &role, qreal alpha) const;
    qreal contrast(const QColor &a, const QColor &b) const;
    QColor readable(const QColor &wanted) const;
    Q_INVOKABLE QColor spaceColor(int index) const;

    static constexpr qreal kReadableContrast = 4.5;
    static constexpr int kFast = 150;
    static constexpr int kBase = 300;
    static constexpr int kSlow = 600;
    /// Surface corners when the desktop does not set its own.
    static constexpr int kSoftCorner = 8;

signals:
    void changed();
    void paletteChanged();
    void typeChanged();
    void motionChanged();
    void focusVisibleChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void loadMode();
    void persistMode();
    void applyLanguage();
    void reload();
    void watch();
    void readMotion();
    void show();
    void applyEvaLight();
    void applyEvaDark();
    void applyOmarchy(const QHash<QString, QString> &values);
    QColor readableOn(const QColor &surface, const QColor &wanted) const;
    QStringList sans() const;
    QStringList serif() const;
    QFont font(const QStringList &families, int pixelSize, QFont::Weight weight) const;
    void setFocusVisible(bool visible);

    QFileSystemWatcher m_watcher;
    QVariantAnimation m_fade;
    QString m_themePath;
    QStringList m_roundingPaths;
    QString m_mode = QStringLiteral("system");
    QString m_language;
    QTranslator m_translator;
    bool m_dark = false;
    bool m_usingOmarchy = false;
    bool m_omarchyShape = false;
    bool m_reduceMotion = false;
    bool m_focusVisible = false;
    bool m_painted = false;
    int m_rounding = kSoftCorner;

    Palette m_palette;
    Palette m_from;
    Palette m_shown;
};

} // namespace matome
