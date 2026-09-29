#include "FakeCore.h"
#include "Session.h"
#include "Theme.h"
#include "Wiring.h"

#include <QAccessible>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFontDatabase>
#include <QFontInfo>
#include <QGuiApplication>
#include <QMimeData>
#include <QPointingDevice>
#include <QQmlApplicationEngine>
#include <QQmlExpression>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSettings>
#include <QtQuickTest/quicktest.h>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

#include <algorithm>
#include <functional>

using matome::EntryModel;
using matome::Session;
using matome::Theme;
using matome::probe::descendants;
using matome::test::FakeCore;

// The landing's Eva tables, as a mode switch settles on them.
static const QColor kEvaLightBackground(QStringLiteral("#f6f4ef"));
static const QColor kEvaDarkBackground(QStringLiteral("#1a1714"));
static const QColor kEvaLightAccentSoft(QStringLiteral("#f6e8c0"));
static const QColor kEvaDarkAccentSoft(QStringLiteral("#3a2d10"));

// An item's centre in scene coordinates: where a pointer aims at it.
static QPoint centreOf(const QQuickItem *item)
{
    return item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint();
}

class TestStudio : public QObject
{
    Q_OBJECT

public slots:
    // The desktop hands downloaded files here instead of to an opener.
    void openFile(const QUrl &url) { m_opened.append(url); }

private slots:
    void initTestCase();
    void cleanupTestCase();
    void init();
    void themeRolesStayReadable();
    void themeFadesToTheNewTable();
    void typeTokensUseTheBundledFonts();
    void motionTokensHonourReducedMotion();
    void themeToggleCyclesModes();
    void focusRingShowsOnlyForTheKeyboard();
    void logoWritesItself();
    void serverAddressWaitsBehindADisclosure();
    void tabsEveryControlOnSignIn();
    void keyboardSignsInAndOut();
    void mouseSignsIn();
    void touchSignsIn();
    void keyboardCreatesAnAccount();
    void keyboardForgotAndReset();
    void escapeReturnsToSignIn();
    void wrongPasswordSaysSo();
    void refusedRegistrationNamesTheField();
    void rateLimitSaysToWait();
    void systemModeReadsOmarchyColours();
    void cornersFollowTheSystem();
    void keyboardDrivesTheExplorer();
    void tabReachesEveryRegion();
    void f6CyclesRegions();
    void keyboardWalksTheTree();
    void keyboardOpensSheetKeymapAndUpload();
    void mouseBrowsesTheExplorer();
    void mouseEditsFromToolbarAndMenu();
    void dragAndDropMovesPayloads();
    void droppedFilesUpload();
    void uploadDialogSendsTheChosenFile();
    void uploadShowsProgressPerFile();
    void uploadFailuresAreNamed();
    void refusedNamesSayWhy();
    void aStaleRowReloadsAndSaysWhy();
    void purgeEmptiesTheTrash();
    void deletingAFolderAsksFirst();
    void folderCycleIsRefused();
    void touchOpensAndLongPressesForAMenu();
    void narrowWidthUsesADrawer();
    void safeAreaKeepsControlsBelowSystemBars();
    void logoLinksHome();
    void locationHeaderNamesThePlace();
    void emptyStateShowsLoadingAndErrors();
    void toolbarKeepsOnePrimary();
    void rowsStandClearOfTheEdges();
    void washesFollowTheCrossfade();
    void overlaysSpeakTheLandingType();
    void languageResolvesAndPersists();
    void languageSwitchesLive();
    void switcherTakesKeysAndPointer();
    void accountMenuChoosesALanguage();
    void emptyFieldsSayWhatIsMissing();
    void expiredTokenRefreshesMidUse();
    void relaunchRemembersTheLastSession();
    void refreshReloadsEveryLevel();
    void everyControlHasANameAndRole();
    void sidebarResizesByDrag();
    void omarchyReloadsLive();
    void reducedMotionStopsAnimations();
    void coreDyingMidUseSaysSo();
    void serverErrorsShowAtEveryLevel();
    void longListKeepsTheCursorInSight();
    void longNamesElide();

private:
    QQuickWindow *window() const;
    QQuickItem *itemNamed(const QString &name, QQuickWindow *in = nullptr) const;
    QQuickItem *rowTitled(const QString &prefix, const QString &title) const;
    QQuickItem *waitItem(const QString &name) const;
    QQuickItem *waitRow(const QString &prefix, const QString &title) const;
    QVariant rowProperty(const QString &prefix, const QString &title, const char *name) const;
    QVariant propertyOf(const QString &item, const char *name) const;
    bool shown(const QString &name) const;
    bool rowFocused(const QString &prefix, const QString &title) const;
    void focusOn(QQuickItem *item);
    QString regionOf(QQuickItem *item) const;
    QString focusName() const;
    bool menuOpen() const;
    bool ringShown(const QString &name) const;
    void writeFile(const QString &path, const QByteArray &body);
    QUrl scratchFile(const QString &name, const QByteArray &body);
    QString statusText() const;
    void key(Qt::Key code, Qt::KeyboardModifiers mods = Qt::NoModifier);
    void type(const QString &text);
    void clicks(QQuickItem *item, const QString &text);
    void clickItem(QQuickItem *item, Qt::MouseButton button = Qt::LeftButton);
    void tapItem(QQuickItem *item, int holdMs = 0);
    void dropOn(QQuickItem *item, QMimeData *mime, const std::function<void()> &midDrag = {});
    void dragOnto(QQuickItem *from, QQuickItem *onto);
    void settle();
    bool waitSignedIn(bool wanted);
    bool waitIdle();
    QString entryId(const QString &name) const;
    void signInAsOk();
    bool openOwnOrg();
    bool createSpace(const QString &name);
    void openSpace(const QString &name);
    void addFolder(const QString &name);

    QTemporaryDir m_home;
    FakeCore m_core;
    QQmlApplicationEngine *m_engine = nullptr;
    Theme *m_theme = nullptr;
    Session *m_session = nullptr;
    QList<QUrl> m_opened;
};

void TestStudio::initTestCase()
{
    QVERIFY(m_home.isValid());
    QStandardPaths::setTestModeEnabled(true);
    qputenv("XDG_CONFIG_HOME", m_home.filePath("config").toUtf8());
    qputenv("XDG_STATE_HOME", m_home.filePath("state").toUtf8());
    // Omarchy's shipped defaults would leak the desktop's rounding in.
    qputenv("OMARCHY_PATH", m_home.filePath("omarchy").toUtf8());
    // Downloads default to ~/Downloads; keep them in the scratch home.
    qputenv("HOME", m_home.path().toUtf8());
    QVERIFY(m_core.listen());
    // The machine's language must not leak in: start from a saved English.
    QSettings().setValue(QStringLiteral("theme/language"), QStringLiteral("en"));
    QDesktopServices::setUrlHandler(QStringLiteral("file"), this, "openFile");
    m_engine = new QQmlApplicationEngine;
    m_engine->load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    QVERIFY(!m_engine->rootObjects().isEmpty());
    m_theme = m_engine->singletonInstance<Theme *>(QStringLiteral("matome"),
                                                   QStringLiteral("Theme"));
    m_session = m_engine->singletonInstance<Session *>(QStringLiteral("matome"),
                                                       QStringLiteral("Session"));
    QVERIFY(m_theme && m_session);
    m_session->setApiBaseUrl(m_core.url());
    QVERIFY(window());
    QVERIFY(QTest::qWaitForWindowExposed(window()));
}

void TestStudio::cleanupTestCase()
{
    QDesktopServices::unsetUrlHandler(QStringLiteral("file"));
    delete m_engine;
    m_engine = nullptr;
}

void TestStudio::init()
{
    // A dialog window may have kept focus; the studio window takes it back.
    window()->requestActivate();
    QVERIFY(QTest::qWaitForWindowActive(window()));
    window()->resize(1200, 760);
    m_theme->setLanguage(QStringLiteral("en"));
    if (m_session->signedIn()) {
        m_session->runCommand(QStringLiteral("sign-out"));
        // The logout lands before the reset, never inside the next test.
        QTRY_COMPARE(m_core.lastPath(), QStringLiteral("/api/auth/logout"));
    }
    m_session->setLastOrgId(QString());
    m_core.reset();
    m_session->setApiBaseUrl(m_core.url());
    settle();
    if (QQuickItem *auth = itemNamed(QStringLiteral("authScreen"))) {
        auth->setProperty("pane", QStringLiteral("signIn"));
        auth->setProperty("serverOpen", false);
        QMetaObject::invokeMethod(auth, "prefill");
        QMetaObject::invokeMethod(auth, "focusDefault");
    }
    settle();
}

QQuickWindow *TestStudio::window() const
{
    return qobject_cast<QQuickWindow *>(m_engine->rootObjects().value(0));
}

QQuickItem *TestStudio::itemNamed(const QString &name, QQuickWindow *in) const
{
    QQuickItem *root = (in ? in : window())->contentItem();
    if (!root)
        return nullptr;
    QQuickItem *hidden = nullptr;
    for (QQuickItem *item : descendants(root)) {
        if (item->objectName() != name)
            continue;
        if (item->isVisible())
            return item;
        if (!hidden)
            hidden = item;
    }
    return hidden;
}

// The visible row whose objectName starts with `prefix` and shows `title`.
QQuickItem *TestStudio::rowTitled(const QString &prefix, const QString &title) const
{
    for (QQuickItem *item : descendants(window()->contentItem())) {
        if (item->isVisible() && item->objectName().startsWith(prefix)
            && item->property("title").toString() == title)
            return item;
    }
    return nullptr;
}

// Delegates appear a frame after their rows, so the wait helpers poll `find`
// for up to 5 s: the item it found, or null when it never did.
template<typename Find>
static QQuickItem *waitFound(Find find)
{
    QQuickItem *found = nullptr;
    return QTest::qWaitFor([&] { return (found = find()) != nullptr; }) ? found : nullptr;
}

QQuickItem *TestStudio::waitItem(const QString &name) const
{
    return waitFound([&] { return itemNamed(name); });
}

QQuickItem *TestStudio::waitRow(const QString &prefix, const QString &title) const
{
    return waitFound([&] { return rowTitled(prefix, title); });
}

QVariant TestStudio::rowProperty(const QString &prefix, const QString &title, const char *name) const
{
    QQuickItem *row = waitRow(prefix, title);
    return row ? row->property(name) : QVariant();
}

QVariant TestStudio::propertyOf(const QString &item, const char *name) const
{
    QQuickItem *found = itemNamed(item);
    return found ? found->property(name) : QVariant();
}

bool TestStudio::shown(const QString &name) const
{
    QQuickItem *found = itemNamed(name);
    return found && found->isVisible();
}

bool TestStudio::rowFocused(const QString &prefix, const QString &title) const
{
    QQuickItem *row = rowTitled(prefix, title);
    return row && row->hasActiveFocus();
}

void TestStudio::focusOn(QQuickItem *item)
{
    QVERIFY(item);
    item->forceActiveFocus();
    settle();
}

// The explorer region that holds `item`, or its own objectName.
QString TestStudio::regionOf(QQuickItem *item) const
{
    static const QStringList regions{QStringLiteral("topBar"), QStringLiteral("sidebar"),
                                     QStringLiteral("toolbar"), QStringLiteral("entryPane"),
                                     QStringLiteral("statusBar")};
    for (QQuickItem *at = item; at; at = at->parentItem()) {
        if (regions.contains(at->objectName()))
            return at->objectName();
    }
    return item ? item->objectName() : QString();
}

QString TestStudio::focusName() const
{
    QQuickItem *focus = window()->activeFocusItem();
    return focus ? focus->objectName() : QString();
}

bool TestStudio::menuOpen() const
{
    QQuickItem *menu = itemNamed(QStringLiteral("contextMenuList"));
    return menu && menu->isVisible();
}

// Whether the shared focus ring of the control `name` is painted.
bool TestStudio::ringShown(const QString &name) const
{
    QQuickItem *control = itemNamed(name);
    if (!control)
        return false;
    for (QQuickItem *child : control->childItems()) {
        if (child->objectName() == u"focusRing")
            return child->isVisible();
    }
    return false;
}

void TestStudio::writeFile(const QString &path, const QByteArray &body)
{
    QVERIFY(QDir().mkpath(QFileInfo(path).absolutePath()));
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    file.write(body);
}

// A file on disk in the scratch home, as a picker or a drop names it.
QUrl TestStudio::scratchFile(const QString &name, const QByteArray &body)
{
    const QString path = m_home.filePath(QStringLiteral("files/") + name);
    writeFile(path, body);
    return QUrl::fromLocalFile(path);
}

QString TestStudio::statusText() const
{
    return propertyOf(QStringLiteral("explorerStatus"), "text").toString();
}

void TestStudio::key(Qt::Key code, Qt::KeyboardModifiers mods)
{
    QTest::keyClick(window(), code, mods);
    settle();
}

void TestStudio::type(const QString &text)
{
    for (const QChar ch : text)
        QTest::keyClick(window(), ch.toLatin1());
    settle();
}

void TestStudio::clicks(QQuickItem *item, const QString &text)
{
    QVERIFY(item);
    item->forceActiveFocus();
    settle();
    QTest::keyClick(window(), Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(window(), Qt::Key_Backspace);
    type(text);
}

void TestStudio::clickItem(QQuickItem *item, Qt::MouseButton button)
{
    QVERIFY(item);
    settle();
    const QPoint scene = centreOf(item);
    QTest::mouseMove(window(), scene);
    settle();
    QTest::mouseClick(window(), button, Qt::NoModifier, scene);
    settle();
}

void TestStudio::tapItem(QQuickItem *item, int holdMs)
{
    QVERIFY(item);
    settle();
    const QPoint pos = centreOf(item);
    QPointingDevice *touch = QTest::createTouchDevice();
    QTest::touchEvent(window(), touch).press(0, pos);
    settle();
    if (holdMs > 0)
        QTest::qWait(holdMs);
    QTest::touchEvent(window(), touch).release(0, pos);
    settle();
}

// What an OS drag would deliver: enter, move, and drop at the item's centre;
// `midDrag` looks at the window while the drag hovers there.
void TestStudio::dropOn(QQuickItem *item, QMimeData *mime, const std::function<void()> &midDrag)
{
    QVERIFY(item);
    settle();
    const QPointF pos = centreOf(item);
    QDragEnterEvent enter(pos.toPoint(), Qt::MoveAction, mime, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(window(), &enter);
    QDragMoveEvent move(pos.toPoint(), Qt::MoveAction, mime, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(window(), &move);
    settle();
    if (midDrag)
        midDrag();
    QDropEvent drop(pos, Qt::MoveAction, mime, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(window(), &drop);
    settle();
    delete mime;
}

// A mouse drag from one item's centre, out past the drag threshold, onto
// another's centre, in steps a DragHandler follows.
void TestStudio::dragOnto(QQuickItem *from, QQuickItem *onto)
{
    QVERIFY(from);
    QVERIFY(onto);
    settle();
    const QPoint start = centreOf(from);
    const QPoint end = centreOf(onto);
    const QPoint aside = start + QPoint(40, 0);
    QTest::mouseMove(window(), start);
    QTest::mousePress(window(), Qt::LeftButton, Qt::NoModifier, start);
    for (int step = 1; step <= 5; ++step)
        QTest::mouseMove(window(), start + (aside - start) * step / 5);
    for (int step = 1; step <= 10; ++step)
        QTest::mouseMove(window(), aside + (end - aside) * step / 10);
    QTest::mouseRelease(window(), Qt::LeftButton, Qt::NoModifier, end);
    settle();
}

// Let events run and layouts settle, so positions read after it are the
// ones a click will hit.
void TestStudio::settle()
{
    for (int i = 0; i < 6; ++i)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
    QQuickTest::qWaitForPolish(window());
}

bool TestStudio::waitSignedIn(bool wanted)
{
    return QTest::qWaitFor(
            [&] {
                return m_session->signedIn() == wanted && !m_session->busy()
                        && (!wanted || !m_session->loading());
            });
}

// Every model at rest, not only the open level's: a space created a moment
// ago still reloads the spaces, and that reload re-reads the folders.
bool TestStudio::waitIdle()
{
    settle();
    return QTest::qWaitFor(
            [&] {
                return m_session->signedIn() && !m_session->busy() && !m_session->loading()
                        && !m_session->organizations()->busy() && !m_session->spaces()->busy();
            });
}

QString TestStudio::entryId(const QString &name) const
{
    const EntryModel *entries = m_session->entries();
    for (int i = 0; i < entries->rowCount(); ++i) {
        const QModelIndex at = entries->index(i);
        if (at.data(EntryModel::NameRole).toString() == name)
            return at.data(EntryModel::EntryIdRole).toString();
    }
    return QString();
}

void TestStudio::signInAsOk()
{
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    focusOn(waitItem(QStringLiteral("submitButton")));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));
    QTRY_VERIFY(itemNamed(QStringLiteral("entryRow0")));
}

// Opens the signed-in user's own organization; false when it never settles.
bool TestStudio::openOwnOrg()
{
    m_session->openEntry(QStringLiteral("org"), entryId(QStringLiteral("ok organization")));
    return waitIdle();
}

// Creates a space in the open organization and waits inside it; false when
// it never opens or settles.
bool TestStudio::createSpace(const QString &name)
{
    m_session->createHere(name);
    return QTest::qWaitFor([&] { return m_session->level() == QLatin1String("files"); })
            && waitIdle();
}

// Signs in and opens a fresh space in the first organization.
void TestStudio::openSpace(const QString &name)
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    QVERIFY(createSpace(name));
}

void TestStudio::addFolder(const QString &name)
{
    const int before = m_session->entries()->rowCount();
    m_session->createHere(name);
    QTRY_COMPARE(m_session->entries()->rowCount(), before + 1);
    QVERIFY(waitIdle());
}

void TestStudio::themeRolesStayReadable()
{
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(m_theme->contrast(m_theme->textPrimary(), m_theme->background()) >= 4.5);
    QCOMPARE(m_theme->spaceColor(8), m_theme->spaceColor(0));
    const QColor wash = m_theme->fill(m_theme->accent(), 0.5);
    QVERIFY(qAbs(wash.alphaF() - 0.5) < 0.01);
    QVERIFY(m_theme->readable(QColor(Qt::yellow)).isValid());
    m_theme->setMode(QStringLiteral("dark"));
    QVERIFY(m_theme->dark());
    m_theme->setMode(QStringLiteral("nope"));
    QVERIFY(m_theme->dark());
}

// A mode switch walks every colour role to the new table; nothing jumps.
void TestStudio::themeFadesToTheNewTable()
{
    m_theme->setMode(QStringLiteral("light"));
    QTRY_COMPARE(m_theme->background(), kEvaLightBackground);
    QSignalSpy steps(m_theme, &Theme::paletteChanged);
    m_theme->setMode(QStringLiteral("dark"));
    QCOMPARE(m_theme->background(), kEvaLightBackground);
    QTRY_COMPARE(m_theme->background(), kEvaDarkBackground);
    QVERIFY(steps.count() > 2);
    QCOMPARE(m_theme->accentLine(), m_theme->accent());
    m_theme->setMode(QStringLiteral("light"));
    QTRY_COMPARE(m_theme->accentLine(), m_theme->accentDark());
}

void TestStudio::typeTokensUseTheBundledFonts()
{
    const QStringList families = Theme::registerFonts();
    for (const char *family : {"Inter", "Newsreader", "Cormorant Garamond", "Noto Sans JP",
                               "Noto Serif JP"}) {
        QVERIFY2(families.contains(QLatin1String(family)), family);
        QVERIFY2(QFontDatabase::hasFamily(QLatin1String(family)), family);
    }
    QCOMPARE(Theme::registerFonts(), families);
    QVERIFY(QFontDatabase::styles(QStringLiteral("Newsreader")).contains(u"Light Italic"));

    QCOMPARE(m_theme->body().families().first(), QStringLiteral("Inter"));
    QCOMPARE(m_theme->body().pixelSize(), 14);
    QVERIFY(m_theme->bodyLarge().pixelSize() > m_theme->body().pixelSize());
    QVERIFY(m_theme->caption().pixelSize() < m_theme->body().pixelSize());
    QCOMPARE(m_theme->eyebrow().capitalization(), QFont::AllUppercase);
    QVERIFY(m_theme->eyebrow().letterSpacing() > 2);
    QCOMPARE(m_theme->button().weight(), QFont::Medium);
    QVERIFY(m_theme->link().letterSpacing() > 1);
    QCOMPARE(m_theme->heading().families().first(), QStringLiteral("Newsreader"));
    QCOMPARE(m_theme->title().weight(), QFont::Light);
    QVERIFY(m_theme->slogan().italic());
    QCOMPARE(m_theme->display().families().first(), QStringLiteral("Cormorant Garamond"));
    QCOMPARE(m_theme->strong(m_theme->body()).weight(), QFont::Medium);
    // The wordmark resolves to the bundled face, not a system stand-in.
    QCOMPARE(QFontInfo(m_theme->display()).family(), QStringLiteral("Cormorant Garamond"));

    QSignalSpy retyped(m_theme, &Theme::typeChanged);
    m_theme->setLanguage(QStringLiteral("ja"));
    m_theme->setLanguage(QStringLiteral("ja"));
    QCOMPARE(retyped.count(), 1);
    QCOMPARE(m_theme->body().families().first(), QStringLiteral("Noto Sans JP"));
    QCOMPARE(m_theme->title().families().first(), QStringLiteral("Noto Serif JP"));
    QVERIFY(m_theme->title().letterSpacing() > 0);
    QVERIFY(!m_theme->slogan().italic());
    QVERIFY(m_theme->link().letterSpacing() < 1);
    m_theme->setLanguage(QStringLiteral("en"));
    QCOMPARE(m_theme->title().families().first(), QStringLiteral("Newsreader"));
}

// GTK's "animations off" empties every duration and the logo stays whole.
void TestStudio::motionTokensHonourReducedMotion()
{
    const QList<double> ease{0.2, 0.7, 0.1, 1.0, 1.0, 1.0};
    QCOMPARE(m_theme->ease(), ease);
    QVERIFY(!m_theme->reduceMotion());
    QCOMPARE(m_theme->fast(), 150);
    QCOMPARE(m_theme->base(), 300);
    QCOMPARE(m_theme->slow(), 600);
    QCOMPARE(m_theme->gapXs(), 4);
    QVERIFY(m_theme->gapS() < m_theme->gapM() && m_theme->gapM() < m_theme->gapL()
            && m_theme->gapL() < m_theme->gapXl() && m_theme->gapXl() < m_theme->gapXxl());
    QVERIFY(m_theme->iconS() < m_theme->iconM() && m_theme->iconM() < m_theme->iconL());
    QVERIFY(m_theme->controlS() < m_theme->controlM() && m_theme->controlM() < m_theme->controlL()
            && m_theme->controlL() < m_theme->controlXl());
    QCOMPARE(m_theme->rowDense(), m_theme->controlM());
    QCOMPARE(m_theme->rowTouch(), m_theme->controlXl());
    QVERIFY(m_theme->measure() > m_theme->column() && m_theme->column() > m_theme->controlXl());

    const QString gtk4 = m_home.filePath(QStringLiteral("config/gtk-4.0/settings.ini"));
    const QString gtk3 = m_home.filePath(QStringLiteral("config/gtk-3.0/settings.ini"));
    writeFile(gtk4, "[Settings]\ngtk-theme-name=Adwaita\n");
    writeFile(gtk3, "[Settings]\ngtk-enable-animations=false\n");
    m_theme->setMode(QStringLiteral("dark"));
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(m_theme->reduceMotion());
    QCOMPARE(m_theme->fast(), 0);
    QCOMPARE(m_theme->base(), 0);
    QCOMPARE(m_theme->slow(), 0);
    // No fade: the new table is there at once.
    QCOMPARE(m_theme->background(), kEvaLightBackground);

    QQuickItem *logo = waitItem(QStringLiteral("authLogo"));
    QVERIFY(QMetaObject::invokeMethod(logo, "write"));
    QVERIFY(!logo->property("writing").toBool());
    QCOMPARE(logo->property("frame").toReal(), 1.0);

    writeFile(gtk3, "[Settings]\ngtk-enable-animations=1\n");
    m_theme->setMode(QStringLiteral("dark"));
    QVERIFY(!m_theme->reduceMotion());
    QCOMPARE(m_theme->slow(), 600);
    QVERIFY(QFile::remove(gtk3));
    QVERIFY(QFile::remove(gtk4));
    m_theme->setMode(QStringLiteral("light"));
}

void TestStudio::themeToggleCyclesModes()
{
    m_theme->setMode(QStringLiteral("system"));
    QQuickItem *toggle = waitItem(QStringLiteral("themeToggle"));
    QCOMPARE(toggle->property("text").toString(), QStringLiteral("System"));
    focusOn(toggle);
    key(Qt::Key_Space);
    QCOMPARE(m_theme->mode(), QStringLiteral("light"));
    QCOMPARE(toggle->property("text").toString(), QStringLiteral("Light"));
    key(Qt::Key_Return);
    QCOMPARE(m_theme->mode(), QStringLiteral("dark"));
    clickItem(toggle);
    QCOMPARE(m_theme->mode(), QStringLiteral("system"));
    tapItem(toggle);
    QCOMPARE(m_theme->mode(), QStringLiteral("light"));
    QAccessibleInterface *named = QAccessible::queryAccessibleInterface(toggle);
    QVERIFY(named);
    QCOMPARE(named->text(QAccessible::Name), QStringLiteral("Theme: Light. Switch theme"));
}

// :focus-visible — the ring follows Tab, not the pointer.
void TestStudio::focusRingShowsOnlyForTheKeyboard()
{
    clickItem(waitItem(QStringLiteral("registerLink")));
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("register"));
    QVERIFY(!m_theme->focusVisible());
    QVERIFY(itemNamed(QStringLiteral("backToSignIn")));
    focusOn(itemNamed(QStringLiteral("passwordField")));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("submitButton"));
    QVERIFY(m_theme->focusVisible());
    QVERIFY(ringShown(QStringLiteral("submitButton")));
    QTest::keyClick(window(), Qt::Key_Shift);
    QVERIFY(m_theme->focusVisible());
    clickItem(waitItem(QStringLiteral("backToSignIn")));
    QVERIFY(!m_theme->focusVisible());
    focusOn(itemNamed(QStringLiteral("forgotLink")));
    QVERIFY(!ringShown(QStringLiteral("forgotLink")));
    key(Qt::Key_Tab);
    QVERIFY(ringShown(focusName()));
}

// Written stroke by stroke on the landing's timings, once per run.
void TestStudio::logoWritesItself()
{
    QQuickItem *logo = waitItem(QStringLiteral("authLogo"));
    QVERIFY(logo->property("written").toBool());
    QTRY_COMPARE(logo->property("fold").toReal(), 1.0);
    QVERIFY(QMetaObject::invokeMethod(logo, "write"));
    QVERIFY(logo->property("writing").toBool());
    QCOMPARE(logo->property("frame").toReal(), 0.0);
    QTRY_VERIFY(logo->property("frame").toReal() > 0.0);
    QVERIFY(logo->property("tick").toReal() < 1.0);
    QTRY_VERIFY(!logo->property("writing").toBool());
    for (const char *stroke : {"frame", "hook", "tick", "fold"})
        QCOMPARE(logo->property(stroke).toReal(), 1.0);
}

// "Server…" opens the Core URL by key or pointer, and opens by itself when
// Core cannot be reached.
void TestStudio::serverAddressWaitsBehindADisclosure()
{
    QVERIFY(!shown(QStringLiteral("apiField")));
    focusOn(waitItem(QStringLiteral("serverToggle")));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("apiField")));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("apiField"));
    clickItem(waitItem(QStringLiteral("serverToggle")));
    QTRY_VERIFY(!shown(QStringLiteral("apiField")));
    clickItem(waitItem(QStringLiteral("serverToggle")));
    QTRY_VERIFY(shown(QStringLiteral("apiField")));
    key(Qt::Key_Space);
    QTRY_VERIFY(!shown(QStringLiteral("apiField")));

    m_session->setApiBaseUrl(QStringLiteral("http://127.0.0.1:9"));
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("authScreen")), "prefill");
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->errorCode(), QStringLiteral("network"));
    QTRY_VERIFY(shown(QStringLiteral("apiField")));
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
             QStringLiteral("Could not reach Core at that URL."));
    QVERIFY(!propertyOf(QStringLiteral("emailField"), "invalid").toBool());
}

void TestStudio::tabsEveryControlOnSignIn()
{
    focusOn(waitItem(QStringLiteral("emailField")));
    QSet<QString> names;
    for (int i = 0; i < 16; ++i) {
        names.insert(focusName());
        key(Qt::Key_Tab);
    }
    QVERIFY(names.contains(QStringLiteral("emailField")));
    QVERIFY(names.contains(QStringLiteral("passwordField")));
    QVERIFY(names.contains(QStringLiteral("submitButton")));
    QVERIFY(names.contains(QStringLiteral("registerLink")));
    QVERIFY(names.contains(QStringLiteral("forgotLink")));
    QVERIFY(names.contains(QStringLiteral("serverToggle")));
    QVERIFY(names.contains(QStringLiteral("themeToggle")));
    QVERIFY(!names.contains(QStringLiteral("apiField")));
}

void TestStudio::keyboardSignsInAndOut()
{
    signInAsOk();
    QCOMPARE(propertyOf(QStringLiteral("accountButton"), "text").toString(),
             QStringLiteral("ok@localhost"));
    focusOn(waitItem(QStringLiteral("accountButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(menuOpen() && focusName().startsWith(u"menu_"));
    key(Qt::Key_End);
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(focusName(), QStringLiteral("emailField"));
}

// In by the form, out by the account menu: the click on Sign out is the
// menu's alone, focus lands in the email field, and the password is gone.
void TestStudio::mouseSignsIn()
{
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    clickItem(waitItem(QStringLiteral("submitButton")));
    QVERIFY(waitSignedIn(true));
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_sign-out")));
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(focusName(), QStringLiteral("emailField"));
    QCOMPARE(propertyOf(QStringLiteral("emailField"), "text").toString(), QStringLiteral("ok@localhost"));
    QCOMPARE(propertyOf(QStringLiteral("passwordField"), "text").toString(), QString());
}

void TestStudio::touchSignsIn()
{
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    tapItem(waitItem(QStringLiteral("submitButton")));
    QVERIFY(waitSignedIn(true));
}

void TestStudio::keyboardCreatesAnAccount()
{
    focusOn(waitItem(QStringLiteral("registerLink")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("register"));
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("new@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    focusOn(waitItem(QStringLiteral("submitButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(m_session->confirmationPending());
    QTRY_COMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
                 QStringLiteral("confirm"));
    QVERIFY(!m_session->signedIn());
    QCOMPARE(focusName(), QStringLiteral("backToSignIn"));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("Open the confirmation link sent to new@localhost in your browser, then return to sign in."));
    QVERIFY(m_session->confirmationPending());
    clickItem(waitItem(QStringLiteral("resendConfirmation")));
    QTRY_VERIFY(m_session->confirmationResent());
    QVERIFY(m_core.confirmEmailInBrowser(QStringLiteral("new@localhost")));
    focusOn(waitItem(QStringLiteral("backToSignIn")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("signIn"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));
}

void TestStudio::keyboardForgotAndReset()
{
    focusOn(waitItem(QStringLiteral("forgotLink")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("forgot"));
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    focusOn(waitItem(QStringLiteral("submitButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(m_session->resetSent());
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("If that account exists, a password reset link was sent. Open it in your browser, then sign in with your new password."));
    QVERIFY(m_core.resetPasswordInBrowser(QStringLiteral("ok@localhost"), QStringLiteral("fresh-pass1")));
    focusOn(waitItem(QStringLiteral("backToSignIn")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("signIn"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("fresh-pass1"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));

    // Signed out, the form is back on sign-in with neither secret kept.
    m_session->runCommand(QStringLiteral("sign-out"));
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("signIn"));
    QCOMPARE(focusName(), QStringLiteral("emailField"));
    QCOMPARE(propertyOf(QStringLiteral("passwordField"), "text").toString(), QString());
}

void TestStudio::escapeReturnsToSignIn()
{
    focusOn(waitItem(QStringLiteral("registerLink")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("register"));
    key(Qt::Key_Escape);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("signIn"));
    clickItem(waitItem(QStringLiteral("forgotLink")));
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("forgot"));
    clickItem(waitItem(QStringLiteral("backToSignIn")));
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(),
             QStringLiteral("signIn"));
}

void TestStudio::wrongPasswordSaysSo()
{
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("wrong"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("That email or password is wrong."));
    QVERIFY(propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "color").value<QColor>(), m_theme->failed());
}

// Core refusing a new account's values marks the field it named and says
// what to fix: a taken email, then a short password, then both.
void TestStudio::refusedRegistrationNamesTheField()
{
    const QString email = QStringLiteral("Use a valid email address with no account yet.");
    const QString password = QStringLiteral("Use a password of 8 to 72 characters.");
    clickItem(waitItem(QStringLiteral("registerLink")));
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), email);
    QVERIFY(!m_session->signedIn());
    QVERIFY(propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QVERIFY(!propertyOf(QStringLiteral("passwordField"), "invalid").toBool());
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "color").value<QColor>(), m_theme->failed());

    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("new@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("short"));
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), password);
    QVERIFY(!propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());

    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("no-at-sign"));
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 email + QLatin1Char('\n') + password);
    QVERIFY(propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());
}

// Core refusing a sign-in as rate limited says to wait.
void TestStudio::rateLimitSaysToWait()
{
    QVERIFY(m_core.failNext(QStringLiteral("POST"), QStringLiteral("^/api/auth/login$"), 1,
                            FakeCore::FaultMode::Status, 429, QStringLiteral("rate_limited")));
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("Too many attempts. Wait a moment and try again."));
}

void TestStudio::systemModeReadsOmarchyColours()
{
    const QString dir = m_home.filePath(QStringLiteral("state/omarchy/current/theme"));
    QVERIFY(QDir().mkpath(dir));
    QFile file(dir + QStringLiteral("/colors.toml"));
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
    file.write("background = \"#111111\"\nforeground = \"#eeeeee\"\naccent = \"#ccaa44\"\n");
    file.close();
    m_theme->setMode(QStringLiteral("light"));
    m_theme->setMode(QStringLiteral("system"));
    settle();
    QTRY_VERIFY(m_theme->dark());
    QVERIFY(QFile::remove(dir + QStringLiteral("/colors.toml")));
    m_theme->setMode(QStringLiteral("light"));
}

// Corners follow the desktop like colours do: Omarchy's rounding for every
// surface and button, else soft panels and pill buttons.
void TestStudio::cornersFollowTheSystem()
{
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(m_theme->pill());
    QCOMPARE(m_theme->rounding(), Theme::kSoftCorner);
    QCOMPARE(m_theme->inset(), m_theme->gapS());
    QQuickItem *submit = waitItem(QStringLiteral("submitButton"));
    QCOMPARE(submit->property("radius").toReal(), submit->height() / 2);

    const QString colours = m_home.filePath(QStringLiteral("state/omarchy/current/theme/colors.toml"));
    const QString mine = m_home.filePath(QStringLiteral("config/hypr/looknfeel.lua"));
    const QString shipped = m_home.filePath(QStringLiteral("omarchy/default/hypr/looknfeel.lua"));
    writeFile(colours, "background = \"#f0f0f0\"\nforeground = \"#202020\"\naccent = \"#3366aa\"\n");
    writeFile(shipped, "-- rounding = 9\nrounding = 5\n");
    m_theme->setMode(QStringLiteral("system"));
    QVERIFY(!m_theme->pill());
    QCOMPARE(m_theme->rounding(), 5);
    QCOMPARE(m_theme->inset(), m_theme->gapS());
    QCOMPARE(submit->property("radius").toReal(), 5.0);

    // Light or dark only picks colours; the corners stay the desktop's.
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(!m_theme->pill());
    QCOMPARE(m_theme->rounding(), 5);
    m_theme->setMode(QStringLiteral("dark"));
    QVERIFY(!m_theme->pill());
    QCOMPARE(m_theme->rounding(), 5);
    QCOMPARE(submit->property("radius").toReal(), 5.0);
    m_theme->setMode(QStringLiteral("system"));

    writeFile(mine, "general = {}\n");
    m_theme->setMode(QStringLiteral("light"));
    m_theme->setMode(QStringLiteral("system"));
    QCOMPARE(m_theme->rounding(), 5);
    writeFile(mine, "rounding = 0\n");
    m_theme->setMode(QStringLiteral("light"));
    m_theme->setMode(QStringLiteral("system"));
    QCOMPARE(m_theme->rounding(), 0);
    QCOMPARE(m_theme->inset(), 0);

    QVERIFY(QFile::remove(mine));
    QVERIFY(QFile::remove(shipped));
    m_theme->setMode(QStringLiteral("light"));
    m_theme->setMode(QStringLiteral("system"));
    QVERIFY(!m_theme->pill());
    QCOMPARE(m_theme->rounding(), 0);
    QVERIFY(QFile::remove(colours));
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(m_theme->pill());
    QCOMPARE(m_theme->rounding(), Theme::kSoftCorner);
}

// Sign in to trash-and-restore without touching the mouse.
void TestStudio::keyboardDrivesTheExplorer()
{
    signInAsOk();
    QTRY_COMPARE(focusName(), QStringLiteral("entryRow0"));
    QCOMPARE(m_session->level(), QStringLiteral("orgs"));

    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
    QVERIFY(waitIdle());
    QTRY_VERIFY(shown(QStringLiteral("emptyState")));

    key(Qt::Key_N);
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    type(QStringLiteral("Inbox"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->level(), QStringLiteral("files"));
    QVERIFY(waitIdle());

    key(Qt::Key_N);
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    type(QStringLiteral("Contracts"));
    key(Qt::Key_Return);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QCOMPARE(propertyOf(QStringLiteral("itemCount"), "text").toString(), QStringLiteral("1 item"));

    const QString contracts = entryId(QStringLiteral("Contracts"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->currentFolderId(), contracts);
    QVERIFY(waitIdle());
    key(Qt::Key_Backspace);
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    key(Qt::Key_Left, Qt::AltModifier);
    QTRY_COMPARE(m_session->currentFolderId(), contracts);
    QVERIFY(waitIdle());
    key(Qt::Key_Right, Qt::AltModifier);
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());

    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());
    key(Qt::Key_End);
    QTRY_VERIFY(!m_session->currentDocumentId().isEmpty());

    key(Qt::Key_F2);
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    QCOMPARE(window()->activeFocusItem()->property("text").toString(), QStringLiteral("Notes"));
    QTest::keyClick(window(), Qt::Key_A, Qt::ControlModifier);
    type(QStringLiteral("Minutes"));
    key(Qt::Key_Return);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Minutes")));
    QVERIFY(waitIdle());

    key(Qt::Key_End);
    key(Qt::Key_X, Qt::ControlModifier);
    QVERIFY(m_session->hasClipboard());
    QVERIFY(propertyOf(QStringLiteral("explorerStatus"), "text").toString().startsWith(u"Cut."));
    key(Qt::Key_Home);
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->currentFolderId(), contracts);
    QVERIFY(waitIdle());
    key(Qt::Key_V, Qt::ControlModifier);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Minutes")));
    QVERIFY(waitIdle());
    QVERIFY(!m_session->hasClipboard());

    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Minutes")));
    key(Qt::Key_Delete);
    QTRY_COMPARE(m_session->entries()->rowCount(), 0);
    QVERIFY(waitIdle());
    key(Qt::Key_Z, Qt::ControlModifier);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Minutes")));
    QVERIFY(waitIdle());

    key(Qt::Key_F, Qt::ControlModifier);
    QTRY_COMPARE(focusName(), QStringLiteral("filterField"));
    type(QStringLiteral("zz"));
    QTRY_COMPARE(m_session->entries()->rowCount(), 0);
    QTRY_VERIFY(propertyOf(QStringLiteral("emptyText"), "text").toString().contains(u"zz"));
    key(Qt::Key_Escape);
    QCOMPARE(m_session->filter(), QString());
    QCOMPARE(focusName(), QStringLiteral("filterField"));
    key(Qt::Key_Escape);
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));

    key(Qt::Key_F10, Qt::ShiftModifier);
    QTRY_VERIFY(menuOpen() && focusName().startsWith(u"menu_"));
    QTRY_VERIFY(itemNamed(QStringLiteral("menu_rename")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!menuOpen());
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QCOMPARE(m_session->currentFolderId(), contracts);

    key(Qt::Key_Menu);
    QTRY_VERIFY(menuOpen() && focusName().startsWith(u"menu_"));
    key(Qt::Key_Down);
    QCOMPARE(propertyOf(QStringLiteral("contextMenuList"), "currentIndex").toInt(), 1);
    key(Qt::Key_Home);
    QTRY_VERIFY(itemNamed(QStringLiteral("menu_download")));
    key(Qt::Key_Return);
    QTRY_VERIFY(!m_opened.isEmpty() && m_opened.constLast().toLocalFile().startsWith(m_home.path()));

    key(Qt::Key_Escape);
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());
    key(Qt::Key_Escape);
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
    QVERIFY(waitIdle());
    key(Qt::Key_Escape);
    QTRY_COMPARE(m_session->level(), QStringLiteral("orgs"));
}

void TestStudio::tabReachesEveryRegion()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("explorer")), "focusDefault");
    settle();
    QSet<QString> regions;
    QSet<QString> names;
    for (int i = 0; i < 40; ++i) {
        regions.insert(regionOf(window()->activeFocusItem()));
        names.insert(focusName());
        key(Qt::Key_Tab);
    }
    for (const char *region : {"topBar", "sidebar", "toolbar", "entryPane", "statusBar"})
        QVERIFY2(regions.contains(QString::fromLatin1(region)), region);
    for (const char *name : {"homeLink", "backButton", "upButton", "crumb0", "crumb2",
                             "filterField", "newButton", "uploadButton", "accountButton"})
        QVERIFY2(names.contains(QString::fromLatin1(name)), name);
    QVERIFY(!names.contains(QStringLiteral("forwardButton")));
}

void TestStudio::f6CyclesRegions()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    const QStringList order{QStringLiteral("statusBar"), QStringLiteral("topBar"),
                            QStringLiteral("sidebar"), QStringLiteral("toolbar"),
                            QStringLiteral("entryPane")};
    for (const QString &region : order) {
        key(Qt::Key_F6);
        QCOMPARE(regionOf(window()->activeFocusItem()), region);
    }
    key(Qt::Key_F6, Qt::ShiftModifier);
    QCOMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("toolbar"));
    key(Qt::Key_F, Qt::ControlModifier);
    QCOMPARE(focusName(), QStringLiteral("filterField"));
    key(Qt::Key_F6);
    QCOMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("sidebar"));
}

void TestStudio::keyboardWalksTheTree()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    addFolder(QStringLiteral("Signed"));
    m_session->navigate(QStringLiteral("folder"), QString());
    QVERIFY(waitIdle());

    QTRY_COMPARE(propertyOf(QStringLiteral("folderTree"), "count").toInt(), 3);
    focusOn(waitItem(QStringLiteral("folderTree")));
    QTRY_COMPARE(focusName(), QStringLiteral("treeRow0"));
    key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("treeRow1"));
    key(Qt::Key_Left);
    QTRY_COMPARE(propertyOf(QStringLiteral("folderTree"), "count").toInt(), 2);
    key(Qt::Key_Left);
    QTRY_COMPARE(focusName(), QStringLiteral("treeRow0"));
    key(Qt::Key_Down);
    key(Qt::Key_Right);
    QTRY_COMPARE(propertyOf(QStringLiteral("folderTree"), "count").toInt(), 3);
    key(Qt::Key_Right);
    QCOMPARE(focusName(), QStringLiteral("treeRow2"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());
    QCOMPARE(m_session->trail().size(), 5);
    QCOMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("sidebar"));
    key(Qt::Key_Home);
    key(Qt::Key_Return);
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());

    focusOn(waitItem(QStringLiteral("spaceList")));
    key(Qt::Key_End);
    key(Qt::Key_Return);
    QTRY_VERIFY(!m_session->currentSpaceId().isEmpty());
    focusOn(waitItem(QStringLiteral("orgList")));
    key(Qt::Key_Up);
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
}

void TestStudio::keyboardOpensSheetKeymapAndUpload()
{
    openSpace(QStringLiteral("Inbox"));
    key(Qt::Key_Colon);
    QTRY_VERIFY(shown(QStringLiteral("commandSheet")));
    QTRY_COMPARE(focusName(), QStringLiteral("sheetQuery"));
    type(QStringLiteral("new"));
    key(Qt::Key_Return);
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    QVERIFY(!shown(QStringLiteral("commandSheet")));
    key(Qt::Key_Escape);
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QCOMPARE(m_session->level(), QStringLiteral("files"));

    key(Qt::Key_Question, Qt::ShiftModifier);
    QTRY_VERIFY(shown(QStringLiteral("keymapSheet")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("keymapSheet")));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));

    QQuickItem *explorer = waitItem(QStringLiteral("explorer"));
    QVERIFY(explorer);
    QObject *dialog = explorer->findChild<QObject *>(QStringLiteral("uploadDialog"));
    QVERIFY(dialog);
    key(Qt::Key_U);
    QTRY_VERIFY(dialog->property("visible").toBool());
    QMetaObject::invokeMethod(dialog, "reject");
    QTRY_VERIFY(!dialog->property("visible").toBool());
}

void TestStudio::mouseBrowsesTheExplorer()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Archive"));
    addFolder(QStringLiteral("Contracts"));
    const QString archive = entryId(QStringLiteral("Archive"));
    m_session->openEntry(QStringLiteral("folder"), archive);
    QVERIFY(waitIdle());
    addFolder(QStringLiteral("Old"));
    m_session->runCommand(QStringLiteral("up"));
    QVERIFY(waitIdle());

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QTRY_VERIFY(rowProperty(QStringLiteral("entryRow"), QStringLiteral("Contracts"), "selected").toBool());
    QVERIFY(m_session->currentFolderId().isEmpty());
    const QString contractsId = entryId(QStringLiteral("Contracts"));
    // The click above left the pointer on the row; the second click opens it.
    QQuickItem *contracts = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    QVERIFY(contracts);
    QTest::mouseDClick(window(), Qt::LeftButton, Qt::NoModifier, centreOf(contracts));
    settle();
    QTRY_COMPARE(m_session->currentFolderId(), contractsId);
    QVERIFY(waitIdle());

    clickItem(waitItem(QStringLiteral("crumb1")));
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());

    QQuickItem *archiveNode = waitRow(QStringLiteral("treeRow"), QStringLiteral("Archive"));
    QVERIFY(archiveNode);
    QVERIFY(archiveNode->property("expandable").toBool());
    const bool open = archiveNode->property("expanded").toBool();
    QQuickItem *chevron = nullptr;
    for (QQuickItem *child : archiveNode->findChildren<QQuickItem *>(QStringLiteral("disclosure")))
        chevron = child;
    clickItem(chevron);
    // Folding re-creates the row, so look it up again.
    QTRY_COMPARE(rowProperty(QStringLiteral("treeRow"), QStringLiteral("Archive"), "expanded").toBool(), !open);
    QVERIFY(m_session->currentFolderId().isEmpty());
    clickItem(waitRow(QStringLiteral("treeRow"), QStringLiteral("Archive")));
    QTRY_COMPARE(m_session->currentFolderId(), archive);
    QVERIFY(waitIdle());

    clickItem(waitItem(QStringLiteral("backButton")));
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());
    clickItem(waitItem(QStringLiteral("forwardButton")));
    QTRY_COMPARE(m_session->currentFolderId(), archive);
    QVERIFY(waitIdle());
    clickItem(waitItem(QStringLiteral("upButton")));
    QTRY_VERIFY(m_session->currentFolderId().isEmpty());
    QVERIFY(waitIdle());

    clickItem(waitRow(QStringLiteral("spaceRow"), QStringLiteral("Inbox")));
    clickItem(waitItem(QStringLiteral("crumb0")));
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
    QVERIFY(waitIdle());
    clickItem(waitItem(QStringLiteral("homeLink")));
    QTRY_COMPARE(m_session->level(), QStringLiteral("orgs"));
    QVERIFY(waitIdle());
    clickItem(waitRow(QStringLiteral("orgRow"), QStringLiteral("ok organization")));
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
}

void TestStudio::mouseEditsFromToolbarAndMenu()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"));
    clickItem(waitItem(QStringLiteral("refreshButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());

    QQuickItem *list = waitItem(QStringLiteral("entryList"));
    QVERIFY(list);
    const qreal listTop = list->mapToScene(QPointF()).y();
    clickItem(waitItem(QStringLiteral("newButton")));
    QTRY_VERIFY(shown(QStringLiteral("newRow")));
    QCOMPARE(focusName(), QStringLiteral("rowEditor"));
    // The new row pushes the list down once laid out; click after that.
    QTRY_VERIFY(list->mapToScene(QPointF()).y() > listTop);
    clickItem(window()->activeFocusItem());
    QCOMPARE(focusName(), QStringLiteral("rowEditor"));
    type(QStringLiteral("Drafts"));
    key(Qt::Key_Return);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));
    QVERIFY(waitIdle());

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QTRY_VERIFY(!m_session->currentDocumentId().isEmpty());
    clickItem(waitItem(QStringLiteral("downloadButton")));
    QTRY_VERIFY(!m_opened.isEmpty() && m_opened.constLast().toLocalFile().startsWith(m_home.path()));

    clickItem(waitItem(QStringLiteral("renameButton")));
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    key(Qt::Key_Escape);
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Notes")), Qt::RightButton);
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_rename")));
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    QTest::keyClick(window(), Qt::Key_A, Qt::ControlModifier);
    type(QStringLiteral("Memo"));
    key(Qt::Key_Return);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());

    // The menu opens over the rows below the first: a click on its Rename is
    // the menu's alone and renames the row the menu is for. A folder's menu
    // offers no Download.
    QQuickItem *contracts = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    clickItem(contracts, Qt::RightButton);
    QTRY_VERIFY(menuOpen());
    QVERIFY(!itemNamed(QStringLiteral("menu_download")));
    QQuickItem *rename = waitItem(QStringLiteral("menu_rename"));
    QVERIFY(rename->mapToScene(QPointF(0, rename->height() / 2)).y()
            > contracts->mapToScene(QPointF(0, contracts->height())).y());
    clickItem(rename);
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    QCOMPARE(window()->activeFocusItem()->property("text").toString(), QStringLiteral("Contracts"));
    key(Qt::Key_Escape);
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    clickItem(waitItem(QStringLiteral("trashButton")));
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());
    QTRY_VERIFY(shown(QStringLiteral("restoreButton")));
    clickItem(waitItem(QStringLiteral("restoreButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());

    const QPoint blank = list->mapToScene(QPointF(list->width() / 2, list->height() - 20)).toPoint();
    QTest::mouseClick(window(), Qt::RightButton, Qt::NoModifier, blank);
    settle();
    QTRY_VERIFY(menuOpen());
    QTRY_VERIFY(itemNamed(QStringLiteral("menu_new")));
    QVERIFY(!shown(QStringLiteral("menu_rename")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!menuOpen());
}

// Rows go by mouse onto a folder row, a tree node, or a crumb; a folder
// dropped on itself stays where it is.
void TestStudio::dragAndDropMovesPayloads()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Archive"));
    addFolder(QStringLiteral("Contracts"));
    const QString archive = entryId(QStringLiteral("Archive"));
    const QString space = m_session->currentSpaceId();
    m_core.seedDocument(space, QStringLiteral("Notes"));
    m_core.seedDocument(space, QStringLiteral("Budget"));
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Budget")));
    QVERIFY(waitIdle());

    // A row onto a folder row.
    dragOnto(waitRow(QStringLiteral("entryRow"), QStringLiteral("Notes")),
             waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());

    // A folder onto itself is refused.
    QQuickItem *contracts = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    dragOnto(contracts, contracts);
    QVERIFY(waitIdle());
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QCOMPARE(m_session->entries()->rowCount(), 3);

    // A row onto a tree node.
    dragOnto(waitRow(QStringLiteral("entryRow"), QStringLiteral("Budget")),
             waitRow(QStringLiteral("treeRow"), QStringLiteral("Archive")));
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Budget")));
    QVERIFY(waitIdle());

    // A folder onto a tree node, then a document back onto the space crumb.
    dragOnto(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")),
             waitRow(QStringLiteral("treeRow"), QStringLiteral("Archive")));
    QTRY_COMPARE(m_session->entries()->rowCount(), 1);
    QVERIFY(waitIdle());
    m_session->openEntry(QStringLiteral("folder"), archive);
    QVERIFY(waitIdle());
    QTRY_COMPARE(m_session->entries()->rowCount(), 2);
    dragOnto(waitRow(QStringLiteral("entryRow"), QStringLiteral("Budget")), waitItem(QStringLiteral("crumb1")));
    QTRY_COMPARE(m_session->entries()->rowCount(), 1);
    QVERIFY(waitIdle());
    QVERIFY(m_core.documentTitled(QStringLiteral("Budget")).value(QStringLiteral("folder_id")).isNull());
}

// Files from the desktop: the list offers itself while they hover, every
// file lands in the open folder with its bytes, one after another. Outside
// a space the list refuses them.
void TestStudio::droppedFilesUpload()
{
    signInAsOk();
    auto *early = new QMimeData;
    early->setUrls({scratchFile(QStringLiteral("early.txt"), "early")});
    dropOn(waitItem(QStringLiteral("entryList")), early);
    QVERIFY(!m_session->uploadBusy());
    QVERIFY(m_core.documentTitled(QStringLiteral("early.txt")).isEmpty());

    QVERIFY(openOwnOrg());
    QVERIFY(createSpace(QStringLiteral("Inbox")));
    addFolder(QStringLiteral("Reports"));
    const QString reports = entryId(QStringLiteral("Reports"));
    m_session->openEntry(QStringLiteral("folder"), reports);
    QVERIFY(waitIdle());

    auto *mime = new QMimeData;
    mime->setUrls({scratchFile(QStringLiteral("q1.txt"), "first quarter"),
                   scratchFile(QStringLiteral("q2.txt"), "second quarter"),
                   scratchFile(QStringLiteral("日本語.txt"), "三番目")});
    bool overlaid = false;
    dropOn(waitItem(QStringLiteral("entryList")), mime,
           [&] { overlaid = QTest::qWaitFor([&] { return shown(QStringLiteral("dropOverlay")); }); });
    QVERIFY(overlaid);
    QTRY_VERIFY(!shown(QStringLiteral("dropOverlay")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("日本語.txt")));
    QTRY_VERIFY(!m_session->uploadBusy());
    QCOMPARE(m_core.landed(QStringLiteral("q1.txt")), FakeCore::sha256("first quarter"));
    QCOMPARE(m_core.landed(QStringLiteral("q2.txt")), FakeCore::sha256("second quarter"));
    QCOMPARE(m_core.landed(QStringLiteral("日本語.txt")), FakeCore::sha256("三番目"));
    QCOMPARE(m_core.documentTitled(QStringLiteral("q2.txt")).value(QStringLiteral("folder_id")).toString(),
             reports);
    QCOMPARE(statusText(), QString());
}

// "u" opens the file dialog; choosing a file uploads its bytes as they are.
void TestStudio::uploadDialogSendsTheChosenFile()
{
    openSpace(QStringLiteral("Inbox"));
    const QByteArray bytes("\x00\x01binary\xff", 9);
    writeFile(m_home.filePath(QStringLiteral("picker/scan.bin")), bytes);
    QObject *dialog = waitItem(QStringLiteral("explorer"))->findChild<QObject *>(QStringLiteral("uploadDialog"));
    QVERIFY(dialog);
    key(Qt::Key_U);
    QTRY_VERIFY(dialog->property("visible").toBool());
    QCOMPARE(dialog->property("fileMode").toInt(), 1); // FileDialog.OpenFiles
    dialog->setProperty("currentFolder", QUrl::fromLocalFile(m_home.filePath(QStringLiteral("picker"))));
    // The dialog is its own window: pick the file there by keyboard.
    QQuickWindow *picker = nullptr;
    QTRY_VERIFY(picker = qobject_cast<QQuickWindow *>(QGuiApplication::focusWindow()));
    QVERIFY(picker != window());
    QTRY_VERIFY(itemNamed(QStringLiteral("fileDialogDelegate0"), picker));
    QCOMPARE(picker->activeFocusItem()->objectName(), QStringLiteral("fileDialogListView"));
    QTest::keyClick(picker, Qt::Key_Down);
    QTest::keyClick(picker, Qt::Key_Return);
    QTRY_VERIFY(!dialog->property("visible").toBool());
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("scan.bin")));
    QTRY_VERIFY(!m_session->uploadBusy());
    QCOMPARE(m_core.landed(QStringLiteral("scan.bin")), FakeCore::sha256(bytes));
    QCOMPARE(m_core.documentTitled(QStringLiteral("scan.bin")).value(QStringLiteral("content_size")).toInt(),
             bytes.size());
}

// The status line counts the files and shows the one on the wire filling up.
// Core holds each step's answer while the test looks at the state it leaves.
void TestStudio::uploadShowsProgressPerFile()
{
    openSpace(QStringLiteral("Inbox"));
    QVERIFY(!shown(QStringLiteral("uploadProgress")));
    QVERIFY(m_core.failNext(QStringLiteral("POST"), QStringLiteral("/uploads$"), 2, FakeCore::FaultMode::Hold));
    QVERIFY(m_core.failNext(QStringLiteral("POST"), QStringLiteral("/complete$"), 1, FakeCore::FaultMode::Hold));
    m_session->uploadUrls({scratchFile(QStringLiteral("a.txt"), "aaaa"),
                           scratchFile(QStringLiteral("b.txt"), "bbbb")});
    QTRY_COMPARE(m_core.held(), 1);
    QVERIFY(shown(QStringLiteral("uploadProgress")));
    QCOMPARE(propertyOf(QStringLiteral("uploadText"), "text").toString(),
             QStringLiteral("Uploading 1 of 2 · 0%"));
    m_core.release();

    QTRY_COMPARE(m_core.held(), 1);
    QCOMPARE(propertyOf(QStringLiteral("uploadText"), "text").toString(),
             QStringLiteral("Uploading 1 of 2 · 100%"));
    QQuickItem *bar = itemNamed(QStringLiteral("uploadBar"));
    QCOMPARE(bar->width(), bar->parentItem()->width());
    QAccessibleInterface *progress = QAccessible::queryAccessibleInterface(itemNamed(QStringLiteral("uploadProgress")));
    QCOMPARE(progress->role(), QAccessible::ProgressBar);
    QCOMPARE(progress->text(QAccessible::Name), QStringLiteral("Uploading 1 of 2 · 100%"));
    m_core.release();

    QTRY_COMPARE(m_core.held(), 1);
    QCOMPARE(propertyOf(QStringLiteral("uploadText"), "text").toString(),
             QStringLiteral("Uploading 2 of 2 · 0%"));
    m_core.release();
    QTRY_VERIFY(!shown(QStringLiteral("uploadProgress")));
    QVERIFY(waitIdle());
    QCOMPARE(m_session->entryCount(), 2);
}

// A file that cannot be read or that Core refuses is named in the status
// line, in the error colour; the others in the batch still land.
void TestStudio::uploadFailuresAreNamed()
{
    openSpace(QStringLiteral("Inbox"));
    auto *mime = new QMimeData;
    mime->setUrls({QUrl::fromLocalFile(m_home.filePath(QStringLiteral("files/missing.txt"))),
                   scratchFile(QStringLiteral("kept.txt"), "kept")});
    dropOn(waitItem(QStringLiteral("entryList")), mime);
    QTRY_VERIFY(!m_session->uploadBusy());
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("kept.txt")));
    QCOMPARE(m_core.landed(QStringLiteral("kept.txt")), FakeCore::sha256("kept"));
    QCOMPARE(statusText(), QStringLiteral("Could not read “missing.txt”."));
    QCOMPARE(propertyOf(QStringLiteral("explorerStatus"), "color").value<QColor>(), m_theme->failed());

    const struct {
        const char *name;
        const char *method;
        const char *path;
        FakeCore::FaultMode mode;
        int status;
        int count;
        const char *words;
    } faults[] = {
            {"server.txt", "POST", "/uploads$", FakeCore::FaultMode::Status, 500, 1,
             "Could not upload “server.txt”: Core could not complete that request."},
            {"dropped.txt", "PUT", "^/files/", FakeCore::FaultMode::Drop, 0, 2,
             "Could not upload “dropped.txt”: Core or storage could not be reached."},
            {"refused.txt", "POST", "/complete$", FakeCore::FaultMode::Status, 422, 1,
             "Could not upload “refused.txt”: Core refused it."},
    };
    for (const auto &fault : faults) {
        QVERIFY(m_core.failNext(QLatin1String(fault.method), QLatin1String(fault.path), fault.count,
                                fault.mode, fault.status, QStringLiteral("verification_failed")));
        m_session->uploadUrls({scratchFile(QLatin1String(fault.name), "bad")});
        QTRY_COMPARE(statusText(), QString::fromUtf8(fault.words));
        QTRY_VERIFY(!m_session->uploadBusy());
        QVERIFY(m_core.landed(QLatin1String(fault.name)).isEmpty());
    }
    // A file named like something already here does not replace it.
    m_session->uploadUrls({scratchFile(QStringLiteral("KEPT.txt"), "other")});
    QTRY_COMPARE(statusText(), QStringLiteral("Could not upload “KEPT.txt”: something here already has that name."));
    QTRY_VERIFY(!m_session->uploadBusy());
    QCOMPARE(m_core.landed(QStringLiteral("kept.txt")), FakeCore::sha256("kept"));
    key(Qt::Key_Backspace);
    QTRY_COMPARE(m_session->level(), QStringLiteral("spaces"));
    QCOMPARE(statusText(), QString());
}

// Core refuses a name the place already holds, in any case and whether a
// folder or a document holds it, and a name no disk could hold; the window
// says which and nothing changes.
void TestStudio::refusedNamesSayWhy()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Drafts"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());
    const QString taken = QStringLiteral("Something here already has that name.");
    const QString unusable = QStringLiteral("Names cannot be “.” or “..”, or contain slashes, backslashes or control characters.");

    const auto create = [&](const QString &name) {
        clickItem(waitItem(QStringLiteral("newButton")));
        QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
        type(name);
        key(Qt::Key_Return);
    };
    create(QStringLiteral("drafts"));
    QTRY_COMPARE(statusText(), taken);
    QCOMPARE(propertyOf(QStringLiteral("explorerStatus"), "color").value<QColor>(), m_theme->failed());
    create(QStringLiteral(".."));
    QTRY_COMPARE(statusText(), unusable);

    const auto rename = [&](const QString &name) {
        clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Drafts")), Qt::RightButton);
        QTRY_VERIFY(menuOpen());
        clickItem(waitItem(QStringLiteral("menu_rename")));
        QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
        QTest::keyClick(window(), Qt::Key_A, Qt::ControlModifier);
        type(name);
        key(Qt::Key_Return);
    };
    rename(QStringLiteral("NOTES"));
    QTRY_COMPARE(statusText(), taken);
    rename(QStringLiteral("a/b"));
    QTRY_COMPARE(statusText(), unusable);
    QVERIFY(waitIdle());
    QCOMPARE(m_session->entryCount(), 2);
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));
}

// A folder or document someone else changed first: Core refuses the
// window's change, the list shows what Core holds now, and the window says
// to try again. A trashed document changed elsewhere is no longer offered
// for restore.
void TestStudio::aStaleRowReloadsAndSaysWhy()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Drafts"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());
    const QString changed = QStringLiteral("That changed on Core first. The list is current now; try again.");

    m_core.renameElsewhere(QStringLiteral("Drafts"), QStringLiteral("Plans"));
    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Drafts")), Qt::RightButton);
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_rename")));
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    QTest::keyClick(window(), Qt::Key_A, Qt::ControlModifier);
    type(QStringLiteral("Ideas"));
    key(Qt::Key_Return);
    QTRY_COMPARE(statusText(), changed);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Plans")));
    QVERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Ideas")));

    m_core.renameElsewhere(QStringLiteral("Notes"), QStringLiteral("Memo"));
    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    key(Qt::Key_Delete);
    QTRY_COMPARE(statusText(), changed);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());
    QCOMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 0);
    QCOMPARE(m_session->entryCount(), 2);

    // Changed in the trash elsewhere: the restore is refused and no longer offered.
    key(Qt::Key_F5);
    QVERIFY(waitIdle());
    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    key(Qt::Key_Delete);
    QTRY_COMPARE(statusText(), QStringLiteral("Moved to trash. Restore brings it back."));
    QVERIFY(waitIdle());
    m_core.changeTrashedElsewhere(QStringLiteral("Memo"));
    clickItem(waitItem(QStringLiteral("restoreButton")));
    QTRY_COMPARE(statusText(), changed);
    QVERIFY(waitIdle());
    QVERIFY(!shown(QStringLiteral("restoreButton")));
    QVERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QCOMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 1);
}

// Purge from the command sheet empties Core's trash for good; a refused
// purge says so and keeps the item restorable.
void TestStudio::purgeEmptiesTheTrash()
{
    openSpace(QStringLiteral("Inbox"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Draft"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Memo"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());
    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Draft")));
    key(Qt::Key_Delete);
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Draft")));
    QVERIFY(waitIdle());
    QCOMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 1);
    QTRY_VERIFY(shown(QStringLiteral("restoreButton")));

    key(Qt::Key_Colon);
    QTRY_COMPARE(focusName(), QStringLiteral("sheetQuery"));
    type(QStringLiteral("purge"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 0);
    QTRY_VERIFY(!shown(QStringLiteral("restoreButton")));
    QCOMPARE(statusText(), QString());

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    key(Qt::Key_Delete);
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());
    m_core.forcedStatus = 500;
    m_session->runCommand(QStringLiteral("purge"));
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(),
                 QStringLiteral("Core could not complete that request."));
    QCOMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 1);
    m_core.forcedStatus = 0;
    QVERIFY(shown(QStringLiteral("restoreButton")));
    clickItem(waitItem(QStringLiteral("restoreButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
}

// A folder has no trash: Del and the menu offer to delete it for good and
// ask first. Cancel keeps it; Delete removes it and leaves nothing to
// restore. Core refuses a folder that holds anything, and the window says
// so. A document still goes to the trash, restorable, without asking.
void TestStudio::deletingAFolderAsksFirst()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Drafts"));
    addFolder(QStringLiteral("Plans"));
    const QString spaceId = m_session->currentSpaceId();
    m_core.seedDocument(spaceId, QStringLiteral("Inside"), entryId(QStringLiteral("Plans")));
    m_core.seedDocument(spaceId, QStringLiteral("Memo"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(waitIdle());

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Drafts")));
    QTRY_COMPARE(propertyOf(QStringLiteral("trashButton"), "text").toString(), QStringLiteral("Delete folder"));
    QCOMPARE(propertyOf(QStringLiteral("trashButton"), "icon").toString(), QStringLiteral("purge"));
    key(Qt::Key_Delete);
    QTRY_VERIFY(shown(QStringLiteral("deleteConfirm")));
    QCOMPARE(focusName(), QStringLiteral("confirmCancel"));
    QCOMPARE(propertyOf(QStringLiteral("overlayTitle"), "text").toString(),
             QStringLiteral("Delete folder \u201cDrafts\u201d?"));
    QCOMPARE(propertyOf(QStringLiteral("confirmDetail"), "text").toString(),
             QStringLiteral("This cannot be undone."));
    // Keys that are not the dialog's run no command under it.
    key(Qt::Key_Backspace);
    QCOMPARE(m_session->level(), QStringLiteral("files"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("deleteConfirm")));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));

    clickItem(waitItem(QStringLiteral("trashButton")));
    QTRY_VERIFY(shown(QStringLiteral("deleteConfirm")));
    clickItem(waitItem(QStringLiteral("confirmCancel")));
    QTRY_VERIFY(!shown(QStringLiteral("deleteConfirm")));
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));

    key(Qt::Key_Delete);
    QTRY_VERIFY(shown(QStringLiteral("deleteConfirm")));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("confirmAccept"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));
    QVERIFY(waitIdle());
    QVERIFY(m_session->lastTrashedId().isEmpty());
    QVERIFY(!shown(QStringLiteral("restoreButton")));
    QCOMPARE(m_core.state().value(QStringLiteral("trash")).toArray().size(), 0);
    QCOMPARE(statusText(), QString());

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Plans")), Qt::RightButton);
    QTRY_VERIFY(menuOpen());
    QCOMPARE(QAccessible::queryAccessibleInterface(waitItem(QStringLiteral("menu_trash")))
                     ->text(QAccessible::Name),
             QStringLiteral("Delete folder"));
    clickItem(waitItem(QStringLiteral("menu_trash")));
    QTRY_VERIFY(shown(QStringLiteral("deleteConfirm")));
    clickItem(waitItem(QStringLiteral("confirmAccept")));
    QTRY_COMPARE(statusText(), QStringLiteral("Only an empty folder can be deleted."));
    QVERIFY(waitIdle());
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Plans")));
    QVERIFY(!shown(QStringLiteral("restoreButton")));

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QTRY_COMPARE(propertyOf(QStringLiteral("trashButton"), "text").toString(), QStringLiteral("Move to trash"));
    QCOMPARE(propertyOf(QStringLiteral("trashButton"), "icon").toString(), QStringLiteral("trash"));
    key(Qt::Key_Delete);
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QVERIFY(!shown(QStringLiteral("deleteConfirm")));
    QVERIFY(waitIdle());
    QTRY_VERIFY(shown(QStringLiteral("restoreButton")));
    clickItem(waitItem(QStringLiteral("restoreButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
}

// Core refuses a folder pasted into itself or below itself; the window says
// why and nothing moves.
void TestStudio::folderCycleIsRefused()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Outer"));
    const QString outer = entryId(QStringLiteral("Outer"));
    m_session->openEntry(QStringLiteral("folder"), outer);
    QVERIFY(waitIdle());
    addFolder(QStringLiteral("Inner"));
    m_session->runCommand(QStringLiteral("up"));
    QVERIFY(waitIdle());

    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Outer")));
    key(Qt::Key_X, Qt::ControlModifier);
    QVERIFY(m_session->hasClipboard());
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->currentFolderId(), outer);
    QVERIFY(waitIdle());
    key(Qt::Key_V, Qt::ControlModifier);
    QTRY_COMPARE(statusText(), QStringLiteral("A folder cannot move into itself."));
    QCOMPARE(propertyOf(QStringLiteral("explorerStatus"), "color").value<QColor>(), m_theme->failed());

    m_session->runCommand(QStringLiteral("up"));
    QVERIFY(waitIdle());
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Outer")));
    key(Qt::Key_X, Qt::ControlModifier);
    m_session->openEntry(QStringLiteral("folder"), outer);
    QVERIFY(waitIdle());
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Inner")));
    QVERIFY(waitIdle());
    key(Qt::Key_V, Qt::ControlModifier);
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(),
                 QStringLiteral("A folder cannot move into itself."));
    QVERIFY(m_core.state().value(QStringLiteral("folders")).toArray().at(0).toObject()
                    .value(QStringLiteral("parent_id")).isNull());
}

void TestStudio::touchOpensAndLongPressesForAMenu()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    tapItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")), 1200);
    QTRY_VERIFY(menuOpen());
    QVERIFY(m_session->currentFolderId().isEmpty());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!menuOpen());
    tapItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QTRY_VERIFY(!m_session->currentFolderId().isEmpty());
}

void TestStudio::narrowWidthUsesADrawer()
{
    openSpace(QStringLiteral("Inbox"));
    window()->resize(400, 800);
    settle();
    QQuickItem *sidebar = waitItem(QStringLiteral("sidebar"));
    QVERIFY(sidebar);
    QTRY_VERIFY(!sidebar->isVisible());
    QVERIFY(!shown(QStringLiteral("toolbar")));
    QTRY_VERIFY(shown(QStringLiteral("fabButton")));

    tapItem(waitItem(QStringLiteral("fabButton")));
    QTRY_VERIFY(menuOpen());
    tapItem(waitItem(QStringLiteral("menu_new")));
    QTRY_COMPARE(focusName(), QStringLiteral("rowEditor"));
    type(QStringLiteral("Contracts"));
    key(Qt::Key_Return);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    QCOMPARE(rowProperty(QStringLiteral("entryRow"), QStringLiteral("Contracts"), "height").toReal(),
             qreal(m_theme->rowTouch()));
    QCOMPARE(propertyOf(QStringLiteral("locationTitle"), "font").value<QFont>().pixelSize(),
             m_theme->heading().pixelSize());

    tapItem(waitItem(QStringLiteral("drawerButton")));
    QTRY_COMPARE(sidebar->x(), 0.0);
    QVERIFY(sidebar->isVisible());
    QCOMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("sidebar"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!sidebar->isVisible());
    QCOMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QCOMPARE(m_session->level(), QStringLiteral("files"));

    tapItem(waitItem(QStringLiteral("drawerButton")));
    QTRY_COMPARE(sidebar->x(), 0.0);
    QQuickItem *scrim = waitItem(QStringLiteral("drawerScrim"));
    QVERIFY(scrim);
    QTest::mouseClick(window(), Qt::LeftButton, Qt::NoModifier,
                      scrim->mapToScene(QPointF(scrim->width() - 10, scrim->height() / 2)).toPoint());
    settle();
    QTRY_VERIFY(!sidebar->isVisible());

    tapItem(waitItem(QStringLiteral("drawerButton")));
    QTRY_COMPARE(sidebar->x(), 0.0);
    tapItem(waitRow(QStringLiteral("treeRow"), QStringLiteral("Contracts")));
    QTRY_VERIFY(!m_session->currentFolderId().isEmpty());
    QTRY_VERIFY(!sidebar->isVisible());

    tapItem(waitItem(QStringLiteral("filterButton")));
    QTRY_COMPARE(focusName(), QStringLiteral("filterField"));
    QVERIFY(!shown(QStringLiteral("breadcrumb")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(shown(QStringLiteral("breadcrumb")));
    QVERIFY(!m_session->currentFolderId().isEmpty());
}

void TestStudio::safeAreaKeepsControlsBelowSystemBars()
{
    QQmlExpression addTop(qmlContext(window()), window(),
                          QStringLiteral("SafeArea.additionalMargins.top = 64"));
    addTop.evaluate();
    QVERIFY2(!addTop.hasError(), qPrintable(addTop.error().toString()));
    QQuickItem *content = waitItem(QStringLiteral("safeContent"));
    QVERIFY(content);
    QTRY_COMPARE(content->y(), 64.0);
    QTRY_COMPARE(content->height(), qreal(window()->height() - 64));
    QQuickItem *language = waitItem(QStringLiteral("languageSwitcher"));
    QVERIFY(language);
    QVERIFY(language->mapToScene(QPointF()).y() >= 64);
    QQmlExpression clearTop(qmlContext(window()), window(),
                            QStringLiteral("SafeArea.additionalMargins.top = 0"));
    clearTop.evaluate();
    QVERIFY2(!clearTop.hasError(), qPrintable(clearTop.error().toString()));
    QTRY_COMPARE(content->y(), 0.0);
}

// The マ mark is the way home: a button by key, pointer, or touch, named for
// screen readers, and never a drop target. The crumbs start below it.
void TestStudio::logoLinksHome()
{
    openSpace(QStringLiteral("Inbox"));
    QQuickItem *home = waitItem(QStringLiteral("homeLink"));
    QVERIFY(home);
    QAccessibleInterface *named = QAccessible::queryAccessibleInterface(home);
    QVERIFY(named);
    QCOMPARE(named->text(QAccessible::Name), QStringLiteral("Matome"));
    QCOMPARE(named->role(), QAccessible::Button);
    for (QQuickItem *child : home->findChildren<QQuickItem *>())
        QVERIFY(!child->inherits("QQuickDropArea"));
    QTRY_VERIFY(shown(QStringLiteral("crumb1")));
    QVERIFY(!shown(QStringLiteral("crumb2")));

    focusOn(home);
    key(Qt::Key_Tab, Qt::ShiftModifier);
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("homeLink"));
    QVERIFY(ringShown(QStringLiteral("homeLink")));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->level(), QStringLiteral("orgs"));
    QVERIFY(waitIdle());
    QTRY_VERIFY(!shown(QStringLiteral("crumb0")));

    QVERIFY(openOwnOrg());
    clickItem(waitItem(QStringLiteral("homeLink")));
    QTRY_COMPARE(m_session->level(), QStringLiteral("orgs"));
    QVERIFY(waitIdle());
    QVERIFY(openOwnOrg());
    tapItem(waitItem(QStringLiteral("homeLink")));
    QTRY_COMPARE(m_session->level(), QStringLiteral("orgs"));
}

// Above the list: what kind of place and what holds it, its name in the
// serif title, and the one item count.
void TestStudio::locationHeaderNamesThePlace()
{
    signInAsOk();
    QCOMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(),
             QStringLiteral("Organizations"));
    QCOMPARE(propertyOf(QStringLiteral("locationTitle"), "text").toString(), QStringLiteral("Matome"));
    QCOMPARE(propertyOf(QStringLiteral("itemCount"), "text").toString(), QStringLiteral("1 item"));
    const QFont title = propertyOf(QStringLiteral("locationTitle"), "font").value<QFont>();
    QCOMPARE(title.families().first(), m_theme->title().families().first());
    QCOMPARE(title.pixelSize(), m_theme->title().pixelSize());

    QVERIFY(openOwnOrg());
    QTRY_COMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(),
                 QStringLiteral("Organization"));
    QCOMPARE(propertyOf(QStringLiteral("locationTitle"), "text").toString(),
             QStringLiteral("ok organization"));

    QVERIFY(createSpace(QStringLiteral("Inbox")));
    QTRY_COMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(),
                 QStringLiteral("Space · ok organization"));
    QCOMPARE(propertyOf(QStringLiteral("locationTitle"), "text").toString(), QStringLiteral("Inbox"));
    QCOMPARE(propertyOf(QStringLiteral("itemCount"), "text").toString(), QStringLiteral("0 items"));

    addFolder(QStringLiteral("Contracts"));
    QCOMPARE(propertyOf(QStringLiteral("itemCount"), "text").toString(), QStringLiteral("1 item"));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    QTRY_COMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(),
                 QStringLiteral("Folder · Inbox"));
    QCOMPARE(propertyOf(QStringLiteral("locationTitle"), "text").toString(), QStringLiteral("Contracts"));
    QVERIFY(!propertyOf(QStringLiteral("explorerStatus"), "text").toString().contains(u"item"));

    // A screen reader reads the eyebrow, the count, and the status line.
    m_session->runCommand(QStringLiteral("up"));
    m_session->setFocusPayload(rowProperty(QStringLiteral("entryRow"), QStringLiteral("Contracts"), "payload")
                                       .toString());
    m_session->runCommand(QStringLiteral("cut"));
    QTRY_VERIFY(!propertyOf(QStringLiteral("explorerStatus"), "text").toString().isEmpty());
    for (const char *name : {"locationEyebrow", "itemCount", "explorerStatus"}) {
        QAccessibleInterface *read =
                QAccessible::queryAccessibleInterface(waitItem(QString::fromLatin1(name)));
        QVERIFY(read);
        QCOMPARE(read->text(QAccessible::Name), propertyOf(QString::fromLatin1(name), "text").toString());
    }
}

// No rows: the drawn pages over one phrase, for an empty place, while it
// loads (the lines write themselves), and when Core fails.
void TestStudio::emptyStateShowsLoadingAndErrors()
{
    openSpace(QStringLiteral("Inbox"));
    QTRY_VERIFY(shown(QStringLiteral("emptyState")));
    QCOMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("empty"));
    QCOMPARE(propertyOf(QStringLiteral("emptyText"), "color").value<QColor>(), m_theme->accentText());
    QVERIFY(propertyOf(QStringLiteral("emptyText"), "font").value<QFont>().italic());

    addFolder(QStringLiteral("Contracts"));
    QVERIFY(m_core.failNext(QStringLiteral("GET"), QStringLiteral("/documents$"), 1, FakeCore::FaultMode::Hold));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QTRY_COMPARE(m_core.held(), 1);
    QCOMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("loading"));
    QVERIFY(shown(QStringLiteral("emptyState")));
    QCOMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(), QStringLiteral("Loading…"));
    QVERIFY(!shown(QStringLiteral("itemCount")));
    QTRY_VERIFY(propertyOf(QStringLiteral("emptyState"), "first").toReal() < 1.0);
    m_core.release();
    QVERIFY(waitIdle());
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("empty"));
    QCOMPARE(propertyOf(QStringLiteral("emptyState"), "first").toReal(), 1.0);
    QVERIFY(shown(QStringLiteral("itemCount")));

    m_core.forcedStatus = 500;
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("error"));
    QCOMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(),
             QStringLiteral("Core could not complete that request."));
    QCOMPARE(propertyOf(QStringLiteral("emptyText"), "color").value<QColor>(), m_theme->failed());
    QVERIFY(!shown(QStringLiteral("itemCount")));
    m_core.forcedStatus = 0;
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("empty"));
}

// Whether `item` or anything under it shows `text`.
static bool showsText(QQuickItem *item, const QString &text)
{
    if (!item)
        return false;
    if (item->isVisible() && item->property("text").toString() == text)
        return true;
    const QList<QQuickItem *> children = item->childItems();
    return std::any_of(children.begin(), children.end(),
                       [&](QQuickItem *child) { return showsText(child, text); });
}

// One gold "New"; every other action is a quiet icon that names itself for
// screen readers and in a tooltip with its key, by keyboard or pointer.
void TestStudio::toolbarKeepsOnePrimary()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    QQuickItem *add = waitItem(QStringLiteral("newButton"));
    QVERIFY(add->property("primary").toBool());
    QVERIFY(add->property("showLabel").toBool());
    for (const char *name : {"uploadButton", "downloadButton", "renameButton", "trashButton",
                             "refreshButton"}) {
        QQuickItem *button = waitItem(QString::fromLatin1(name));
        QVERIFY2(button && button->isVisible(), name);
        QVERIFY2(!button->property("primary").toBool(), name);
        QVERIFY2(!button->property("showLabel").toBool(), name);
        QAccessibleInterface *named = QAccessible::queryAccessibleInterface(button);
        QVERIFY2(named && !named->text(QAccessible::Name).isEmpty(), name);
    }
    // Nothing to download from a folder: the button dims but keeps its place.
    QQuickItem *download = itemNamed(QStringLiteral("downloadButton"));
    QVERIFY(!download->property("usable").toBool());
    QVERIFY(download->isVisible() && download->opacity() < 1.0);

    focusOn(add);
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("uploadButton"));
    QTRY_VERIFY(shown(QStringLiteral("toolTip")));
    QVERIFY(showsText(itemNamed(QStringLiteral("toolTip")), QStringLiteral("Upload file")));
    QVERIFY(showsText(itemNamed(QStringLiteral("toolTip")), QStringLiteral("U")));

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    QTRY_VERIFY(!shown(QStringLiteral("toolTip")));
    QQuickItem *refresh = itemNamed(QStringLiteral("refreshButton"));
    QTest::mouseMove(window(), centreOf(refresh));
    QTRY_VERIFY(showsText(itemNamed(QStringLiteral("toolTip")), QStringLiteral("Refresh")));
    QVERIFY(showsText(itemNamed(QStringLiteral("toolTip")), QStringLiteral("F5")));
    QTest::mouseMove(window(), QPoint(1, window()->height() - 1));
    QTRY_VERIFY(!shown(QStringLiteral("toolTip")));
}

// Washes stand clear of a panel's edges while corners are round and run
// flush when the desktop squares them. In the sidebar only the open place
// is washed; the rows on the way to it only set their names heavier.
void TestStudio::rowsStandClearOfTheEdges()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    QQuickItem *row = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    QQuickItem *list = waitItem(QStringLiteral("entryList"));
    QVERIFY(row && list);
    QCOMPARE(row->width(), list->width());
    QQuickItem *fill = row->findChild<QQuickItem *>(QStringLiteral("fill"));
    QVERIFY(fill);
    QCOMPARE(fill->x(), qreal(m_theme->inset()));
    QCOMPARE(fill->width(), row->width() - 2 * m_theme->inset());
    QVERIFY(m_theme->inset() > 0);

    QVERIFY(rowProperty(QStringLiteral("treeRow"), QStringLiteral("Inbox"), "selected").toBool());
    QVERIFY(!rowProperty(QStringLiteral("spaceRow"), QStringLiteral("Inbox"), "selected").toBool());
    QVERIFY(rowProperty(QStringLiteral("spaceRow"), QStringLiteral("Inbox"), "along").toBool());
    QVERIFY(rowProperty(QStringLiteral("orgRow"), QStringLiteral("ok organization"), "along").toBool());
    QQuickItem *node = waitRow(QStringLiteral("treeRow"), QStringLiteral("Inbox"));
    QCOMPARE(node->findChild<QQuickItem *>(QStringLiteral("fill"))->x(), qreal(m_theme->inset()));

    const QString colours = m_home.filePath(QStringLiteral("state/omarchy/current/theme/colors.toml"));
    const QString mine = m_home.filePath(QStringLiteral("config/hypr/looknfeel.lua"));
    writeFile(colours, "background = \"#1e1e2e\"\nforeground = \"#cdd6f4\"\naccent = \"#89b4fa\"\n");
    writeFile(mine, "rounding = 0\n");
    m_theme->setMode(QStringLiteral("system"));
    settle();
    QCOMPARE(fill->x(), 0.0);
    QCOMPARE(fill->width(), row->width());
    QCOMPARE(fill->property("radius").toReal(), 0.0);
    QVERIFY(QFile::remove(colours));
    QVERIFY(QFile::remove(mine));
    m_theme->setMode(QStringLiteral("light"));
    settle();
    QCOMPARE(fill->x(), qreal(m_theme->inset()));
}

// A mode switch walks every wash with the palette, frame by frame; only
// the hover wash eases, by its own opacity.
void TestStudio::washesFollowTheCrossfade()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_theme->setMode(QStringLiteral("light"));
    QTRY_COMPARE(m_theme->accentSoft(), kEvaLightAccentSoft);
    QQuickItem *row = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    QTRY_VERIFY(row->property("selected").toBool());
    QQuickItem *fill = row->findChild<QQuickItem *>(QStringLiteral("fill"));
    QVERIFY(fill);

    QList<QColor> softs;
    const QMetaObject::Connection record =
            connect(m_theme, &Theme::paletteChanged, this, [&] { softs.append(m_theme->accentSoft()); });
    QSignalSpy washed(fill, SIGNAL(colorChanged()));
    m_theme->setMode(QStringLiteral("dark"));
    QTRY_COMPARE(m_theme->accentSoft(), kEvaDarkAccentSoft);
    disconnect(record);
    QVERIFY(std::any_of(softs.cbegin(), softs.cend(), [](const QColor &soft) {
        return soft != kEvaLightAccentSoft && soft != kEvaDarkAccentSoft;
    }));
    QVERIFY(washed.count() > 2);
    QCOMPARE(fill->property("color").value<QColor>(), m_theme->accentSoft());

    QQuickItem *org = waitRow(QStringLiteral("orgRow"), QStringLiteral("ok organization"));
    QCOMPARE(org->property("lit").toReal(), 0.0);
    QTest::mouseMove(window(), centreOf(org));
    QTRY_COMPARE(org->property("lit").toReal(), 1.0);
    QTest::mouseMove(window(), QPoint(1, window()->height() - 1));
    QTRY_COMPARE(org->property("lit").toReal(), 0.0);
    m_theme->setMode(QStringLiteral("light"));
}

// The keymap is titled in the serif and closes on any key or a click
// outside; the sheet and the menu spell keys as chips.
void TestStudio::overlaysSpeakTheLandingType()
{
    openSpace(QStringLiteral("Inbox"));
    key(Qt::Key_Question, Qt::ShiftModifier);
    QTRY_VERIFY(shown(QStringLiteral("keymapSheet")));
    QCOMPARE(propertyOf(QStringLiteral("overlayTitle"), "text").toString(), QStringLiteral("Keys"));
    const QFont title = propertyOf(QStringLiteral("overlayTitle"), "font").value<QFont>();
    QCOMPARE(title.families().first(), m_theme->title().families().first());
    QVERIFY(showsText(itemNamed(QStringLiteral("keymapSheet")), QStringLiteral("Ctrl+K")));
    key(Qt::Key_A);
    QTRY_VERIFY(!shown(QStringLiteral("keymapSheet")));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));

    key(Qt::Key_Question, Qt::ShiftModifier);
    QTRY_VERIFY(shown(QStringLiteral("keymapSheet")));
    QTest::mouseClick(window(), Qt::LeftButton, Qt::NoModifier, QPoint(4, window()->height() / 2));
    settle();
    QTRY_VERIFY(!shown(QStringLiteral("keymapSheet")));

    key(Qt::Key_Colon);
    QTRY_VERIFY(shown(QStringLiteral("commandSheet")));
    QVERIFY(showsText(itemNamed(QStringLiteral("commandSheet")), QStringLiteral("Commands")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("commandSheet")));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));

    key(Qt::Key_Menu);
    QTRY_VERIFY(menuOpen());
    QVERIFY(showsText(itemNamed(QStringLiteral("menu_new")), QStringLiteral("N")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!menuOpen());
}

// The saved choice wins, then the first system language we speak, then
// English; a choice is saved and only our languages are taken.
void TestStudio::languageResolvesAndPersists()
{
    QCOMPARE(Theme::resolveLanguage(QStringLiteral("ja"), {QStringLiteral("pt-BR")}),
             QStringLiteral("ja"));
    QCOMPARE(Theme::resolveLanguage(QString(), {QStringLiteral("de-DE"), QStringLiteral("pt-PT"),
                                                QStringLiteral("ja")}),
             QStringLiteral("pt-BR"));
    QCOMPARE(Theme::resolveLanguage(QStringLiteral("tlh"), {QStringLiteral("ja_JP")}),
             QStringLiteral("ja"));
    QCOMPARE(Theme::resolveLanguage(QString(), {QStringLiteral("EN-GB")}), QStringLiteral("en"));
    QCOMPARE(Theme::resolveLanguage(QString(), {QStringLiteral("fr-FR")}), QStringLiteral("en"));
    QCOMPARE(Theme::resolveLanguage(QString(), {}), QStringLiteral("en"));

    QStringList codes;
    QStringList marks;
    for (const QVariant &language : m_theme->languages()) {
        codes.append(language.toMap().value(QStringLiteral("code")).toString());
        marks.append(language.toMap().value(QStringLiteral("mark")).toString());
    }
    QCOMPARE(codes, (QStringList{QStringLiteral("pt-BR"), QStringLiteral("en"), QStringLiteral("ja")}));
    QCOMPARE(marks, (QStringList{QStringLiteral("PT"), QStringLiteral("EN"), QStringLiteral("日本語")}));

    m_theme->setLanguage(QStringLiteral("pt-BR"));
    const QString saved = QSettings().value(QStringLiteral("theme/language")).toString();
    QCOMPARE(saved, QStringLiteral("pt-BR"));
    QCOMPARE(Theme::resolveLanguage(saved, {QStringLiteral("ja-JP")}), QStringLiteral("pt-BR"));
    QCOMPARE(QLocale().name(), QStringLiteral("pt_BR"));
    m_theme->setLanguage(QStringLiteral("tlh"));
    QCOMPARE(m_theme->language(), QStringLiteral("pt-BR"));
    m_theme->setLanguage(QStringLiteral("en"));
    QCOMPARE(QSettings().value(QStringLiteral("theme/language")).toString(), QStringLiteral("en"));
}

// One switch retitles QML, the C++ command table, and Core's words,
// re-reads sizes in the new locale, and swaps the families, all live.
void TestStudio::languageSwitchesLive()
{
    QQuickItem *submit = waitItem(QStringLiteral("submitButton"));
    QCOMPARE(submit->property("text").toString(), QStringLiteral("Sign in"));
    m_theme->setLanguage(QStringLiteral("pt-BR"));
    QCOMPARE(submit->property("text").toString(), QStringLiteral("Entrar"));
    QCOMPARE(propertyOf(QStringLiteral("paneTitle"), "text").toString(), QStringLiteral("Entrar"));
    const auto title = [this](const QString &id) {
        for (const QVariant &row : m_session->commandList()) {
            if (row.toMap().value(QStringLiteral("id")) == id)
                return row.toMap().value(QStringLiteral("title")).toString();
        }
        return QString();
    };
    QCOMPARE(title(QStringLiteral("keymap")), QStringLiteral("Mapa do teclado"));
    QCOMPARE(title(QStringLiteral("new")), QStringLiteral("Nova organização"));

    // The library script's words follow too.
    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("ok@localhost"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("wrong"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(false));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("E-mail ou senha incorretos."));
    m_theme->setLanguage(QStringLiteral("en"));
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
             QStringLiteral("That email or password is wrong."));

    openSpace(QStringLiteral("Inbox"));
    m_theme->setLanguage(QStringLiteral("ja"));
    QTRY_VERIFY(showsText(itemNamed(QStringLiteral("emptyState")),
                          QStringLiteral("このフォルダーは空です。\nフォルダーを作るか、\nファイルをドロップしましょう。")));
    const QFont phrase = propertyOf(QStringLiteral("emptyText"), "font").value<QFont>();
    QCOMPARE(phrase.families().first(), QStringLiteral("Noto Serif JP"));
    QVERIFY(!phrase.italic());
    QCOMPARE(propertyOf(QStringLiteral("newButton"), "text").toString(),
             QStringLiteral("新しいフォルダー"));

    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"), {}, QByteArray("hello world\n"));
    m_session->runCommand(QStringLiteral("refresh"));
    QVERIFY(waitIdle());
    QTRY_COMPARE(m_session->entryCount(), 1);
    const auto size = [this] {
        return m_session->entries()->index(0).data(EntryModel::DetailRole).toString();
    };
    QCOMPARE(size(), QLocale(QLocale::Japanese).formattedDataSize(12));
    m_theme->setLanguage(QStringLiteral("en"));
    QCOMPARE(size(), QLocale(QLocale::English).formattedDataSize(12));
    QVERIFY(size() != QLocale(QLocale::Japanese).formattedDataSize(12));
    QCOMPARE(propertyOf(QStringLiteral("newButton"), "text").toString(), QStringLiteral("New folder"));
}

// PT · EN · 日本語 on the sign-in screen: a click or Enter picks one, arrows
// walk the group, and each says its language and whether it is chosen.
void TestStudio::switcherTakesKeysAndPointer()
{
    QQuickItem *japanese = waitItem(QStringLiteral("language_ja"));
    QQuickItem *english = itemNamed(QStringLiteral("language_en"));
    QQuickItem *portuguese = itemNamed(QStringLiteral("language_pt-BR"));
    QVERIFY(english->property("checked").toBool());
    clickItem(japanese);
    QCOMPARE(m_theme->language(), QStringLiteral("ja"));
    QVERIFY(japanese->property("checked").toBool());
    QVERIFY(!english->property("checked").toBool());
    QCOMPARE(propertyOf(QStringLiteral("submitButton"), "text").toString(), QStringLiteral("サインイン"));

    focusOn(portuguese);
    key(Qt::Key_Left);
    QCOMPARE(focusName(), QStringLiteral("language_pt-BR"));
    key(Qt::Key_Return);
    QCOMPARE(m_theme->language(), QStringLiteral("pt-BR"));
    key(Qt::Key_Right);
    QCOMPARE(focusName(), QStringLiteral("language_en"));
    key(Qt::Key_Right);
    QCOMPARE(focusName(), QStringLiteral("language_ja"));
    key(Qt::Key_Right);
    QCOMPARE(focusName(), QStringLiteral("language_ja"));
    key(Qt::Key_Left);
    key(Qt::Key_Space);
    QCOMPARE(m_theme->language(), QStringLiteral("en"));
    key(Qt::Key_Tab);
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("themeToggle"));

    QAccessibleInterface *named = QAccessible::queryAccessibleInterface(japanese);
    QVERIFY(named);
    QCOMPARE(named->text(QAccessible::Name), QStringLiteral("日本語"));
    QVERIFY(named->state().checkable);
    QVERIFY(!named->state().checked);
    QVERIFY(QAccessible::queryAccessibleInterface(english)->state().checked);
}

// The account menu lists the languages under the themes, the one in use
// checked; picking one switches the explorer in place.
void TestStudio::accountMenuChoosesALanguage()
{
    signInAsOk();
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    QQuickItem *english = waitItem(QStringLiteral("menu_lang-en"));
    QVERIFY(showsText(english, QStringLiteral("English")));
    QVERIFY(english->findChild<QQuickItem *>(QStringLiteral("checkMark"))->isVisible());
    QVERIFY(itemNamed(QStringLiteral("menu_theme-") + m_theme->mode())
                    ->findChild<QQuickItem *>(QStringLiteral("checkMark"))
                    ->isVisible());
    QQuickItem *japanese = itemNamed(QStringLiteral("menu_lang-ja"));
    QVERIFY(!japanese->findChild<QQuickItem *>(QStringLiteral("checkMark"))->isVisible());
    clickItem(japanese);
    QTRY_VERIFY(!menuOpen());
    QCOMPARE(m_theme->language(), QStringLiteral("ja"));
    QCOMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(), QStringLiteral("組織"));

    // By keyboard: the menu key on the account link, then arrows and Enter.
    focusOn(itemNamed(QStringLiteral("accountButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(menuOpen());
    QQuickItem *portuguese = waitItem(QStringLiteral("menu_lang-pt-BR"));
    QVERIFY(portuguese);
    for (int i = 0; i < portuguese->property("index").toInt(); ++i)
        key(Qt::Key_Down);
    key(Qt::Key_Return);
    QTRY_VERIFY(!menuOpen());
    QCOMPARE(m_theme->language(), QStringLiteral("pt-BR"));
    QCOMPARE(focusName(), QStringLiteral("accountButton"));
}

// A form sent with a required field empty names what is missing and marks
// only the empty fields, on every pane.
void TestStudio::emptyFieldsSayWhatIsMissing()
{
    const QString missing = QStringLiteral("Fill every required field.");
    clicks(itemNamed(QStringLiteral("emailField")), QString());
    clicks(itemNamed(QStringLiteral("passwordField")), QString());
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), missing);
    QVERIFY(propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());
    QCOMPARE(m_core.hits(), 0);

    clicks(itemNamed(QStringLiteral("emailField")), QStringLiteral("new@localhost"));
    focusOn(waitItem(QStringLiteral("submitButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(!propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    // What was typed stays; the remembered email does not come back over it.
    QCOMPARE(propertyOf(QStringLiteral("emailField"), "text").toString(), QStringLiteral("new@localhost"));
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), missing);

    clickItem(waitItem(QStringLiteral("registerLink")));
    clicks(itemNamed(QStringLiteral("passwordField")), QString());
    clickItem(waitItem(QStringLiteral("submitButton")));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), missing);
    QVERIFY(propertyOf(QStringLiteral("passwordField"), "invalid").toBool());

    key(Qt::Key_Escape);
    clickItem(waitItem(QStringLiteral("forgotLink")));
    clicks(itemNamed(QStringLiteral("emailField")), QString());
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(), missing);
    QVERIFY(propertyOf(QStringLiteral("emailField"), "invalid").toBool());

    QCOMPARE(m_core.hits(), 0);
}

// An access token that expires mid-use is refreshed without a word; when
// the refresh is refused too, the window returns to sign-in and says why.
void TestStudio::expiredTokenRefreshesMidUse()
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString org = m_session->currentOrgId();
    m_core.seedSpace(org, QStringLiteral("Archive"));
    const QString spaces = QStringLiteral("^/api/v1/organizations/[^/]+/spaces$");
    QVERIFY(m_core.failNext(QStringLiteral("GET"), spaces, 1, FakeCore::FaultMode::Expire));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Archive")));
    QVERIFY(waitIdle());
    QVERIFY(m_session->signedIn());
    QCOMPARE(statusText(), QString());
    QCOMPARE(m_core.state().value(QStringLiteral("faults")).toArray().size(), 0);

    QVERIFY(m_core.failNext(QStringLiteral("GET"), spaces, 1, FakeCore::FaultMode::Expire));
    QVERIFY(m_core.failNext(QStringLiteral("POST"), QStringLiteral("^/api/auth/refresh$"), 1,
                            FakeCore::FaultMode::Status, 401, QStringLiteral("invalid_refresh_token")));
    key(Qt::Key_R, Qt::ControlModifier);
    QVERIFY(waitSignedIn(false));
    QTRY_VERIFY(shown(QStringLiteral("authScreen")));
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
             QStringLiteral("Your session ended. Sign in again."));
    QCOMPARE(propertyOf(QStringLiteral("emailField"), "text").toString(), QStringLiteral("ok@localhost"));
    QVERIFY(!propertyOf(QStringLiteral("emailField"), "invalid").toBool());
    QTRY_COMPARE(focusName(), QStringLiteral("emailField"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));
    QTRY_COMPARE(m_session->currentOrgId(), org);
}

// A new window over the same settings is where the last one stopped: the
// email, the server, the organization, the theme, and the language.
void TestStudio::relaunchRemembersTheLastSession()
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString org = m_session->currentOrgId();
    m_theme->setMode(QStringLiteral("dark"));
    m_theme->setLanguage(QStringLiteral("ja"));

    {
        QQmlApplicationEngine again;
        again.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
        QVERIFY(!again.rootObjects().isEmpty());
        auto *theme = again.singletonInstance<Theme *>(QStringLiteral("matome"), QStringLiteral("Theme"));
        auto *session = again.singletonInstance<Session *>(QStringLiteral("matome"), QStringLiteral("Session"));
        QVERIFY(theme != m_theme && session != m_session);
        auto *relaunched = qobject_cast<QQuickWindow *>(again.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(relaunched));
        QCOMPARE(theme->mode(), QStringLiteral("dark"));
        QVERIFY(theme->dark());
        QCOMPARE(theme->language(), QStringLiteral("ja"));
        QCOMPARE(session->email(), QStringLiteral("ok@localhost"));
        QCOMPARE(session->apiBaseUrl(), m_core.url());
        QCOMPARE(session->lastOrgId(), org);
        QCOMPARE(itemNamed(QStringLiteral("emailField"), relaunched)->property("text").toString(),
                 QStringLiteral("ok@localhost"));
        QCOMPARE(itemNamed(QStringLiteral("submitButton"), relaunched)->property("text").toString(),
                 QStringLiteral("サインイン"));
        session->signIn(session->email(), QStringLiteral("secret12"), session->apiBaseUrl());
        QTRY_VERIFY(session->signedIn() && !session->loading());
        QCOMPARE(session->currentOrgId(), org);
        QCOMPARE(session->level(), QStringLiteral("spaces"));
        session->runCommand(QStringLiteral("sign-out"));
    }
    m_theme->setLanguage(QStringLiteral("en"));
    m_theme->setMode(QStringLiteral("light"));
    QCOMPARE(propertyOf(QStringLiteral("locationEyebrow"), "text").toString(), QStringLiteral("Organization"));
}

// F5, Ctrl+R, and the refresh button re-read the open level from Core at
// organizations, spaces, and files alike.
void TestStudio::refreshReloadsEveryLevel()
{
    signInAsOk();
    m_core.seedOrganization(QStringLiteral("Guests"), QStringLiteral("member"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Guests")));
    QVERIFY(waitIdle());

    QVERIFY(openOwnOrg());
    m_core.seedSpace(m_session->currentOrgId(), QStringLiteral("Archive"));
    key(Qt::Key_R, Qt::ControlModifier);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Archive")));
    QVERIFY(waitIdle());

    m_session->openEntry(QStringLiteral("space"), entryId(QStringLiteral("Archive")));
    QVERIFY(waitIdle());
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Ledger"));
    clickItem(waitItem(QStringLiteral("refreshButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Ledger")));
    QVERIFY(waitIdle());
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Receipt"));
    tapItem(waitItem(QStringLiteral("refreshButton")));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Receipt")));
    focusOn(waitItem(QStringLiteral("filterField")));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Invoice"));
    key(Qt::Key_F5);
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Invoice")));
    QCOMPARE(focusName(), QStringLiteral("filterField"));
}

// Whether `item` is a control a keyboard or a screen reader reaches.
static bool interactive(QQuickItem *item)
{
    for (const QMetaObject *meta = item->metaObject(); meta; meta = meta->superClass()) {
        if (QByteArray(meta->className()).startsWith("FocusableControl"))
            return true;
    }
    return item->activeFocusOnTab();
}

// Every visible control the user can reach, by Tab or by pointer, names
// itself to a screen reader and says what it is, on every screen.
void TestStudio::everyControlHasANameAndRole()
{
    QStringList silent;
    const auto audit = [&](const QString &where) {
        settle();
        int checked = 0;
        for (QQuickItem *item : descendants(window()->contentItem())) {
            if (!item->isVisible() || !interactive(item))
                continue;
            ++checked;
            QAccessibleInterface *named = QAccessible::queryAccessibleInterface(item);
            const QAccessible::Role role = named ? named->role() : QAccessible::NoRole;
            if (!named || named->text(QAccessible::Name).trimmed().isEmpty()
                || role == QAccessible::NoRole || role == QAccessible::Client)
                silent.append(QStringLiteral("%1: %2 (%3)").arg(where, item->objectName(),
                                                                  QString::fromLatin1(item->metaObject()->className())));
        }
        QVERIFY2(checked > 3, qPrintable(where));
    };

    for (const char *pane : {"signIn", "register", "forgot", "reset"}) {
        itemNamed(QStringLiteral("authScreen"))->setProperty("pane", QString::fromLatin1(pane));
        itemNamed(QStringLiteral("authScreen"))->setProperty("serverOpen", true);
        audit(QString::fromLatin1(pane));
    }
    itemNamed(QStringLiteral("authScreen"))->setProperty("pane", QStringLiteral("signIn"));
    itemNamed(QStringLiteral("authScreen"))->setProperty("serverOpen", false);
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Notes"));
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Notes")));
    QVERIFY(waitIdle());
    audit(QStringLiteral("files"));
    key(Qt::Key_Menu);
    QTRY_VERIFY(menuOpen());
    audit(QStringLiteral("menu"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!menuOpen());
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    audit(QStringLiteral("account"));
    key(Qt::Key_Escape);
    key(Qt::Key_Colon);
    QTRY_VERIFY(shown(QStringLiteral("commandSheet")));
    audit(QStringLiteral("sheet"));
    key(Qt::Key_Escape);
    key(Qt::Key_Question, Qt::ShiftModifier);
    QTRY_VERIFY(shown(QStringLiteral("keymapSheet")));
    audit(QStringLiteral("keymap"));
    key(Qt::Key_Escape);
    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    key(Qt::Key_Delete);
    QTRY_VERIFY(shown(QStringLiteral("deleteConfirm")));
    audit(QStringLiteral("confirm"));
    key(Qt::Key_Escape);
    window()->resize(400, 800);
    tapItem(waitItem(QStringLiteral("drawerButton")));
    QTRY_COMPARE(waitItem(QStringLiteral("sidebar"))->x(), 0.0);
    audit(QStringLiteral("narrow"));
    QVERIFY2(silent.isEmpty(), qPrintable(silent.join(QStringLiteral("\n"))));
}

// The sidebar's edge drags wider or narrower, between its limits.
void TestStudio::sidebarResizesByDrag()
{
    openSpace(QStringLiteral("Inbox"));
    QQuickItem *sidebar = waitItem(QStringLiteral("sidebar"));
    QQuickItem *handle = waitItem(QStringLiteral("sidebarHandle"));
    QVERIFY(handle && handle->isVisible());
    const qreal start = sidebar->width();
    QCOMPARE(start, qreal(m_theme->column()));
    const QPoint grip = centreOf(handle);
    QTest::mousePress(window(), Qt::LeftButton, Qt::NoModifier, grip);
    QTest::mouseMove(window(), grip + QPoint(60, 0));
    QTRY_COMPARE(sidebar->width(), start + 60);
    QTest::mouseMove(window(), QPoint(1000, grip.y()));
    QTRY_COMPARE(sidebar->width(), 420.0);
    QTest::mouseMove(window(), QPoint(10, grip.y()));
    QTRY_COMPARE(sidebar->width(), 180.0);
    QTest::mouseRelease(window(), Qt::LeftButton, Qt::NoModifier, QPoint(10, grip.y()));
    settle();
    QTest::mouseMove(window(), QPoint(300, grip.y()));
    settle();
    QCOMPARE(sidebar->width(), 180.0);
    QQuickItem *list = waitItem(QStringLiteral("entryList"));
    QCOMPARE(list->mapToScene(QPointF()).x(), 180.0);
    window()->resize(400, 800);
    QTRY_VERIFY(!handle->isVisible());
}

// In System on Omarchy the window follows theme switches while it runs:
// edited colours, a theme swapped under the `current/theme` link, a new
// rounding, and colours that vanish.
void TestStudio::omarchyReloadsLive()
{
    const QString current = m_home.filePath(QStringLiteral("state/omarchy/current"));
    const QString themes = m_home.filePath(QStringLiteral("state/omarchy/themes"));
    const QString looknfeel = m_home.filePath(QStringLiteral("config/hypr/looknfeel.lua"));
    QDir(current).removeRecursively();
    QVERIFY(QDir().mkpath(current));
    writeFile(themes + QStringLiteral("/night/colors.toml"),
              "background = \"#101010\"\nforeground = \"#eeeeee\"\naccent = \"#ccaa44\"\n");
    writeFile(themes + QStringLiteral("/day/colors.toml"),
              "background = \"#f4f4f4\"\nforeground = \"#1a1a1a\"\naccent = \"#3366aa\"\n");
    QVERIFY(QFile::link(themes + QStringLiteral("/night"), current + QStringLiteral("/theme")));
    writeFile(looknfeel, "rounding = 3\n");
    m_theme->setMode(QStringLiteral("light"));
    m_theme->setMode(QStringLiteral("system"));
    QTRY_COMPARE(m_theme->background(), QColor(QStringLiteral("#101010")));
    QVERIFY(m_theme->dark());
    QCOMPARE(m_theme->rounding(), 3);
    QCOMPARE(window()->color(), m_theme->background());

    writeFile(themes + QStringLiteral("/night/colors.toml"),
              "background = \"#202830\"\nforeground = \"#eeeeee\"\naccent = \"#ccaa44\"\n");
    QTRY_COMPARE(m_theme->background(), QColor(QStringLiteral("#202830")));
    QCOMPARE(window()->color(), m_theme->background());

    // Omarchy switches by renaming a new link over the old one.
    QVERIFY(QFile::link(themes + QStringLiteral("/day"), current + QStringLiteral("/next")));
    QVERIFY(::rename(QFile::encodeName(current + QStringLiteral("/next")).constData(),
                     QFile::encodeName(current + QStringLiteral("/theme")).constData()) == 0);
    QTRY_COMPARE(m_theme->background(), QColor(QStringLiteral("#f4f4f4")));
    QVERIFY(!m_theme->dark());
    QCOMPARE(propertyOf(QStringLiteral("submitButton"), "color").value<QColor>(), m_theme->accent());

    writeFile(looknfeel, "rounding = 7\n");
    QTRY_COMPARE(m_theme->rounding(), 7);
    QTRY_COMPARE(propertyOf(QStringLiteral("submitButton"), "radius").toReal(), 7.0);

    QVERIFY(QFile::remove(current + QStringLiteral("/theme")));
    // Back on the Eva table the desktop's colour scheme picks.
    QTRY_COMPARE(m_theme->background(), m_theme->dark() ? kEvaDarkBackground : kEvaLightBackground);
    QCOMPARE(m_theme->rounding(), 7);
    QCOMPARE(m_theme->mode(), QStringLiteral("system"));

    QVERIFY(QFile::remove(looknfeel));
    QVERIFY(QDir(themes).removeRecursively());
    QVERIFY(QDir(current).removeRecursively());
    m_theme->setMode(QStringLiteral("light"));
    QTRY_COMPARE(m_theme->rounding(), Theme::kSoftCorner);
}

// With animations off on the desktop nothing in the window moves over
// time: the drawer, hover washes, and a row's chevron land at once.
void TestStudio::reducedMotionStopsAnimations()
{
    const QString gtk3 = m_home.filePath(QStringLiteral("config/gtk-3.0/settings.ini"));
    writeFile(gtk3, "[Settings]\ngtk-enable-animations=false\n");
    m_theme->setMode(QStringLiteral("dark"));
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(m_theme->reduceMotion());

    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QVERIFY(waitIdle());
    addFolder(QStringLiteral("Signed"));
    m_session->runCommand(QStringLiteral("up"));
    QVERIFY(waitIdle());

    QQuickItem *row = waitRow(QStringLiteral("entryRow"), QStringLiteral("Contracts"));
    QTest::mouseMove(window(), centreOf(row));
    settle();
    QCOMPARE(row->property("lit").toReal(), 1.0);
    QTest::mouseMove(window(), QPoint(1, window()->height() - 1));
    settle();
    QCOMPARE(row->property("lit").toReal(), 0.0);

    QQuickItem *node = waitRow(QStringLiteral("treeRow"), QStringLiteral("Contracts"));
    QQuickItem *chevron = node->findChild<QQuickItem *>(QStringLiteral("disclosure"));
    const qreal turned = node->property("expanded").toBool() ? 0 : 90;
    clickItem(chevron);
    node = waitRow(QStringLiteral("treeRow"), QStringLiteral("Contracts"));
    QCOMPARE(node->findChild<QQuickItem *>(QStringLiteral("disclosure"))->rotation(), turned);

    window()->resize(400, 800);
    settle();
    QQuickItem *sidebar = waitItem(QStringLiteral("sidebar"));
    tapItem(waitItem(QStringLiteral("drawerButton")));
    QCOMPARE(sidebar->x(), 0.0);
    key(Qt::Key_Escape);
    QVERIFY(!sidebar->isVisible());

    QVERIFY(QFile::remove(gtk3));
    m_theme->setMode(QStringLiteral("dark"));
    m_theme->setMode(QStringLiteral("light"));
    QVERIFY(!m_theme->reduceMotion());
}

// Core going away mid-use is a message over the list, not a sign-out; the
// same refresh works again once it is back.
void TestStudio::coreDyingMidUseSaysSo()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    const quint16 port = m_core.port();
    m_core.close();
    const auto revive = qScopeGuard([&] {
        if (!m_core.port())
            m_core.listen(QHostAddress::LocalHost, port);
    });
    key(Qt::Key_F5);
    QTRY_COMPARE(statusText(), QStringLiteral("Could not reach Core at that URL."));
    QVERIFY(m_session->signedIn());
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(),
                 QStringLiteral("Could not reach Core at that URL."));
    QVERIFY(m_core.listen(QHostAddress::LocalHost, port));
    QCOMPARE(m_core.port(), port);
    key(Qt::Key_F5);
    QVERIFY(waitIdle());
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("empty"));
    QCOMPARE(statusText(), QString());
}

// A 500 from Core reads the same at every level: in the status line while
// rows are listed, over the list when there are none.
void TestStudio::serverErrorsShowAtEveryLevel()
{
    const QString words = QStringLiteral("Core could not complete that request.");
    signInAsOk();
    m_core.forcedStatus = 500;
    key(Qt::Key_F5);
    QTRY_COMPARE(statusText(), words);
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("ok organization")));
    m_core.forcedStatus = 0;
    key(Qt::Key_F5);
    QTRY_COMPARE(statusText(), QString());

    QVERIFY(openOwnOrg());
    m_core.forcedStatus = 500;
    key(Qt::Key_F5);
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(), words);
    key(Qt::Key_N);
    type(QStringLiteral("Inbox"));
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(), words);
    m_core.forcedStatus = 0;
    QVERIFY(createSpace(QStringLiteral("Inbox")));

    addFolder(QStringLiteral("Contracts"));
    m_core.forcedStatus = 500;
    key(Qt::Key_F5);
    QTRY_COMPARE(statusText(), words);
    QCOMPARE(propertyOf(QStringLiteral("explorerStatus"), "color").value<QColor>(), m_theme->failed());
    m_session->openEntry(QStringLiteral("folder"), entryId(QStringLiteral("Contracts")));
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("error"));
    QCOMPARE(propertyOf(QStringLiteral("emptyText"), "text").toString(), words);
    QVERIFY(!shown(QStringLiteral("itemCount")));
    m_core.forcedStatus = 0;
    key(Qt::Key_F5);
    QTRY_COMPARE(propertyOf(QStringLiteral("emptyState"), "mode").toString(), QStringLiteral("empty"));
}

// Whether the row under the list's cursor is inside the list's viewport.
static bool cursorInSight(QQuickItem *list)
{
    auto *row = list->property("currentItem").value<QQuickItem *>();
    if (!row)
        return false;
    const qreal top = row->mapToItem(list, QPointF()).y();
    return top >= 0 && top + row->height() <= list->height() + 0.5;
}

// Hundreds of rows scroll by wheel, and every key that moves the cursor
// keeps its row in sight.
void TestStudio::longListKeepsTheCursorInSight()
{
    openSpace(QStringLiteral("Inbox"));
    for (int i = 1; i <= 200; ++i)
        m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("Row %1").arg(i, 3, 10, QLatin1Char('0')));
    key(Qt::Key_F5);
    QTRY_COMPARE(m_session->entryCount(), 200);
    QVERIFY(waitIdle());
    QQuickItem *list = waitItem(QStringLiteral("entryList"));
    QCOMPARE(propertyOf(QStringLiteral("itemCount"), "text").toString(), QStringLiteral("200 items"));
    focusOn(list);
    QVERIFY(cursorInSight(list));

    key(Qt::Key_End);
    QTRY_COMPARE(list->property("currentIndex").toInt(), 199);
    QVERIFY(list->property("contentY").toReal() > 0);
    QTRY_VERIFY(cursorInSight(list));
    QVERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Row 200")));
    key(Qt::Key_PageUp);
    QVERIFY(list->property("currentIndex").toInt() < 199);
    QTRY_VERIFY(cursorInSight(list));
    for (int i = 0; i < 5; ++i)
        key(Qt::Key_Up);
    QTRY_VERIFY(cursorInSight(list));
    key(Qt::Key_Home);
    QTRY_COMPARE(list->property("contentY").toReal(), -list->property("topMargin").toReal());
    QVERIFY(cursorInSight(list));
    key(Qt::Key_PageDown);
    QTRY_VERIFY(cursorInSight(list));

    key(Qt::Key_Home);
    const qreal top = list->property("contentY").toReal();
    const QPointF centre = centreOf(list);
    QWheelEvent wheel(centre, centre, QPoint(), QPoint(0, -360), Qt::NoButton, Qt::NoModifier,
                      Qt::NoScrollPhase, false);
    // Stamped after the pointer events before it, as a real wheel would be.
    QTest::lastMouseTimestamp += 500;
    wheel.setTimestamp(QTest::lastMouseTimestamp);
    QCoreApplication::sendEvent(window(), &wheel);
    QTRY_VERIFY(list->property("contentY").toReal() > top);
    // Rows the flick is still building would be torn down by the next sign-out.
    QTRY_VERIFY(!list->property("moving").toBool());
    settle();
}

// Very long and Japanese names end in an ellipsis inside their row and the
// title; nothing pushes the size column or the item count out of the pane.
void TestStudio::longNamesElide()
{
    openSpace(QStringLiteral("Inbox"));
    const QString latin = QStringLiteral("Quarterly report ").repeated(20).trimmed();
    const QString japanese = QStringLiteral("とても長い日本語の書類名です").repeated(12);
    const QString folder = QStringLiteral("とても長い日本語のフォルダ名です").repeated(12);
    addFolder(folder);
    m_core.seedDocument(m_session->currentSpaceId(), latin);
    m_core.seedDocument(m_session->currentSpaceId(), japanese);
    key(Qt::Key_F5);
    QTRY_COMPARE(m_session->entryCount(), 3);
    QVERIFY(waitIdle());
    QQuickItem *list = waitItem(QStringLiteral("entryList"));
    for (const QString &name : {latin, japanese, folder}) {
        QQuickItem *row = waitRow(QStringLiteral("entryRow"), name);
        QVERIFY(row);
        QCOMPARE(row->width(), list->width());
        QQuickItem *title = row->findChild<QQuickItem *>(QStringLiteral("rowTitle"));
        QQuickItem *detail = row->findChild<QQuickItem *>(QStringLiteral("rowDetail"));
        QVERIFY(title->property("truncated").toBool());
        QVERIFY(title->mapToItem(row, QPointF(title->width(), 0)).x() <= detail->mapToItem(row, QPointF()).x());
        QVERIFY(detail->mapToItem(row, QPointF(detail->width(), 0)).x() <= row->width());
        QVERIFY(detail->isVisible());
    }
    QQuickItem *node = waitRow(QStringLiteral("treeRow"), folder);
    QQuickItem *sidebar = waitItem(QStringLiteral("sidebar"));
    QVERIFY(node->findChild<QQuickItem *>(QStringLiteral("rowTitle"))->property("truncated").toBool());
    QVERIFY(node->mapToItem(sidebar, QPointF(node->width(), 0)).x() <= sidebar->width());

    m_session->openEntry(QStringLiteral("folder"), entryId(folder));
    QVERIFY(waitIdle());
    QQuickItem *heading = waitItem(QStringLiteral("locationTitle"));
    QQuickItem *count = waitItem(QStringLiteral("itemCount"));
    QQuickItem *header = waitItem(QStringLiteral("locationHeader"));
    QTRY_COMPARE(heading->property("text").toString(), folder);
    QVERIFY(heading->property("truncated").toBool());
    QVERIFY(count->isVisible());
    QVERIFY(count->mapToItem(header, QPointF(count->width(), 0)).x() <= header->width());
    QVERIFY(header->mapToScene(QPointF(header->width(), 0)).x() <= window()->width());
    QVERIFY(waitItem(QStringLiteral("breadcrumb"))->mapToScene(QPointF(waitItem(QStringLiteral("breadcrumb"))->width(), 0)).x()
            <= window()->width());
}

QTEST_MAIN(TestStudio)
#include "tst_studio.moc"
