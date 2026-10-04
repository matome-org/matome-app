#include "FakeCore.h"
#include "Session.h"
#include "Theme.h"
#include "Wiring.h"
#include "references/AssetImages.h"

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
    void keyboardSetsUpAnAccount();
    void keyboardForgotAndReset();
    void escapeReturnsToSignIn();
    void wrongPasswordSaysSo();
    void refusedRegistrationNamesTheField();
    void rateLimitSaysToWait();
    void systemModeReadsOmarchyColours();
    void cornersFollowTheSystem();
    void keyboardDrivesTheExplorer();
    void tabReachesEveryRegion();
    void explorerOpensDocumentsOnlyWhenAsked();
    void documentAsksInASidePanel();
    void relatedTabOpensLinkedDocuments();
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
    void uploadOffersReviews();
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
    void settingsSelectsPackagesAndRespectsBillingRoles();
    void addOnPageConfiguresSettings();
    void classifierInstallsAndTurnsOnPerSpace();
    void addOnResumeKeepsItsSettings();
    void addOnInstallsWithItsSettings();
    void spacePageRequiresReviews();
    void refusalsLeadToTheFix();
    void settingsFollowsEffectiveActions();
    void spaceTablesSelectManyAndFlagAddOns();
    void inviteRefusalStaysInThePanel();
    void addOnRolesAreReadOnly();
    void apiTokensCreateAndRevoke();
    void settingsManagesGroupsRolesAndAccess();
    void renameOrganizationInAPanel();
    void settingsNavigationIsOneTabStop();
    void explorerManagesFolderAccess();
    void explorerFollowsSpaceAccess();
    void memberPageListsAccessGroupsAndRoles();
    void peopleCreatesManagedUsers();
    void rolePageListsHoldersAndAddsPeople();
    void detailPagesShowOneTableAtATime();
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
    void wheelScrollsPagesAndPanels();
    void aReloadKeepsTheClick();
    void longNamesElide();

private:
    QQuickWindow *window() const;
    QQuickItem *itemNamed(const QString &name, QQuickWindow *in = nullptr) const;
    QQuickItem *rowTitled(const QString &prefix, const QString &title) const;
    QQuickItem *rowWith(const QString &prefix, int column, const QString &text) const;
    QQuickItem *waitItem(const QString &name) const;
    QQuickItem *waitRow(const QString &prefix, const QString &title) const;
    QVariant rowProperty(const QString &prefix, const QString &title, const char *name) const;
    QVariant propertyOf(const QString &item, const char *name) const;
    bool shown(const QString &name) const;
    bool panelOpen() const;
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
    void clickItem(QQuickItem *item, Qt::MouseButton button = Qt::LeftButton, Qt::KeyboardModifiers mods = Qt::NoModifier);
    void openRow(QQuickItem *row);
    QString cell(const QString &row, int column) const;
    void tapItem(QQuickItem *item, int holdMs = 0);
    void dropOn(QQuickItem *item, QMimeData *mime, const std::function<void()> &midDrag = {});
    void dragOnto(QQuickItem *from, QQuickItem *onto);
    void wheelOn(QQuickItem *item);
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
    // As main() does: the images Markdown links come from this provider.
    matome::installAssetImages(*m_engine, *m_engine->singletonInstance<Session *>(QStringLiteral("matome"),
                                                                                   QStringLiteral("Session")));
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

// The visible table row whose objectName starts with `prefix` and whose
// cell `column` shows `text`.
QQuickItem *TestStudio::rowWith(const QString &prefix, int column, const QString &text) const
{
    for (QQuickItem *item : descendants(window()->contentItem())) {
        if (item->isVisible() && item->objectName().startsWith(prefix)
            && item->property("cells").toList().value(column).toString() == text)
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

// The side panel shown and slid fully in at the right edge of the item it
// sits beside; the pane lives in a popup, whose `parent` is that item.
bool TestStudio::panelOpen() const
{
    QQuickItem *pane = itemNamed(QStringLiteral("sidePanel"));
    if (!pane || !pane->isVisible() || !pane->parentItem())
        return false;
    const auto *area = pane->parentItem()->parent()->property("parent").value<QQuickItem *>();
    return area && qAbs(pane->mapToScene(QPointF(pane->width(), 0)).x() - area->mapToScene(QPointF(area->width(), 0)).x()) < 0.5;
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

void TestStudio::clickItem(QQuickItem *item, Qt::MouseButton button, Qt::KeyboardModifiers mods)
{
    QVERIFY(item);
    settle();
    const QPoint scene = centreOf(item);
    QTest::mouseMove(window(), scene);
    settle();
    QTest::mouseClick(window(), button, mods, scene);
    settle();
}

// A table row opens as Enter opens it, once a click selected it.
void TestStudio::openRow(QQuickItem *row)
{
    QVERIFY(row);
    const QString name = row->objectName();
    clickItem(row);
    // A reload may build the row again; the cursor stays on its key.
    QTRY_VERIFY(itemNamed(name) && itemNamed(name)->hasActiveFocus());
    key(Qt::Key_Return);
}

// The text of cell `column` of the table row `row`.
QString TestStudio::cell(const QString &row, int column) const
{
    return propertyOf(row, "cells").toList().value(column).toString();
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

// One notch-burst of the mouse wheel down over the item's centre, stamped
// after the pointer events before it, as a real wheel would be.
void TestStudio::wheelOn(QQuickItem *item)
{
    QVERIFY(item);
    settle();
    const QPointF centre = centreOf(item);
    QWheelEvent wheel(centre, centre, QPoint(), QPoint(0, -360), Qt::NoButton, Qt::NoModifier,
                      Qt::NoScrollPhase, false);
    QTest::lastMouseTimestamp += 500;
    wheel.setTimestamp(QTest::lastMouseTimestamp);
    QCoreApplication::sendEvent(window(), &wheel);
    settle();
}

// The scrolling page or panel body that holds `item`.
static QQuickItem *flickableOf(QQuickItem *item)
{
    for (QQuickItem *at = item ? item->parentItem() : nullptr; at; at = at->parentItem()) {
        if (at->inherits("QQuickFlickable"))
            return at;
    }
    return nullptr;
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
    m_session->createHere(name, QStringLiteral("private"));
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
    for (int i = 0; i < 18; ++i) {
        names.insert(focusName());
        key(Qt::Key_Tab);
    }
    QVERIFY(names.contains(QStringLiteral("emailField")));
    QVERIFY(names.contains(QStringLiteral("passwordField")));
    QVERIFY(names.contains(QStringLiteral("submitButton")));
    QVERIFY(names.contains(QStringLiteral("registerLink")));
    QVERIFY(names.contains(QStringLiteral("forgotLink")));
    QVERIFY(names.contains(QStringLiteral("setupLink")));
    QVERIFY(!names.contains(QStringLiteral("setupCodeField")));
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
    // Signing in before confirming returns to the same wait.
    clickItem(waitItem(QStringLiteral("backToSignIn")));
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("signIn"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QTRY_COMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("confirm"));
    QVERIFY(!m_session->signedIn());
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("Open the confirmation link sent to new@localhost in your browser, then return to sign in."));
    QVERIFY(m_core.confirmEmailInBrowser(QStringLiteral("new@localhost")));
    focusOn(waitItem(QStringLiteral("backToSignIn")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("signIn"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));
}

// An account an organization made is set up from the sign-in screen: its
// identifier, the one-time code, and a new password, which signs it in.
void TestStudio::keyboardSetsUpAnAccount()
{
    m_core.seedOrganization(QStringLiteral("Acme"), QStringLiteral("owner"));
    const QString identifier = m_core.seedManagedMember(QStringLiteral("org-1"), QStringLiteral("bo"), QStringLiteral("member"),
                                                        QStringLiteral("mst_code"));
    focusOn(waitItem(QStringLiteral("setupLink")));
    key(Qt::Key_Return);
    QCOMPARE(propertyOf(QStringLiteral("authScreen"), "pane").toString(), QStringLiteral("setup"));
    QCOMPARE(propertyOf(QStringLiteral("paneTitle"), "text").toString(), QStringLiteral("Set up account"));
    QCOMPARE(propertyOf(QStringLiteral("emailField"), "placeholderText").toString(), QStringLiteral("Email or username"));
    QCOMPARE(propertyOf(QStringLiteral("passwordField"), "placeholderText").toString(), QStringLiteral("New password"));
    clicks(itemNamed(QStringLiteral("emailField")), identifier);
    clicks(itemNamed(QStringLiteral("setupCodeField")), QStringLiteral("mst_wrong"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("fresh-pass1"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->errorCode(), QStringLiteral("invalid_setup_code"));
    QTRY_COMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
                 QStringLiteral("That username or setup code is wrong, or the code was used or expired."));
    QVERIFY(propertyOf(QStringLiteral("setupCodeField"), "invalid").toBool());
    clicks(itemNamed(QStringLiteral("setupCodeField")), QStringLiteral("mst_code"));
    clicks(itemNamed(QStringLiteral("passwordField")), QStringLiteral("fresh-pass1"));
    key(Qt::Key_Return);
    QVERIFY(waitSignedIn(true));
    QTRY_COMPARE(propertyOf(QStringLiteral("accountButton"), "text").toString(), identifier);
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
                 QStringLiteral("That email, username, or password is wrong."));
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

    // A new space asks its name and who reads it, private unless changed.
    key(Qt::Key_N);
    QTRY_COMPARE(focusName(), QStringLiteral("newSpaceName"));
    QVERIFY(propertyOf(QStringLiteral("spaceVisibility_private"), "selected").toBool());
    type(QStringLiteral("Inbox"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->level(), QStringLiteral("files"));
    QVERIFY(waitIdle());
    QCOMPARE(m_core.state().value(QStringLiteral("spaces")).toArray().last().toObject()
                     .value(QStringLiteral("visibility")).toString(), QStringLiteral("private"));

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

    // The menu opens on its first command, under the row's heading; the
    // arrows step over headings.
    key(Qt::Key_Menu);
    QTRY_COMPARE(focusName(), QStringLiteral("menu_open"));
    key(Qt::Key_Down);
    QTRY_COMPARE(focusName(), QStringLiteral("menu_download"));
    key(Qt::Key_Home);
    QTRY_COMPARE(focusName(), QStringLiteral("menu_open"));
    key(Qt::Key_Down);
    QTRY_COMPARE(focusName(), QStringLiteral("menu_download"));
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

// Entering a folder lands the cursor on its first row and the arrows move
// it; only Enter (or a double click, or a tap) opens the document screen.
void TestStudio::explorerOpensDocumentsOnlyWhenAsked()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Contracts"));
    const QString folder = entryId(QStringLiteral("Contracts"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("notes.md"), folder, QByteArray("# Notes\n"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("plan.md"), folder, QByteArray("# Plan\n"));
    m_session->navigate(QStringLiteral("folder"), folder);
    QVERIFY(waitIdle());
    QTRY_VERIFY(itemNamed(QStringLiteral("entryRow1")));
    settle();
    QVERIFY(!m_session->documentView()->active());
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("explorer")), "focusDefault");
    key(Qt::Key_Down);
    settle();
    QVERIFY(!m_session->documentView()->active());
    key(Qt::Key_Return);
    QTRY_VERIFY(m_session->documentView()->active());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->documentView()->active());
    QTRY_VERIFY(itemNamed(QStringLiteral("explorer"))->isVisible());
}

// Leaving, discarding, and saving an edit ask in a side panel beside the
// editor; Esc steps back out of it and keeps the edit.
void TestStudio::documentAsksInASidePanel()
{
    openSpace(QStringLiteral("Inbox"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("notes.md"), {}, QByteArray("# Notes\n"));
    key(Qt::Key_F5);
    QVERIFY(waitIdle());
    QTRY_VERIFY(!entryId(QStringLiteral("notes.md")).isEmpty());
    m_session->openEntry(QStringLiteral("document"), entryId(QStringLiteral("notes.md")));
    QTRY_VERIFY(m_session->documentView()->active());
    QVERIFY(waitIdle());
    QTRY_VERIFY(m_session->documentView()->editable());
    settle();
    key(Qt::Key_2);
    QTRY_COMPARE(m_session->documentView()->tab(), QStringLiteral("edit"));
    QQuickItem *editor = waitItem(QStringLiteral("documentEditor"));
    QTRY_VERIFY(editor->isVisible() && editor->isEnabled());
    focusOn(editor);
    key(Qt::Key_End, Qt::ControlModifier);
    type(QStringLiteral("more"));

    key(Qt::Key_Escape);
    QTRY_VERIFY(shown(QStringLiteral("documentAskPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Discard your changes?"));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Discard and close"));
    QTRY_COMPARE(focusName(), QStringLiteral("sidePanelCancel"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("documentAskPanel")));
    QVERIFY(m_session->documentView()->active());

    key(Qt::Key_S, Qt::ControlModifier);
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Save a new version?"));
    // The reason is optional here, and has focus.
    QTRY_COMPARE(focusName(), QStringLiteral("confirmReason"));
    QVERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    type(QStringLiteral("typo"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("documentAskPanel")));
    QTRY_COMPARE(m_session->documentView()->notice(), QStringLiteral("version_published"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->documentView()->active());
}

// 4 shows what links the document and what it links; Enter on a source
// opens it, and a broken link is listed but dimmed.
void TestStudio::relatedTabOpensLinkedDocuments()
{
    openSpace(QStringLiteral("Inbox"));
    addFolder(QStringLiteral("Guides"));
    const QString folder = entryId(QStringLiteral("Guides"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("notes.md"), folder, QByteArray("# Notes\n"));
    m_core.seedDocument(m_session->currentSpaceId(), QStringLiteral("plan.md"), folder, QByteArray("# Plan\n"));
    m_session->navigate(QStringLiteral("folder"), folder);
    QVERIFY(waitIdle());
    QTRY_VERIFY(!entryId(QStringLiteral("plan.md")).isEmpty());
    const QString notes = entryId(QStringLiteral("notes.md")), plan = entryId(QStringLiteral("plan.md"));
    m_core.seedReferences(notes, {
        {QStringLiteral("incoming"), QJsonObject{{QStringLiteral("hidden_count"), 1}, {QStringLiteral("references"), QJsonArray{
            QJsonObject{{QStringLiteral("document_id"), plan}, {QStringLiteral("title"), QStringLiteral("plan.md")},
                        {QStringLiteral("path"), QStringLiteral("/plan.md")}}}}}},
        {QStringLiteral("outgoing"), QJsonObject{{QStringLiteral("references"), QJsonArray{
            QJsonObject{{QStringLiteral("position"), 0}, {QStringLiteral("mode"), QStringLiteral("path")},
                        {QStringLiteral("path"), QStringLiteral("/gone.md")},
                        {QStringLiteral("target"), QJsonObject{{QStringLiteral("state"), QStringLiteral("broken")}}}}}}}}});
    m_session->openEntry(QStringLiteral("document"), notes);
    QTRY_VERIFY(m_session->documentView()->active());
    QVERIFY(waitIdle());
    settle();
    key(Qt::Key_4);
    QTRY_COMPARE(m_session->documentView()->tab(), QStringLiteral("related"));
    QTRY_VERIFY(m_session->documentView()->relatedLoaded());
    settle();
    QQuickItem *source = itemNamed(QStringLiteral("incoming_0"));
    QVERIFY(source && source->isVisible());
    QCOMPARE(source->property("title").toString(), QStringLiteral("plan.md"));
    QVERIFY(itemNamed(QStringLiteral("relatedHidden"))->isVisible());
    QQuickItem *broken = itemNamed(QStringLiteral("outgoing_0"));
    QVERIFY(broken);
    QCOMPARE(broken->property("title").toString(), QStringLiteral("/gone.md"));
    QCOMPARE(broken->property("detail").toString(), QStringLiteral("Nothing is at this path any more · By path"));
    QVERIFY(broken->opacity() < 1);
    QVERIFY(!itemNamed(QStringLiteral("relatedEmpty"))->isVisible());
    itemNamed(QStringLiteral("incomingList"))->forceActiveFocus();
    settle();
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->documentView()->documentId(), plan);
    QCOMPARE(m_session->documentView()->tab(), QStringLiteral("view"));
    key(Qt::Key_4);
    QTRY_VERIFY(m_session->documentView()->relatedLoaded());
    settle();
    QVERIFY(itemNamed(QStringLiteral("relatedEmpty"))->isVisible());
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

// Markdown going into a space that requires reviews asks first, every time,
// from the keyboard or the pointer: Manage with reviews starts unchecked, and each file
// is managed once it lands. Unchecked, it lands unmanaged; Esc drops it; a
// refused control names the file that landed. Other files go up at once.
void TestStudio::uploadOffersReviews()
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    QVERIFY(createSpace(QStringLiteral("Quality")));
    QTRY_VERIFY(!m_session->addOns()->busy());
    const QString spaceId = m_session->currentSpaceId();
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")},
            {QStringLiteral("revision"), 1}}}}});
    m_session->addOns()->refresh();
    QTRY_VERIFY(!m_session->addOns()->busy());
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("ok@localhost"), QStringLiteral("content_reader"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("ok@localhost"), QStringLiteral("addon.controlled_docs.manager"));
    auto *activations = m_session->addOnActivations();
    activations->open();
    QTRY_VERIFY(!activations->rows().isEmpty());
    QTRY_VERIFY(!activations->busy());
    activations->activate(spaceId, QStringLiteral("controlled_docs"));
    QTRY_COMPARE(activations->notice(), QStringLiteral("activated"));
    activations->close();
    // The space's catalog grants managing documents once the add-on is
    // active there; read again, it no longer grants making folders.
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(!propertyOf(QStringLiteral("newButton"), "usable").toBool());
    QVERIFY(waitIdle());

    auto *mime = new QMimeData;
    mime->setUrls({scratchFile(QStringLiteral("plan.md"), "# Plan\n"), scratchFile(QStringLiteral("notes.txt"), "notes")});
    dropOn(waitItem(QStringLiteral("entryList")), mime);
    QTRY_VERIFY(shown(QStringLiteral("reviewUploadPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Manage 1 Markdown file with reviews?"));
    QTRY_VERIFY(!m_core.landed(QStringLiteral("notes.txt")).isEmpty());
    QVERIFY(m_core.landed(QStringLiteral("plan.md")).isEmpty());
    // Managing is opt-in: the choice starts off and Space turns it on.
    QTRY_COMPARE(focusName(), QStringLiteral("manageUploadsRow"));
    QVERIFY(!propertyOf(QStringLiteral("manageUploadsRow"), "selected").toBool());
    key(Qt::Key_Space);
    QTRY_VERIFY(propertyOf(QStringLiteral("manageUploadsRow"), "selected").toBool());
    key(Qt::Key_Tab);
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("sidePanelSave"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("reviewUploadPanel")));
    QTRY_VERIFY(m_core.documentTitled(QStringLiteral("plan.md")).value(QStringLiteral("controlled_docs_enabled")).toBool());
    QTRY_VERIFY(!m_session->uploadBusy());
    QTRY_VERIFY(rowProperty(QStringLiteral("entryRow"), QStringLiteral("plan.md"), "controlled").toBool());
    QVERIFY(!m_core.documentTitled(QStringLiteral("notes.txt")).value(QStringLiteral("controlled_docs_enabled")).toBool());
    QCOMPARE(statusText(), QString());

    // Asked again every time, unchecked at first.
    m_session->uploadUrls({scratchFile(QStringLiteral("loose.md"), "# Loose\n")});
    QTRY_VERIFY(shown(QStringLiteral("reviewUploadPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!propertyOf(QStringLiteral("manageUploadsRow"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!m_core.landed(QStringLiteral("loose.md")).isEmpty());
    QTRY_VERIFY(!m_session->uploadBusy());
    QVERIFY(!m_core.documentTitled(QStringLiteral("loose.md")).value(QStringLiteral("controlled_docs_enabled")).toBool());

    // Esc drops the files.
    m_session->uploadUrls({scratchFile(QStringLiteral("dropped.md"), "# Dropped\n")});
    QTRY_VERIFY(shown(QStringLiteral("reviewUploadPanel")));
    QTRY_VERIFY(panelOpen());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("reviewUploadPanel")));
    QCOMPARE(m_session->reviewUploads(), 0);
    QVERIFY(m_core.documentTitled(QStringLiteral("dropped.md")).isEmpty());

    QVERIFY(m_core.failNext(QStringLiteral("PUT"), QStringLiteral("/controlled-docs$"), 1, FakeCore::FaultMode::Status,
                            409, QStringLiteral("incompatible_publication_subscriptions")));
    m_session->uploadUrls({scratchFile(QStringLiteral("late.md"), "# Late\n")});
    QTRY_VERIFY(shown(QStringLiteral("reviewUploadPanel")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("manageUploadsRow")));
    QVERIFY(propertyOf(QStringLiteral("manageUploadsRow"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(statusText(), QStringLiteral("Uploaded “late.md”, but it is not managed with reviews: Pause incompatible "
                                              "readiness automations or processing subscriptions before enabling control."));
    QCOMPARE(propertyOf(QStringLiteral("explorerStatus"), "color").value<QColor>(), m_theme->failed());
    QTRY_VERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("late.md")));
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
    QVERIFY(waitIdle());

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
    QTRY_VERIFY(shown(QStringLiteral("deleteFolderPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_COMPARE(focusName(), QStringLiteral("sidePanelCancel"));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(),
             QStringLiteral("Delete folder \u201cDrafts\u201d?"));
    QCOMPARE(propertyOf(QStringLiteral("confirmDetail"), "text").toString(),
             QStringLiteral("This cannot be undone."));
    // Keys that are not the panel's run no command under it.
    key(Qt::Key_Backspace);
    QCOMPARE(m_session->level(), QStringLiteral("files"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("deleteFolderPanel")));
    QTRY_COMPARE(regionOf(window()->activeFocusItem()), QStringLiteral("entryPane"));
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));

    clickItem(waitItem(QStringLiteral("trashButton")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("sidePanelCancel")));
    QTRY_VERIFY(!shown(QStringLiteral("deleteFolderPanel")));
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Drafts")));

    key(Qt::Key_Delete);
    QTRY_VERIFY(panelOpen());
    QTRY_COMPARE(focusName(), QStringLiteral("sidePanelCancel"));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("sidePanelSave"));
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
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(statusText(), QStringLiteral("Only an empty folder can be deleted."));
    QVERIFY(waitIdle());
    QVERIFY(rowTitled(QStringLiteral("entryRow"), QStringLiteral("Plans")));
    QVERIFY(!shown(QStringLiteral("restoreButton")));

    clickItem(waitRow(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QTRY_COMPARE(propertyOf(QStringLiteral("trashButton"), "text").toString(), QStringLiteral("Move to trash"));
    QCOMPARE(propertyOf(QStringLiteral("trashButton"), "icon").toString(), QStringLiteral("trash"));
    key(Qt::Key_Delete);
    QTRY_VERIFY(!rowTitled(QStringLiteral("entryRow"), QStringLiteral("Memo")));
    QTRY_VERIFY(!shown(QStringLiteral("deleteFolderPanel")));
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

void TestStudio::settingsSelectsPackagesAndRespectsBillingRoles()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    const QJsonObject plan{{QStringLiteral("key"), QStringLiteral("pro")}, {QStringLiteral("version"), 1}};
    m_core.seedPackages({QJsonObject{{QStringLiteral("key"), QStringLiteral("professional")},
            {QStringLiteral("name"), QStringLiteral("Professional")}, {QStringLiteral("version"), 2},
            {QStringLiteral("plan"), plan}, {QStringLiteral("add_ons"), QJsonArray()}},
            QJsonObject{{QStringLiteral("key"), QStringLiteral("professional")},
            {QStringLiteral("name"), QStringLiteral("Professional")}, {QStringLiteral("version"), 1},
            {QStringLiteral("plan"), plan}, {QStringLiteral("add_ons"), QJsonArray()}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_billing").arg(orgId)));
    QTRY_VERIFY(shown(QStringLiteral("billingPackage_professional_2")));
    QCOMPARE(propertyOf(QStringLiteral("billingPackageTitle_professional_2"), "text").toString(),
             QStringLiteral("Professional · version 2"));
    QCOMPARE(propertyOf(QStringLiteral("billingPackageTitle_professional_1"), "text").toString(),
             QStringLiteral("Professional · version 1"));
    const int hits = m_core.hits();
    // A package is selected first; the bar's Subscribe asks to confirm it.
    QVERIFY(!propertyOf(QStringLiteral("subscribePackageButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("billingPackage_professional_2")));
    QVERIFY(!shown(QStringLiteral("selectPackagePanel")));
    QTRY_VERIFY(propertyOf(QStringLiteral("subscribePackageButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("subscribePackageButton")));
    QTRY_VERIFY(shown(QStringLiteral("selectPackagePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(m_core.hits(), hits);
    clickItem(waitItem(QStringLiteral("sidePanelCancel")));
    QTRY_VERIFY(!shown(QStringLiteral("selectPackagePanel")));
    QTRY_COMPARE(focusName(), QStringLiteral("subscribePackageButton"));
    QCOMPARE(m_core.hits(), hits);
    clickItem(waitItem(QStringLiteral("subscribePackageButton")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("selectPackagePanel")));
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    QTRY_VERIFY(shown(QStringLiteral("openBillingPortalButton")));
    QCOMPARE(m_core.billingRequest().value(QStringLiteral("package")).toObject()
                 .value(QStringLiteral("version")).toInt(), 2);
    QVERIFY(!m_core.billingRequest().contains(QStringLiteral("plan")));
    QVERIFY(!m_core.billingRequest().contains(QStringLiteral("add_ons")));
    QCOMPARE(m_session->orgBilling()->plan(), QStringLiteral("free"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());

    m_core.seedOrganization(QStringLiteral("Admin team"), QStringLiteral("admin"));
    m_session->refreshOrganizations();
    QVERIFY(waitIdle());
    const QString adminId = m_session->organizations()->index(1).data(matome::OrgModel::OrgIdRole).toString();
    m_session->navigate(QStringLiteral("org"), adminId);
    QVERIFY(waitIdle());
    window()->resize(390, 844);
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsNavigationButton")));
    QObject *drawer = waitItem(QStringLiteral("settingsScreen"))->findChild<QObject *>(
        QStringLiteral("settingsNavigationDrawer"));
    QVERIFY(drawer);
    QTRY_VERIFY(drawer->property("opened").toBool());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_billing").arg(adminId)));
    QTRY_VERIFY(!drawer->property("visible").toBool());
    QTRY_COMPARE(propertyOf(QStringLiteral("settingsScreen"), "section").toString(), QStringLiteral("billing"));
    // Packages stay readable; only a billing manager may subscribe, and the
    // commands say why, dimmed in place.
    QVERIFY(!m_session->orgBilling()->canManage());
    for (const QString &name : {QStringLiteral("billingPortalButton"), QStringLiteral("subscribePackageButton")}) {
        QVERIFY(shown(name));
        QVERIFY(!propertyOf(name, "usable").toBool());
        QVERIFY(!propertyOf(name, "reason").toString().isEmpty());
    }
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());
}

// An add-on's tile opens its page, whose form follows the catalog's
// settings schema; saving sends only what changed.
// Groups, roles, space access, and tags each list their entries, open one
// on a page of its own, and change it through the dialogs they hold.
void TestStudio::settingsManagesGroupsRolesAndAccess()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    QVERIFY(createSpace(QStringLiteral("Contracts")));
    const QString spaceId = m_session->currentSpaceId();
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());

    // New group opens a panel with focus in its name; Enter creates it and
    // opens its page.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_groups").arg(orgId)));
    QTRY_VERIFY(shown(QStringLiteral("accessCreateButton")));
    QTRY_VERIFY(propertyOf(QStringLiteral("accessCreateButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("accessCreateButton")));
    QTRY_VERIFY(shown(QStringLiteral("groupNamePanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("groupNameField"))->hasActiveFocus());
    type(QStringLiteral("Legal"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("groupPage")));
    QTRY_VERIFY(!shown(QStringLiteral("groupNamePanel")));
    QCOMPARE(propertyOf(QStringLiteral("groupName"), "text").toString(), QStringLiteral("Legal"));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Group created."));
    QVERIFY(shown(QStringLiteral("accessNotice")));
    QVERIFY(!shown(QStringLiteral("accessCreateButton")));
    const QString groupId = m_session->accessDirectory()->groups().constFirst().toMap().value(QStringLiteral("id")).toString();
    // Manage members checks people in a panel; Save makes them the members.
    QTRY_VERIFY(propertyOf(QStringLiteral("groupManageMembersButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("groupManageMembersButton")));
    QTRY_VERIFY(shown(QStringLiteral("groupMembersPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("groupMember_") + bo));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("groupMembersPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Members saved."));
    QTRY_VERIFY(waitItem(QStringLiteral("groupManageMembersButton"))->hasActiveFocus());
    // The Members tab lists them; switching tabs keeps the page's commands.
    clickItem(waitItem(QStringLiteral("groupTab_members")));
    QTRY_VERIFY(shown(QStringLiteral("groupPerson_") + bo));
    QVERIFY(!shown(QStringLiteral("groupName")));
    QVERIFY(shown(QStringLiteral("groupOpenMemberButton")));
    QVERIFY(shown(QStringLiteral("groupManageMembersButton")));
    clickItem(waitItem(QStringLiteral("groupTab_details")));
    QTRY_VERIFY(shown(QStringLiteral("groupName")));
    QVERIFY(!shown(QStringLiteral("groupOpenMemberButton")));
    // Rename is a panel of its own.
    QTRY_VERIFY(propertyOf(QStringLiteral("groupRenameButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("groupRenameButton")));
    QTRY_VERIFY(shown(QStringLiteral("groupNamePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Rename group"));
    clicks(waitItem(QStringLiteral("groupNameField")), QStringLiteral("Legal team"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("groupNamePanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("groupName"), "text").toString(), QStringLiteral("Legal team"));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Group renamed."));
    QVERIFY(shown(QStringLiteral("accessNotice")));
    // Archive asks in its panel; Esc leaves it, then the page.
    clickItem(waitItem(QStringLiteral("groupArchiveButton")));
    QTRY_VERIFY(shown(QStringLiteral("archiveGroupPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Archive Legal team?"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("archiveGroupPanel")));
    QVERIFY(shown(QStringLiteral("groupPage")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("groupPage")));
    QTRY_VERIFY(waitItem(QStringLiteral("group_") + groupId)->hasActiveFocus());
    QCOMPARE(m_session->accessDirectory()->groups().constFirst().toMap().value(QStringLiteral("members")).toList().size(), 1);
    // The group opens again by keyboard, and its Back button returns.
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("groupPage")));
    QTRY_VERIFY(waitItem(QStringLiteral("groupBackButton"))->hasActiveFocus());
    clickItem(waitItem(QStringLiteral("groupBackButton")));
    QTRY_VERIFY(!shown(QStringLiteral("groupPage")));

    // Roles are a table of their name, type, and scope; the list's commands
    // are New role and Open, which acts on the one selected.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    QTRY_VERIFY(shown(QStringLiteral("role_content_reader")));
    QCOMPARE(propertyOf(QStringLiteral("role_owner"), "cells").toStringList(),
             (QStringList{QStringLiteral("Owner"), QStringLiteral("Built-in"), QStringLiteral("Organization")}));
    QCOMPARE(cell(QStringLiteral("role_content_reader"), 2), QStringLiteral("Spaces"));
    QVERIFY(!itemNamed(QStringLiteral("roleListCopyButton")) && !itemNamed(QStringLiteral("roleListArchiveButton")));
    QVERIFY(!propertyOf(QStringLiteral("accessOpenButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("role_content_reader")));
    QTRY_VERIFY(propertyOf(QStringLiteral("role_content_reader"), "selected").toBool());
    QVERIFY(!shown(QStringLiteral("rolePage")));
    QVERIFY(propertyOf(QStringLiteral("accessOpenButton"), "usable").toBool());
    // The arrows move the selection; one row at a time.
    key(Qt::Key_Down);
    QTRY_VERIFY(!propertyOf(QStringLiteral("role_content_reader"), "selected").toBool());
    // New role opens in the panel; a created role opens its page.
    clickItem(waitItem(QStringLiteral("accessCreateButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolePanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("roleNameField"))->hasActiveFocus());
    type(QStringLiteral("Reviewers"));
    QVERIFY(!shown(QStringLiteral("permission_membership.list")));
    clickItem(waitItem(QStringLiteral("permission_content.download")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    QTRY_VERIFY(!shown(QStringLiteral("rolePanel")));
    QCOMPARE(propertyOf(QStringLiteral("roleKind"), "text").toString(), QStringLiteral("Custom"));
    QCOMPARE(propertyOf(QStringLiteral("roleScope"), "text").toString(), QStringLiteral("Spaces"));
    // Its Permissions tab is a table of what it allows, by area.
    clickItem(waitItem(QStringLiteral("roleTab_permissions")));
    QTRY_VERIFY(shown(QStringLiteral("rolePermission_content.download")));
    QCOMPARE(propertyOf(QStringLiteral("rolePermission_content.download"), "cells").toStringList(),
             (QStringList{QStringLiteral("Files"), QStringLiteral("Download files")}));
    QVERIFY(!panelOpen());
    // Made of an action Core reads only from a grant on the place, the new
    // role is given on places, never across the organization.
    QCOMPARE(m_session->accessDirectory()->assignableRoles().size(), 5);
    QCOMPARE(m_session->accessDirectory()->grantableRoles().constLast().toMap().value(QStringLiteral("actions")).toStringList(),
             QStringList{QStringLiteral("content.download")});
    // Edit permissions changes them for every holder.
    clickItem(waitItem(QStringLiteral("roleEditButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Edit permissions"));
    QVERIFY(propertyOf(QStringLiteral("permission_content.download"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("permission_content.list")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("rolePanel")));
    QTRY_VERIFY(shown(QStringLiteral("rolePermission_content.list")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("rolePage")));
    // A built-in role is read only, its changes there but unusable, saying
    // why; Copy makes a custom role from it.
    openRow(waitItem(QStringLiteral("role_content_reader")));
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    QVERIFY(shown(QStringLiteral("roleEditButton")));
    QVERIFY(!propertyOf(QStringLiteral("roleEditButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("roleEditButton"), "reason").toString().isEmpty());
    QVERIFY(!propertyOf(QStringLiteral("roleArchiveButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("roleKind"), "text").toString(), QStringLiteral("Built-in"));
    clickItem(waitItem(QStringLiteral("roleCopyButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("roleNameField"), "text").toString(), QStringLiteral("Copy of Content reader"));
    QVERIFY(propertyOf(QStringLiteral("permission_content.list"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("rolePanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("roleKind"), "text").toString(), QStringLiteral("Custom"));
    // Archiving a custom role asks, then returns to the list.
    clickItem(waitItem(QStringLiteral("roleArchiveButton")));
    QTRY_VERIFY(shown(QStringLiteral("archiveRolePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Archive Copy of Content reader?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("rolePage")));
    QTRY_VERIFY(!shown(QStringLiteral("archiveRolePanel")));
    QTRY_COMPARE(m_session->accessDirectory()->grantableRoles().size(), 12);

    // A space's page lists who has access, read only: selecting a row
    // selects it, and the command bar acts on it. Grant access picks
    // people, then several roles at once.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    openRow(waitItem(QStringLiteral("accessSpace_") + spaceId));
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QCOMPARE(propertyOf(QStringLiteral("spaceTitle"), "text").toString(), QStringLiteral("Contracts"));
    QTRY_COMPARE(propertyOf(QStringLiteral("spaceVisibility"), "text").toString(), QStringLiteral("Private"));
    clickItem(waitItem(QStringLiteral("spaceTab_access")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_empty")));
    QVERIFY(!propertyOf(QStringLiteral("manageAccessRolesButton"), "usable").toBool());
    QVERIFY(!shown(QStringLiteral("stopInheritingButton")));
    QTRY_VERIFY(propertyOf(QStringLiteral("grantAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("grantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Grant access"));
    const QString holder = QStringLiteral("user:") + bo;
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("grantPrincipal_") + holder));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    // Roles come on a step of their own, each checked from the keyboard:
    // Core's space roles, atomic then broad.
    QTRY_VERIFY(shown(QStringLiteral("grantRole_role-content_reader")));
    QCOMPARE(propertyOf(QStringLiteral("grantRole_role-space_operator"), "text").toString(), QStringLiteral("Space operator"));
    QCOMPARE(propertyOf(QStringLiteral("grantRole_role-space_admin"), "text").toString(), QStringLiteral("Space administrator"));
    QVERIFY(!itemNamed(QStringLiteral("grantRole_role-owner")));
    QVERIFY(!shown(QStringLiteral("grantPrincipal_") + holder));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSubtitle"), "text").toString(), QStringLiteral("1 picked"));
    focusOn(waitItem(QStringLiteral("grantRole_role-content_reader")));
    key(Qt::Key_Space);
    focusOn(waitItem(QStringLiteral("grantRole_role-content_contributor")));
    key(Qt::Key_Space);
    QTRY_VERIFY(propertyOf(QStringLiteral("grantRole_role-content_contributor"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    QCOMPARE(m_session->accessGrants()->holders().size(), 1);
    QCOMPARE(m_session->accessGrants()->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList(),
             (QStringList{QStringLiteral("role-content_reader"), QStringLiteral("role-content_contributor")}));
    QTRY_VERIFY(shown(QStringLiteral("accessGrantsNotice")));
    QCOMPARE(cell(QStringLiteral("accessHolder_") + holder, 1), QStringLiteral("Content reader, Content contributor"));
    QCOMPARE(cell(QStringLiteral("accessHolder_") + holder, 2), QStringLiteral("Given here"));
    // Selecting the row lets Manage roles open its roles as checkboxes;
    // Save makes the checked ones theirs.
    clickItem(waitItem(QStringLiteral("accessHolder_") + holder));
    QTRY_VERIFY(propertyOf(QStringLiteral("accessHolder_") + holder, "selected").toBool());
    QVERIFY(!panelOpen());
    QTRY_VERIFY(propertyOf(QStringLiteral("manageAccessRolesButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("manageAccessRolesButton")));
    QTRY_VERIFY(shown(QStringLiteral("holderRolesPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSubtitle"), "text").toString(), QStringLiteral("bo@localhost"));
    QVERIFY(propertyOf(QStringLiteral("grantRole_role-content_reader"), "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    focusOn(waitItem(QStringLiteral("grantRole_role-content_reader")));
    key(Qt::Key_Space);
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("holderRolesPanel")));
    QCOMPARE(m_session->accessGrants()->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList(),
             QStringList{QStringLiteral("role-content_contributor")});
    QTRY_VERIFY(waitItem(QStringLiteral("manageAccessRolesButton"))->hasActiveFocus());
    // Check access says what Bo may do here and why.
    clickItem(waitItem(QStringLiteral("checkAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("checkAccessPanel")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("checkAccess_") + bo));
    QTRY_VERIFY(shown(QStringLiteral("checkAccessReason_0")));
    QCOMPARE(propertyOf(QStringLiteral("checkAccessReason_0"), "text").toString(), QStringLiteral("Content contributor on Contracts."));
    QVERIFY(!shown(QStringLiteral("checkAccessNone")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(shown(QStringLiteral("checkAccess_") + bo));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("checkAccessPanel")));
    // Removing access asks in its panel, naming the roles lost.
    QTRY_VERIFY(propertyOf(QStringLiteral("removeAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("removeAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeAccessPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(propertyOf(QStringLiteral("confirmDetail"), "text").toString().contains(QStringLiteral("Content contributor")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_empty")));
    QTRY_VERIFY(!shown(QStringLiteral("removeAccessPanel")));
    QVERIFY(!propertyOf(QStringLiteral("removeAccessButton"), "usable").toBool());
    // Rename names the space in a panel; the page and the list follow.
    QTRY_VERIFY(propertyOf(QStringLiteral("spaceRenameButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("spaceRenameButton")));
    QTRY_VERIFY(shown(QStringLiteral("spaceNamePanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("spaceNameField"))->hasActiveFocus());
    QCOMPARE(propertyOf(QStringLiteral("spaceNameField"), "text").toString(), QStringLiteral("Contracts"));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    type(QStringLiteral("Agreements"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("spaceNamePanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("spaceTitle"), "text").toString(), QStringLiteral("Agreements"));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Space renamed."));
    QTRY_COMPARE(m_session->accessGrants()->name(), QStringLiteral("Agreements"));
    // Archive asks first; archived, the space reads so and refuses a rename.
    QTRY_VERIFY(propertyOf(QStringLiteral("spaceArchiveButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("spaceArchiveButton")));
    QTRY_VERIFY(shown(QStringLiteral("archiveSpacePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Archive Agreements?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("archiveSpacePanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("spaceStatus"), "text").toString(), QStringLiteral("Archived"));
    QVERIFY(shown(QStringLiteral("spaceRenameButton")));
    QVERIFY(!propertyOf(QStringLiteral("spaceRenameButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("spaceArchiveButton"), "reason").toString(), QStringLiteral("It is archived."));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("spacePage")));
    QTRY_COMPARE(cell(QStringLiteral("accessSpace_") + spaceId, 1), QStringLiteral("Archived"));

    // A new tag is named and restricted in the panel, then opens its page.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_tags").arg(orgId)));
    clickItem(waitItem(QStringLiteral("accessCreateButton")));
    QTRY_VERIFY(shown(QStringLiteral("tagEditor")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("tagNameField"))->hasActiveFocus());
    type(QStringLiteral("Secret"));
    clickItem(waitItem(QStringLiteral("tagRestrictedSwitch")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("tagPage")));
    QTRY_COMPARE(propertyOf(QStringLiteral("tagTitle"), "text").toString(), QStringLiteral("Secret"));
    QCOMPARE(propertyOf(QStringLiteral("tagControl"), "text").toString(), QStringLiteral("Restricted"));
    QVERIFY(m_session->accessDirectory()->tags().constFirst().toMap().value(QStringLiteral("access_controlled")).toBool());
    QTRY_VERIFY(!shown(QStringLiteral("tagEditor")));
    // Everyone with a role may be given the tag, through the same panel.
    clickItem(waitItem(QStringLiteral("tagTab_access")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_empty")));
    QVERIFY(!shown(QStringLiteral("checkAccessButton")));
    QTRY_VERIFY(propertyOf(QStringLiteral("grantAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("grantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("grantPrincipal_search")));
    QTRY_VERIFY(panelOpen());
    clicks(waitItem(QStringLiteral("grantPrincipal_search")), QStringLiteral("content contributor"));
    clickItem(waitItem(QStringLiteral("grantPrincipal_role:role-content_contributor")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    focusOn(waitItem(QStringLiteral("grantRole_role-content_reader")));
    key(Qt::Key_Space);
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(m_session->accessGrants()->holders().size(), 1);
    QCOMPARE(m_session->accessGrants()->holders().constFirst().toMap().value(QStringLiteral("principalKind")).toString(),
             QStringLiteral("role"));
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    // Edit tag renames it in its panel.
    clickItem(waitItem(QStringLiteral("editTagButton")));
    QTRY_VERIFY(shown(QStringLiteral("tagEditor")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!shown(QStringLiteral("tagRestrictedSwitch")));
    clicks(waitItem(QStringLiteral("tagNameField")), QStringLiteral("Top secret"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("tagEditor")));
    QTRY_COMPARE(propertyOf(QStringLiteral("tagTitle"), "text").toString(), QStringLiteral("Top secret"));
    // Stop restricting says what it changes first.
    QCOMPARE(propertyOf(QStringLiteral("restrictTagButton"), "text").toString(), QStringLiteral("Stop restricting"));
    clickItem(waitItem(QStringLiteral("restrictTagButton")));
    QTRY_VERIFY(shown(QStringLiteral("restrictTagPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(propertyOf(QStringLiteral("confirmDetail"), "text").toString().contains(QStringLiteral("visible to everyone")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("restrictTagPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("tagControl"), "text").toString(), QStringLiteral("Open"));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Tag no longer restricts."));
    QCOMPARE(propertyOf(QStringLiteral("restrictTagButton"), "text").toString(), QStringLiteral("Restrict"));
    // Archiving the tag asks in its panel, then returns to the list.
    clickItem(waitItem(QStringLiteral("archiveTagButton")));
    QTRY_VERIFY(shown(QStringLiteral("archiveTagPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Archive Top secret?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("tagPage")));
    QTRY_VERIFY(m_session->accessDirectory()->tags().isEmpty());
    QVERIFY(!m_session->accessGrants()->active());
}

// Rename organization opens a side panel with the name selected; Enter
// saves it and closes the panel, focus back on the command.
void TestStudio::renameOrganizationInAPanel()
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_general").arg(orgId)));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    const QString before = propertyOf(QStringLiteral("organizationName"), "text").toString();
    QTRY_VERIFY(propertyOf(QStringLiteral("renameOrganizationButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("renameOrganizationButton")));
    QTRY_VERIFY(shown(QStringLiteral("renameOrganizationPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("organizationNameField"))->hasActiveFocus());
    QCOMPARE(propertyOf(QStringLiteral("organizationNameField"), "text").toString(), before);
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    type(QStringLiteral("Renamed"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("renameOrganizationPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("organizationName"), "text").toString(), QStringLiteral("Renamed"));
    QTRY_VERIFY(waitItem(QStringLiteral("renameOrganizationButton"))->hasActiveFocus());
    // Escape closes the panel before it leaves Settings.
    clickItem(waitItem(QStringLiteral("renameOrganizationButton")));
    QTRY_VERIFY(panelOpen());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("renameOrganizationPanel")));
    QVERIFY(m_session->settingsActive());
}

// A on a focused folder opens its access page in place of the list; its
// command bar opens one side panel per change, and keys stay on the page.
// A folder below lists that grant and the space's as inherited, with where
// they come from: the folder opens here, the space in Settings. Stopping
// inheritance says who keeps access, and Restore brings it back.
void TestStudio::explorerManagesFolderAccess()
{
    window()->resize(1200, 1100);
    openSpace(QStringLiteral("Inbox"));
    const QString spaceId = m_session->currentSpaceId();
    addFolder(QStringLiteral("Plans"));
    const QString folder = entryId(QStringLiteral("Plans"));
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("explorer")), "focusDefault");
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Plans")));
    key(Qt::Key_A);
    QTRY_VERIFY(shown(QStringLiteral("accessPage")));
    QVERIFY(!shown(QStringLiteral("entryPane")));
    QVERIFY(!panelOpen());
    QCOMPARE(m_session->accessGrants()->kind(), QStringLiteral("folder"));
    QCOMPARE(m_session->accessGrants()->targetId(), folder);
    QCOMPARE(propertyOf(QStringLiteral("placeTitle"), "text").toString(), QStringLiteral("Plans"));
    QTRY_VERIFY(waitItem(QStringLiteral("placeBackButton"))->hasActiveFocus());
    // It opens on its Access tab; inheritance and Check access are the
    // page's own commands.
    QVERIFY(shown(QStringLiteral("stopInheritingButton")));
    QVERIFY(shown(QStringLiteral("checkAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_empty")));
    QCOMPARE(propertyOf(QStringLiteral("placeInheritance"), "text").toString(), QStringLiteral("From the space"));
    QVERIFY(m_session->accessGrants()->inherited().isEmpty());
    QTRY_VERIFY(!m_session->accessGrants()->principals().isEmpty());
    const QString principal = m_session->accessGrants()->principals().constFirst().toMap().value(QStringLiteral("value")).toString();
    // Keys stay on the page: A does not reach the explorer.
    key(Qt::Key_A);
    QVERIFY(shown(QStringLiteral("accessPage")));
    QVERIFY(!panelOpen());
    QCOMPARE(m_session->accessGrants()->targetId(), folder);
    QTRY_VERIFY(propertyOf(QStringLiteral("grantAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("grantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("grantPrincipal_") + principal));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    clickItem(waitItem(QStringLiteral("grantRole_role-content_reader")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    // The folder's own grants list the holder; the panel closes.
    QTRY_COMPARE(m_session->accessGrants()->holders().size(), 1);
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_") + principal));
    clickItem(waitItem(QStringLiteral("accessHolder_") + principal));
    clickItem(waitItem(QStringLiteral("manageAccessRolesButton")));
    QTRY_VERIFY(shown(QStringLiteral("holderRolesPanel")));
    QTRY_VERIFY(panelOpen());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("holderRolesPanel")));
    QTRY_VERIFY(waitItem(QStringLiteral("manageAccessRolesButton"))->hasActiveFocus());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("accessPage")));
    QVERIFY(!m_session->accessGrants()->active());
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Plans")));

    // The space gives Content reader to the same person.
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Inbox"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(principal, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->close();
    m_session->openEntry(QStringLiteral("folder"), folder);
    QVERIFY(waitIdle());
    addFolder(QStringLiteral("Drafts"));
    const QString drafts = entryId(QStringLiteral("Drafts"));
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("explorer")), "focusDefault");
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Drafts")));
    key(Qt::Key_A);
    QTRY_VERIFY(shown(QStringLiteral("accessPage")));
    QTRY_VERIFY(!grants->busy());
    QVERIFY(grants->holders().isEmpty());
    QCOMPARE(grants->inherited().size(), 2);
    const QString fromSpace = QStringLiteral("accessHolder_inherited:space:%1_%2").arg(spaceId, principal);
    const QString fromFolder = QStringLiteral("accessHolder_inherited:folder:%1_%2").arg(folder, principal);
    QTRY_VERIFY(shown(fromSpace));
    QVERIFY(shown(fromFolder));
    QCOMPARE(cell(fromSpace, 1), QStringLiteral("Content reader"));
    QCOMPARE(cell(fromSpace, 2), QStringLiteral("From the space Inbox"));
    QTRY_COMPARE(cell(fromFolder, 2), QStringLiteral("From the folder Plans"));
    // An inherited row changes where it comes from: its roles are not
    // managed here.
    clickItem(waitItem(fromSpace));
    QTRY_VERIFY(propertyOf(fromSpace, "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("manageAccessRolesButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("removeAccessButton"), "usable").toBool());

    // Stopping inheritance as Restricted says who loses access; Core then
    // lists nothing from above but what manages access.
    clickItem(waitItem(QStringLiteral("stopInheritingButton")));
    QTRY_VERIFY(shown(QStringLiteral("inheritancePanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(propertyOf(QStringLiteral("inheritance_restricted"), "selected").toBool());
    QCOMPARE(propertyOf(QStringLiteral("inheritanceKept"), "text").toString(), QStringLiteral("Nobody given access here."));
    QVERIFY(propertyOf(QStringLiteral("inheritanceLost"), "text").toString().contains(grants->inherited().constFirst().toMap()
                                                                                      .value(QStringLiteral("principalName")).toString()));
    clickItem(waitItem(QStringLiteral("inheritance_open")));
    QVERIFY(propertyOf(QStringLiteral("inheritanceKept"), "text").toString().contains(QStringLiteral("Every member except guests")));
    clickItem(waitItem(QStringLiteral("inheritance_restricted")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("inheritancePanel")));
    QTRY_COMPARE(grants->summary().value(QStringLiteral("inheritance")).toString(), QStringLiteral("restricted"));
    QTRY_VERIFY(!grants->busy());
    QVERIFY(grants->inherited().isEmpty());
    QCOMPARE(propertyOf(QStringLiteral("placeInheritance"), "text").toString(), QStringLiteral("Stopped: restricted"));
    // Stopped, it switches straight between Restricted and Open.
    QCOMPARE(propertyOf(QStringLiteral("stopInheritingButton"), "text").toString(), QStringLiteral("Change inheritance"));
    clickItem(waitItem(QStringLiteral("stopInheritingButton")));
    QTRY_VERIFY(shown(QStringLiteral("inheritancePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Change inheritance"));
    QVERIFY(propertyOf(QStringLiteral("inheritance_restricted"), "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("inheritance_open")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("inheritancePanel")));
    QTRY_COMPARE(grants->summary().value(QStringLiteral("inheritance")).toString(), QStringLiteral("open"));
    QTRY_VERIFY(!grants->busy());
    QTRY_COMPARE(propertyOf(QStringLiteral("accessGrantsNotice"), "text").toString(),
                 QStringLiteral("Open: every member except guests reads it now."));
    // Restore inheritance asks, then lists what comes from above again.
    clickItem(waitItem(QStringLiteral("restoreInheritanceButton")));
    QTRY_VERIFY(shown(QStringLiteral("restoreInheritancePanel")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("restoreInheritancePanel")));
    QTRY_COMPARE(grants->inherited().size(), 2);
    QVERIFY(grants->summary().value(QStringLiteral("inheritance")).toString().isEmpty());
    QCOMPARE(grants->targetId(), drafts);

    // The folder it comes from opens here.
    openRow(waitItem(fromFolder));
    QTRY_COMPARE(grants->targetId(), folder);
    QVERIFY(shown(QStringLiteral("accessPage")));
    QTRY_VERIFY(!grants->busy());
    QCOMPARE(grants->name(), QStringLiteral("Plans"));
    QCOMPARE(grants->holders().size(), 1);
    QCOMPARE(grants->inherited().size(), 1);
    // The space's access opens in Settings.
    QTRY_VERIFY(shown(fromSpace));
    openRow(waitItem(fromSpace));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QCOMPARE(propertyOf(QStringLiteral("spaceTitle"), "text").toString(), QStringLiteral("Inbox"));
    QTRY_VERIFY(shown(QStringLiteral("accessTable")));
    QTRY_COMPARE(grants->kind(), QStringLiteral("space"));
}

// Content reader leaves no upload or new folder in the explorer; Content
// contributor brings them back once the location refreshes.
void TestStudio::explorerFollowsSpaceAccess()
{
    openSpace(QStringLiteral("Inbox"));
    const QString spaceId = m_session->currentSpaceId();
    QTRY_VERIFY(propertyOf(QStringLiteral("uploadButton"), "usable").toBool());
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    QString me;
    for (const auto &member : directory->members())
        if (member.toMap().value(QStringLiteral("label")) == QLatin1String("ok@localhost")) me = member.toMap().value(QStringLiteral("id")).toString();
    QVERIFY(!me.isEmpty());
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Inbox"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("user:") + me, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    QTRY_VERIFY(!grants->busy());
    m_session->runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(!propertyOf(QStringLiteral("uploadButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("newButton"), "usable").toBool());
    QVERIFY(propertyOf(QStringLiteral("refreshButton"), "usable").toBool());
    grants->setRoles(QStringLiteral("user:") + me, {QStringLiteral("role-content_contributor")});
    QTRY_COMPARE(grants->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList(),
                 QStringList{QStringLiteral("role-content_contributor")});
    QTRY_VERIFY(!grants->busy());
    grants->close();
    key(Qt::Key_F5);
    QTRY_VERIFY(propertyOf(QStringLiteral("uploadButton"), "usable").toBool());
    QVERIFY(propertyOf(QStringLiteral("newButton"), "usable").toBool());
}

// Selecting a person opens their page: how they sign in, their roles,
// groups, and where they have access, each opening that item. A folder
// opens its access as a page and Back returns to the person; a space opens
// at its entry. Manage roles and Manage groups are panels with checkboxes;
// Core's refusal to drop the last owner stays in the panel, and removing
// the person asks first, naming what they lose.
void TestStudio::memberPageListsAccessGroupsAndRoles()
{
    window()->resize(1200, 1600);
    openSpace(QStringLiteral("Contracts"));
    addFolder(QStringLiteral("Plans"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    const QString folder = entryId(QStringLiteral("Plans"));
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    directory->createGroup(QStringLiteral("Legal"));
    QTRY_COMPARE(directory->groups().size(), 1);
    QTRY_VERIFY(!directory->busy());
    const QString legal = directory->groups().constFirst().toMap().value(QStringLiteral("id")).toString();
    directory->setGroupMembers(legal, {bo});
    QTRY_COMPARE(directory->notice(), QStringLiteral("group_members_saved"));
    QTRY_VERIFY(!directory->busy());
    directory->createRole(QStringLiteral("Auditors"), {QStringLiteral("membership.list")});
    QTRY_COMPARE(directory->notice(), QStringLiteral("role_created"));
    QTRY_VERIFY(!directory->busy());
    QString auditors;
    for (const auto &role : directory->assignableRoles())
        if (role.toMap().value(QStringLiteral("name")) == QLatin1String("Auditors")) auditors = role.toMap().value(QStringLiteral("id")).toString();
    QVERIFY(!auditors.isEmpty());
    // Bo views Contracts; Legal edits its folder Plans.
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Contracts"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("user:") + bo, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->open(QStringLiteral("folder"), spaceId, folder, QStringLiteral("Plans"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("group:") + legal, {QStringLiteral("role-content_contributor")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->close();

    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    // People reloads on entry; the row is clicked once that load ends.
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    // Organization roles read as people name them.
    QCOMPARE(rowProperty(QStringLiteral("member_"), QStringLiteral("ok@localhost"), "cells").toStringList().value(1), QStringLiteral("Owner"));
    openRow(waitItem(QStringLiteral("member_") + bo));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QVERIFY(!panelOpen());
    QVERIFY(!shown(QStringLiteral("memberList")));
    QVERIFY(!shown(QStringLiteral("newUserButton")));
    QTRY_VERIFY(waitItem(QStringLiteral("userBackButton"))->hasActiveFocus());
    QCOMPARE(propertyOf(QStringLiteral("userIdentifier"), "text").toString(), QStringLiteral("bo@localhost"));
    QCOMPARE(propertyOf(QStringLiteral("userKind"), "text").toString(), QStringLiteral("Personal"));
    // A personal account has no setup code, and the command says so.
    QVERIFY(!propertyOf(QStringLiteral("userSetupCodeButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("userSetupCodeButton"), "reason").toString().isEmpty());
    clickItem(waitItem(QStringLiteral("userTab_groups")));
    QTRY_VERIFY(shown(QStringLiteral("userGroup_") + legal));
    // The Roles tab: each organization role and where it holds.
    clickItem(waitItem(QStringLiteral("userTab_roles")));
    QTRY_VERIFY(waitRow(QStringLiteral("heldRole_"), QStringLiteral("Member")));
    QCOMPARE(rowProperty(QStringLiteral("heldRole_"), QStringLiteral("Member"), "cells").toStringList(),
             (QStringList{QStringLiteral("Member"), QStringLiteral("Organization")}));
    // The Access tab: every place, with the roles held there and how they
    // reach them.
    clickItem(waitItem(QStringLiteral("userTab_access")));
    QQuickItem *onSpace = waitFound([&] { return rowWith(QStringLiteral("heldAccess_"), 0, QStringLiteral("Contracts")); });
    QQuickItem *onFolder = waitFound([&] { return rowWith(QStringLiteral("heldAccess_"), 0, QStringLiteral("Plans in Contracts")); });
    QVERIFY(onSpace && onFolder);
    QCOMPARE(onSpace->property("cells").toStringList(),
             (QStringList{QStringLiteral("Contracts"), QStringLiteral("Content reader"), QStringLiteral("Direct")}));
    QCOMPARE(onFolder->property("cells").toStringList(),
             (QStringList{QStringLiteral("Plans in Contracts"), QStringLiteral("Content contributor"), QStringLiteral("Through the group Legal")}));
    // What comes through a group is removed from the group.
    clickItem(onFolder);
    QTRY_VERIFY(onFolder->property("selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("heldRemoveButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("heldRemoveButton"), "reason").toString().isEmpty());

    // The folder opens its access as a page, with what it inherits; Back
    // returns to the person's page.
    focusOn(onFolder);
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("placePage")));
    QTRY_VERIFY(!shown(QStringLiteral("userPage")));
    QCOMPARE(propertyOf(QStringLiteral("placeTitle"), "text").toString(), QStringLiteral("Plans in Contracts"));
    QCOMPARE(propertyOf(QStringLiteral("placeBackButton"), "text").toString(), QStringLiteral("bo@localhost"));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_group:") + legal));
    const QString inherited = QStringLiteral("accessHolder_inherited:space:%1_user:%2").arg(spaceId, bo);
    QTRY_VERIFY(shown(inherited));
    QCOMPARE(cell(inherited, 2), QStringLiteral("From the space Contracts"));
    QTRY_VERIFY(waitItem(QStringLiteral("placeBackButton"))->hasActiveFocus());
    clickItem(waitItem(QStringLiteral("placeBackButton")));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QVERIFY(!shown(QStringLiteral("placePage")));

    // Manage roles: every organization role as a checkbox, built-in ones
    // first; Save leaves exactly the checked ones.
    QTRY_VERIFY(propertyOf(QStringLiteral("userManageRolesButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userManageRolesButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolesPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Manage roles"));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSubtitle"), "text").toString(), QStringLiteral("bo@localhost"));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    QTRY_VERIFY(propertyOf(QStringLiteral("manageRole_role-member"), "selected").toBool());
    QCOMPARE(propertyOf(QStringLiteral("manageRole_role-owner"), "text").toString(), QStringLiteral("Owner"));
    QVERIFY(!shown(QStringLiteral("manageRole_role-content_reader")));
    clickItem(waitItem(QStringLiteral("manageRole_") + auditors));
    clickItem(waitItem(QStringLiteral("manageRole_role-admin")));
    clickItem(waitItem(QStringLiteral("manageRole_role-member")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("rolesPanel")));
    clickItem(waitItem(QStringLiteral("userTab_roles")));
    QTRY_VERIFY(rowTitled(QStringLiteral("heldRole_"), QStringLiteral("Auditors")));
    QTRY_VERIFY(rowTitled(QStringLiteral("heldRole_"), QStringLiteral("Administrator")));
    QVERIFY(!rowTitled(QStringLiteral("heldRole_"), QStringLiteral("Member")));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Roles saved."));
    QTRY_VERIFY(!directory->busy());
    const auto rolesOf = [directory](const QString &id) {
        for (const auto &member : directory->members())
            if (member.toMap().value(QStringLiteral("id")) == id) return member.toMap().value(QStringLiteral("roles")).toStringList();
        return QStringList();
    };
    QTRY_COMPARE(rolesOf(bo), QStringList{QStringLiteral("admin")});

    // Manage groups: a checkbox per group; Save leaves exactly those.
    QTRY_VERIFY(propertyOf(QStringLiteral("userManageGroupsButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userManageGroupsButton")));
    QTRY_VERIFY(shown(QStringLiteral("memberGroupsPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(propertyOf(QStringLiteral("memberGroup_") + legal, "selected").toBool());
    clickItem(waitItem(QStringLiteral("memberGroup_") + legal));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("memberGroupsPanel")));
    clickItem(waitItem(QStringLiteral("userTab_groups")));
    QTRY_VERIFY(shown(QStringLiteral("userGroup_empty")));
    QVERIFY(!shown(QStringLiteral("userGroup_") + legal));
    // The notice names the last change saved, and only that one.
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Groups saved."));
    QVERIFY(directory->groups().constFirst().toMap().value(QStringLiteral("members")).toList().isEmpty());

    // Removing Bo asks in a panel, naming the access and the role Bo loses.
    QTRY_VERIFY(propertyOf(QStringLiteral("userRemoveButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userRemoveButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeMemberPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Remove member"));
    const QString impact = propertyOf(QStringLiteral("confirmDetail"), "text").toString();
    QVERIFY2(impact.contains(QStringLiteral("1 place")) && !impact.contains(QStringLiteral("Legal"))
             && impact.contains(QStringLiteral("Auditors")) && !impact.contains(QStringLiteral("Administrator")), qPrintable(impact));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("removeMemberPanel")));
    QVERIFY(shown(QStringLiteral("userPage")));

    // Removing the space access asks, naming it, then it is gone.
    clickItem(waitItem(QStringLiteral("userTab_access")));
    onSpace = waitFound([&] { return rowWith(QStringLiteral("heldAccess_"), 0, QStringLiteral("Contracts")); });
    QVERIFY(onSpace);
    clickItem(onSpace);
    QTRY_VERIFY(propertyOf(QStringLiteral("heldRemoveButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("heldRemoveButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeHeldPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("confirmDetail"), "text").toString(), QStringLiteral("Content reader · Contracts"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("removeHeldPanel")));
    QTRY_VERIFY(!rowWith(QStringLiteral("heldAccess_"), 0, QStringLiteral("Contracts")));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(),
                 QStringLiteral("Access removed here. Access through groups or other places stays."));
    // Grant access picks the space, then the roles given there.
    QTRY_VERIFY(propertyOf(QStringLiteral("heldGrantAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("heldGrantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("placeGrantPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("pickPlace_space:") + spaceId));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    focusOn(waitItem(QStringLiteral("placeGrantRole_role-content_reader")));
    key(Qt::Key_Space);
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("placeGrantPanel")));
    onSpace = waitFound([&] { return rowWith(QStringLiteral("heldAccess_"), 0, QStringLiteral("Contracts")); });
    QVERIFY(onSpace);

    // The space opens at its entry.
    openRow(onSpace);
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QCOMPARE(propertyOf(QStringLiteral("spaceTitle"), "text").toString(), QStringLiteral("Contracts"));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_user:") + bo));
    QVERIFY(!shown(QStringLiteral("userPage")));

    // The last owner keeps Owner: Core's refusal stays in the panel.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    openRow(waitRow(QStringLiteral("member_"), QStringLiteral("ok@localhost")));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QTRY_VERIFY(propertyOf(QStringLiteral("userManageRolesButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userManageRolesButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolesPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(propertyOf(QStringLiteral("manageRole_role-owner"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("manageRole_role-owner")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("rolesPanelError")));
    QCOMPARE(propertyOf(QStringLiteral("rolesPanelError"), "text").toString(), QStringLiteral("The organization must keep at least one owner."));
    QVERIFY(shown(QStringLiteral("rolesPanel")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("rolesPanel")));
    // Esc then leaves the page for the list.
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("userPage")));
    QTRY_VERIFY(rowFocused(QStringLiteral("member_"), QStringLiteral("ok@localhost")));
}

// New user makes an account the organization manages; without a password
// the panel shows its setup code once. Its page issues a new one, and a
// taken username is refused in the panel.
void TestStudio::peopleCreatesManagedUsers()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(propertyOf(QStringLiteral("newUserButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("newUserButton")));
    QTRY_VERIFY(shown(QStringLiteral("newUserPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("newUserUsernameField"))->hasActiveFocus());
    type(QStringLiteral("A"));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    type(QStringLiteral("na.lima"));
    QVERIFY(propertyOf(QStringLiteral("newUserRole_member"), "selected").toBool());
    clicks(waitItem(QStringLiteral("newUserNameField")), QStringLiteral("Ana Lima"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("setupCodeField")));
    const QString identifier = m_session->orgAdmin()->slug() + QStringLiteral("/ana.lima");
    QCOMPARE(propertyOf(QStringLiteral("setupIdentifierField"), "text").toString(), identifier);
    QVERIFY(propertyOf(QStringLiteral("setupCodeField"), "text").toString().startsWith(QLatin1String("mst_")));
    QVERIFY(!shown(QStringLiteral("sidePanelSave")));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelCancel"), "text").toString(), QStringLiteral("Close"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("newUserPanel")));
    QVERIFY(m_session->orgAdmin()->setupCode().isEmpty());
    QTRY_VERIFY(waitItem(QStringLiteral("newUserButton"))->hasActiveFocus());

    // The account's page says how it signs in and issues a new code.
    openRow(waitRow(QStringLiteral("member_"), QStringLiteral("Ana Lima")));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QCOMPARE(propertyOf(QStringLiteral("userIdentifier"), "text").toString(), identifier);
    QCOMPARE(propertyOf(QStringLiteral("userKind"), "text").toString(), QStringLiteral("Managed by the organization"));
    QTRY_VERIFY(propertyOf(QStringLiteral("userSetupCodeButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userSetupCodeButton")));
    QTRY_VERIFY(shown(QStringLiteral("setupCodePanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!shown(QStringLiteral("setupCodeField")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("setupCodeField")));
    QVERIFY(propertyOf(QStringLiteral("setupCodeField"), "text").toString().startsWith(QLatin1String("mst_")));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelCancel"), "text").toString(), QStringLiteral("Close"));
    clickItem(waitItem(QStringLiteral("sidePanelCancel")));
    QTRY_VERIFY(!shown(QStringLiteral("setupCodePanel")));
    clickItem(waitItem(QStringLiteral("userBackButton")));
    QTRY_VERIFY(!shown(QStringLiteral("userPage")));

    // A taken username is refused in the panel; a password leaves no code.
    clickItem(waitItem(QStringLiteral("newUserButton")));
    QTRY_VERIFY(shown(QStringLiteral("newUserPanel")));
    QTRY_VERIFY(waitItem(QStringLiteral("newUserUsernameField"))->hasActiveFocus());
    type(QStringLiteral("ana.lima"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("newUserError")));
    QCOMPARE(propertyOf(QStringLiteral("newUserError"), "text").toString(), QStringLiteral("That username is taken in this organization."));
    clicks(waitItem(QStringLiteral("newUserUsernameField")), QStringLiteral("robot"));
    QVERIFY(!shown(QStringLiteral("newUserError")));
    clicks(waitItem(QStringLiteral("newUserPasswordField")), QStringLiteral("long-secret"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("newUserPanel")));
    QTRY_VERIFY(waitRow(QStringLiteral("member_"), QStringLiteral("robot")));
    QTRY_COMPARE(propertyOf(QStringLiteral("orgAdminNotice"), "text").toString(), QStringLiteral("User created."));
}

// A role's page lists who holds it, organization-wide and on places; Add
// people gives it to several at once, and each row opens the person,
// group, or place.
void TestStudio::rolePageListsHoldersAndAddsPeople()
{
    window()->resize(1200, 1300);
    openSpace(QStringLiteral("Contracts"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    const QString cy = m_core.seedMember(orgId, QStringLiteral("cy@localhost"), QStringLiteral("guest"));
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    directory->createGroup(QStringLiteral("Legal"));
    QTRY_COMPARE(directory->groups().size(), 1);
    QTRY_VERIFY(!directory->busy());
    const QString legal = directory->groups().constFirst().toMap().value(QStringLiteral("id")).toString();
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Contracts"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("user:") + bo, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->close();

    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    // The first click after entering the section lands, while the
    // directory reloads: the reload neither rebuilds nor moves the rows.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    openRow(waitItem(QStringLiteral("role_member")));
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    // Assigned to is a tab with one table: the holder, its kind, and where
    // it holds; its commands join the role's own.
    QVERIFY(!shown(QStringLiteral("roleAddPeopleButton")));
    clickItem(waitItem(QStringLiteral("roleTab_holders")));
    QTRY_VERIFY(shown(QStringLiteral("roleAddPeopleButton")));
    QVERIFY(shown(QStringLiteral("roleCopyButton")));
    QTRY_VERIFY(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost")));
    QCOMPARE(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost"), "cells").toStringList(),
             (QStringList{QStringLiteral("bo@localhost"), QStringLiteral("Person"), QStringLiteral("Organization")}));
    QVERIFY(!rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost")));
    QVERIFY(!propertyOf(QStringLiteral("roleRemoveHoldersButton"), "usable").toBool());
    // Add people offers those without it; the checked ones get it.
    QTRY_VERIFY(propertyOf(QStringLiteral("roleAddPeopleButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("roleAddPeopleButton")));
    QTRY_VERIFY(shown(QStringLiteral("addPeoplePanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!shown(QStringLiteral("addHolder_user:") + bo));
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Add"));
    clickItem(waitItem(QStringLiteral("addHolder_user:") + cy));
    clickItem(waitItem(QStringLiteral("addHolder_group:") + legal));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("addPeoplePanel")));
    QTRY_VERIFY(rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost")));
    QTRY_VERIFY(rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("Legal")));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Role given."));
    QCOMPARE(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("Legal"), "cells").toStringList().value(1), QStringLiteral("Group"));
    // Remove asks for the rows selected, a Ctrl click adding one, then
    // takes the role back from them.
    clickItem(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost")));
    clickItem(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost")), Qt::LeftButton, Qt::ControlModifier);
    QTRY_VERIFY(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost"), "selected").toBool());
    QVERIFY(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost"), "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("roleOpenHolderButton"), "usable").toBool());
    QTRY_VERIFY(propertyOf(QStringLiteral("roleRemoveHoldersButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("roleRemoveHoldersButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeHoldersPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Take back Member from 2 holders?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("removeHoldersPanel")));
    QTRY_VERIFY(!rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost")));
    QTRY_VERIFY(!rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost")));
    QTRY_COMPARE(propertyOf(QStringLiteral("accessNotice"), "text").toString(), QStringLiteral("Role taken back."));
    // A group opens its page.
    openRow(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("Legal")));
    QTRY_VERIFY(shown(QStringLiteral("groupPage")));
    clickItem(waitItem(QStringLiteral("groupTab_roles")));
    QTRY_VERIFY(waitRow(QStringLiteral("heldRole_"), QStringLiteral("Member")));

    // A space role is given in a space picked after the people, and Open
    // opens the holder selected.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    openRow(waitItem(QStringLiteral("role_content_reader")));
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    clickItem(waitItem(QStringLiteral("roleTab_holders")));
    QTRY_VERIFY(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost")));
    QCOMPARE(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost"), "cells").toStringList().value(2),
             QStringLiteral("Contracts"));
    QTRY_VERIFY(propertyOf(QStringLiteral("roleAddPeopleButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("roleAddPeopleButton")));
    QTRY_VERIFY(shown(QStringLiteral("addPeoplePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Next"));
    clickItem(waitItem(QStringLiteral("addHolder_user:") + cy));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(shown(QStringLiteral("pickPlace_space:") + spaceId));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("pickPlace_space:") + spaceId));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("addPeoplePanel")));
    QTRY_VERIFY(rowTitled(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost")));
    QCOMPARE(rowProperty(QStringLiteral("roleHolder_"), QStringLiteral("cy@localhost"), "cells").toStringList().value(2),
             QStringLiteral("Contracts"));
    clickItem(waitRow(QStringLiteral("roleHolder_"), QStringLiteral("bo@localhost")));
    QTRY_VERIFY(propertyOf(QStringLiteral("roleOpenHolderButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("roleOpenHolderButton")));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QCOMPARE(propertyOf(QStringLiteral("userTitle"), "text").toString(), QStringLiteral("bo@localhost"));
}

// The tables shown in the window: each shows its column titles once.
static int tablesShown(QQuickItem *root)
{
    const QList<QQuickItem *> items = descendants(root);
    return int(std::count_if(items.begin(), items.end(), [](QQuickItem *item) {
        return item->objectName() == QLatin1String("tableHeader") && item->isVisible();
    }));
}

// Every detail page heads with the way back, the item's name, and one
// command bar, then its tabs: Details shows no table, every other tab one,
// and its commands join the bar only while it shows. At 920 px the command
// bar leaves the item's name whole.
void TestStudio::detailPagesShowOneTableAtATime()
{
    window()->resize(920, 900);
    openSpace(QStringLiteral("Quarterly contracts and supplier agreements"));
    addFolder(QStringLiteral("Plans"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}}}}});
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    directory->createGroup(QStringLiteral("Legal"));
    QTRY_COMPARE(directory->groups().size(), 1);
    QTRY_VERIFY(!directory->busy());
    directory->createTag(QStringLiteral("Secret"), true);
    QTRY_COMPARE(directory->tags().size(), 1);
    QTRY_VERIFY(!directory->busy());
    const QString legal = directory->groups().constFirst().toMap().value(QStringLiteral("id")).toString();
    const QString tag = directory->tags().constFirst().toMap().value(QStringLiteral("id")).toString();

    const auto check = [this](const QString &page, const QString &prefix) {
        QQuickItem *shownPage = waitItem(page);
        QTRY_VERIFY(shownPage->isVisible());
        QTRY_VERIFY(!propertyOf(prefix + QStringLiteral("Title"), "text").toString().isEmpty());
        QVERIFY2(!propertyOf(prefix + QStringLiteral("Title"), "truncated").toBool(), qPrintable(page));
        QList<QQuickItem *> tabs;
        for (QQuickItem *item : descendants(shownPage))
            if (item->objectName().startsWith(prefix + QStringLiteral("Tab_")))
                tabs.append(item);
        QVERIFY2(tabs.size() >= 2, qPrintable(page));
        QCOMPARE(tabs.constFirst()->objectName(), prefix + QStringLiteral("Tab_details"));
        for (QQuickItem *tab : std::as_const(tabs)) {
            clickItem(tab);
            QTRY_COMPARE(tab->property("current").toString(), tab->property("view").toString());
            settle();
            const int tables = tablesShown(window()->contentItem());
            QVERIFY2(tables == (tab == tabs.constFirst() ? 0 : 1), qPrintable(tab->objectName()));
            QVERIFY(shown(prefix + QStringLiteral("BackButton")));
        }
        clickItem(tabs.constFirst());
    };

    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    QCOMPARE(tablesShown(window()->contentItem()), 1);
    openRow(waitItem(QStringLiteral("member_") + bo));
    check(QStringLiteral("userPage"), QStringLiteral("user"));
    // A tab's commands show only on it; the person's own stay on every tab.
    QVERIFY(!shown(QStringLiteral("heldGrantAccessButton")));
    clickItem(waitItem(QStringLiteral("userTab_access")));
    QTRY_VERIFY(shown(QStringLiteral("heldGrantAccessButton")));
    QVERIFY(shown(QStringLiteral("userRemoveButton")));
    QVERIFY(!shown(QStringLiteral("heldRoleRemoveButton")));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_groups").arg(orgId)));
    openRow(waitItem(QStringLiteral("group_") + legal));
    check(QStringLiteral("groupPage"), QStringLiteral("group"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    openRow(waitItem(QStringLiteral("role_member")));
    check(QStringLiteral("rolePage"), QStringLiteral("role"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    openRow(waitItem(QStringLiteral("accessSpace_") + spaceId));
    check(QStringLiteral("spacePage"), QStringLiteral("space"));
    // Too narrow for the name and the bar on one line, the bar goes below.
    QQuickItem *title = waitItem(QStringLiteral("spaceTitle"));
    QVERIFY(waitItem(QStringLiteral("spaceRenameButton"))->mapToScene(QPointF()).y() > title->mapToScene(QPointF(0, title->height())).y());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_tags").arg(orgId)));
    openRow(waitItem(QStringLiteral("tag_") + tag));
    check(QStringLiteral("tagPage"), QStringLiteral("tag"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    check(QStringLiteral("addonDetail"), QStringLiteral("addon"));
    m_session->closeSettings();
    QTRY_VERIFY(!m_session->settingsActive());
    // A folder's access page, from the explorer.
    QMetaObject::invokeMethod(itemNamed(QStringLiteral("explorer")), "focusDefault");
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Plans")));
    key(Qt::Key_A);
    QTRY_VERIFY(shown(QStringLiteral("accessPage")));
    QTRY_VERIFY(!m_session->accessGrants()->busy());
    check(QStringLiteral("placePage"), QStringLiteral("place"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("accessPage")));
}

void TestStudio::addOnPageConfiguresSettings()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("settings_schema"), QJsonObject{
            {QStringLiteral("allow_author_approval"), QJsonObject{{QStringLiteral("type"), QStringLiteral("boolean")}, {QStringLiteral("default"), false}}},
            {QStringLiteral("required_approvals"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}, {QStringLiteral("default"), 1},
                {QStringLiteral("minimum"), 1}, {QStringLiteral("maximum"), 10}}}}},
        {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")},
            {QStringLiteral("revision"), 1},
            {QStringLiteral("settings"), QJsonObject{{QStringLiteral("allow_author_approval"), false},
                {QStringLiteral("required_approvals"), 1}}}}}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    QTRY_VERIFY(shown(QStringLiteral("addon_controlled_docs")));
    QCOMPARE(cell(QStringLiteral("addon_controlled_docs"), 1), QStringLiteral("Installed"));
    QVERIFY(!shown(QStringLiteral("addonDetail")));
    QVERIFY(!shown(QStringLiteral("installAddonButton")));
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
    QVERIFY(!shown(QStringLiteral("addon_controlled_docs")));
    QCOMPARE(propertyOf(QStringLiteral("addonTitle"), "text").toString(), QStringLiteral("Controlled documents"));
    QVERIFY(shown(QStringLiteral("pauseAddonButton")));
    QVERIFY(!shown(QStringLiteral("addonResponsibleButton")));
    // The organization settings read only on the page; Settings changes them in a panel.
    QTRY_COMPARE(propertyOf(QStringLiteral("addonSetting_required_approvals"), "text").toString(), QStringLiteral("1"));
    QCOMPARE(propertyOf(QStringLiteral("addonSetting_allow_author_approval"), "text").toString(), QStringLiteral("Off"));
    QVERIFY(!shown(QStringLiteral("addonSettingValue_organization_required_approvals")));
    clickItem(waitItem(QStringLiteral("addonSettingsButton")));
    QTRY_VERIFY(shown(QStringLiteral("addonSettingsPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(shown(QStringLiteral("addonSettingMode_organization_allow_author_approval")));
    QVERIFY(!shown(QStringLiteral("addonSettingMode_organization_required_approvals")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonSettingValue_organization_required_approvals"), "text").toString(), QStringLiteral("1"));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    // Out of the schema's bounds, the value cannot be saved.
    clicks(waitItem(QStringLiteral("addonSettingValue_organization_required_approvals")), QStringLiteral("0"));
    QTRY_VERIFY(propertyOf(QStringLiteral("addonSettingValue_organization_required_approvals"), "invalid").toBool());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    key(Qt::Key_Backspace);
    type(QStringLiteral("3"));
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("addonSettingsPanel")));
    QTRY_VERIFY(!m_session->addOns()->busy());
    const QJsonObject sent = m_core.addOnRequest().value(QStringLiteral("settings")).toObject();
    QCOMPARE(sent.value(QStringLiteral("required_approvals")).toInt(), 3);
    QVERIFY(!sent.contains(QStringLiteral("allow_author_approval")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonSetting_required_approvals"), "text").toString(), QStringLiteral("3"));
    QTRY_VERIFY(shown(QStringLiteral("addonNotice")));
    QTRY_VERIFY(waitItem(QStringLiteral("addonSettingsButton"))->hasActiveFocus());
    // Escape leaves the add-on for the list before it leaves Settings; the notice stays behind.
    key(Qt::Key_Escape);
    QTRY_VERIFY(shown(QStringLiteral("addon_controlled_docs")));
    QTRY_VERIFY(waitItem(QStringLiteral("addon_controlled_docs"))->hasActiveFocus());
    QVERIFY(!shown(QStringLiteral("addonNotice")));
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
    QVERIFY(!shown(QStringLiteral("addonNotice")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(shown(QStringLiteral("addon_controlled_docs")));
    QVERIFY(m_session->settingsActive());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());
}

// An installed add-on's roles list apart, open read-only, and are given
// only on places; one held across the organization shows as doing nothing
// there, and is removed.
void TestStudio::addOnRolesAreReadOnly()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    const QString membershipId = m_core.seedMember(orgId, QStringLiteral("bob@example.com"), QStringLiteral("member"));
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")},
            {QStringLiteral("revision"), 1}}}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    QTRY_VERIFY(shown(QStringLiteral("role_addon.controlled_docs.manager")));
    QVERIFY(shown(QStringLiteral("role_addon.controlled_docs.reviewer")));
    QVERIFY(shown(QStringLiteral("role_content_reader")));
    // The add-on's roles work only granted on a place: across the
    // organization, only the five built-in organization roles are given.
    QTRY_COMPARE(m_session->accessDirectory()->assignableRoles().size(), 5);
    // The space roles run past the window: the keyboard reaches the add-on's.
    focusOn(waitItem(QStringLiteral("role_addon.controlled_docs.manager")));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    QCOMPARE(propertyOf(QStringLiteral("roleKind"), "text").toString(), QStringLiteral("Add-on"));
    QVERIFY(!propertyOf(QStringLiteral("roleEditButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("roleArchiveButton"), "usable").toBool());
    // Add people gives it in a place, picked after the people.
    clickItem(waitItem(QStringLiteral("roleTab_holders")));
    QTRY_VERIFY(propertyOf(QStringLiteral("roleAddPeopleButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("roleAddPeopleButton")));
    QTRY_VERIFY(shown(QStringLiteral("addPeoplePanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Next"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("addPeoplePanel")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("rolePage")));
    QTRY_VERIFY(!m_session->accessDirectory()->busy());
    // Given across the organization anyway, as Core still lists it, it
    // shows on the person's page as doing nothing there, and is removed.
    auto *held = m_session->principalAccess();
    held->open(QStringLiteral("user:") + membershipId);
    QTRY_VERIFY(!held->busy());
    held->setRoles({QStringLiteral("role-member"), QStringLiteral("role-addon.controlled_docs.manager")});
    QTRY_COMPARE(held->roles().size(), 2);
    held->close();
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    openRow(waitItem(QStringLiteral("member_") + membershipId));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    clickItem(waitItem(QStringLiteral("userTab_roles")));
    QTRY_VERIFY(waitRow(QStringLiteral("heldRole_"), QStringLiteral("Controlled documents manager")));
    QCOMPARE(rowProperty(QStringLiteral("heldRole_"), QStringLiteral("Controlled documents manager"), "cells").toStringList(),
             (QStringList{QStringLiteral("Controlled documents manager"), QStringLiteral("Organization · no effect there")}));
    // Manage roles does not offer it, and keeps it while it is held.
    clickItem(waitItem(QStringLiteral("userManageRolesButton")));
    QTRY_VERIFY(shown(QStringLiteral("rolesPanel")));
    QVERIFY(!shown(QStringLiteral("manageRole_role-addon.controlled_docs.manager")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("rolesPanel")));
    QQuickItem *idle = waitFound([&] { return rowWith(QStringLiteral("heldRole_"), 0, QStringLiteral("Controlled documents manager")); });
    QVERIFY(idle);
    clickItem(idle);
    QTRY_VERIFY(propertyOf(QStringLiteral("heldRoleRemoveButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("heldRoleRemoveButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeHeldPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("confirmDetail"), "text").toString(),
             QStringLiteral("Controlled documents manager · Organization · no effect there"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("removeHeldPanel")));
    QTRY_VERIFY(!rowWith(QStringLiteral("heldRole_"), 0, QStringLiteral("Controlled documents manager")));
    QTRY_VERIFY(rowWith(QStringLiteral("heldRole_"), 0, QStringLiteral("Member")));
}

// A required list setting holds the install until it has an entry; entries
// are added with Enter, repeat case-insensitively nowhere, and are removed.
// Installed, the classifier turns on per space from its page, answers for
// the member chosen in its advanced panel, and uninstalls without a reason.
void TestStudio::classifierInstallsAndTurnsOnPerSpace()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    const QString quality = m_core.seedSpace(orgId, QStringLiteral("Quality"));
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    openRow(waitItem(QStringLiteral("addon_classifier")));
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
    // Installing asks only its settings, in its panel.
    QTRY_VERIFY(propertyOf(QStringLiteral("installAddonButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("installAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("addonSettingsPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(shown(QStringLiteral("addonSettingsMissing")));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSave"), "text").toString(), QStringLiteral("Install"));
    clicks(waitItem(QStringLiteral("addonSettingValue_organization_labels")), QStringLiteral("Contract"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("addonSettingRemove_organization_labels_0")));
    QVERIFY(!shown(QStringLiteral("addonSettingsMissing")));
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    // A repeat in another case is refused and adds nothing.
    type(QStringLiteral("contract"));
    QTRY_VERIFY(propertyOf(QStringLiteral("addonSettingValue_organization_labels"), "invalid").toBool());
    QVERIFY(!propertyOf(QStringLiteral("addonSettingAdd_organization_labels"), "usable").toBool());
    key(Qt::Key_Return);
    QVERIFY(!shown(QStringLiteral("addonSettingRemove_organization_labels_1")));
    for (int i = 0; i < 8; ++i) key(Qt::Key_Backspace);
    type(QStringLiteral("Invoice"));
    clickItem(waitItem(QStringLiteral("addonSettingAdd_organization_labels")));
    QTRY_VERIFY(shown(QStringLiteral("addonSettingRemove_organization_labels_1")));
    clickItem(waitItem(QStringLiteral("addonSettingRemove_organization_labels_0")));
    QTRY_VERIFY(!shown(QStringLiteral("addonSettingRemove_organization_labels_1")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("addonSettingsPanel")));
    QTRY_VERIFY(!m_session->addOns()->busy());
    const QJsonObject sent = m_core.addOnRequest().value(QStringLiteral("settings")).toObject();
    QCOMPARE(sent.value(QStringLiteral("labels")).toArray(), (QJsonArray{QStringLiteral("Invoice")}));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Installed"));

    // Installed, it is active in no space; its Spaces tab turns it on in
    // one through the same panel a space's page opens.
    clickItem(waitItem(QStringLiteral("addonTab_spaces")));
    QTRY_VERIFY(shown(QStringLiteral("addonSpace_") + quality));
    QCOMPARE(cell(QStringLiteral("addonSpace_") + quality, 1), QStringLiteral("Inactive"));
    QCOMPARE(propertyOf(QStringLiteral("addonSpaces"), "text").toString(), QStringLiteral("Active in 0 spaces"));
    openRow(waitItem(QStringLiteral("addonSpace_") + quality));
    QTRY_VERIFY(shown(QStringLiteral("activationPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelSubtitle"), "text").toString(), QStringLiteral("Quality"));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("activationSwitch")));
    QTRY_VERIFY(shown(QStringLiteral("addonSettingMode_space_rerun_on_new_version")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("activationPanel")));
    QTRY_COMPARE(cell(QStringLiteral("addonSpace_") + quality, 1), QStringLiteral("Active"));
    QCOMPARE(propertyOf(QStringLiteral("addonSpaces"), "text").toString(), QStringLiteral("Active in 1 space"));
    QTRY_VERIFY(shown(QStringLiteral("activationNotice")));

    // It calls Core itself: the member it answers for is an advanced panel.
    QTRY_VERIFY(shown(QStringLiteral("addonResponsibleButton")));
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("admin"));
    m_session->addOns()->refresh();
    QTRY_VERIFY(!m_session->addOns()->busy());
    clickItem(waitItem(QStringLiteral("addonResponsibleButton")));
    QTRY_VERIFY(shown(QStringLiteral("responsiblePanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("responsible_") + bo));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("responsiblePanel")));
    QCOMPARE(m_core.addOnRequest(), (QJsonObject{{QStringLiteral("responsible_membership_id"), bo}}));

    // Uninstalling says what it stops; it needs no reason.
    clickItem(waitItem(QStringLiteral("uninstallAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("uninstallAddonPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!shown(QStringLiteral("confirmReason")));
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    const QString impact = propertyOf(QStringLiteral("confirmDetail"), "text").toString();
    QVERIFY2(impact.contains(QStringLiteral("It stops in 1 space where it is active.")) && !impact.contains(QStringLiteral("role")),
             qPrintable(impact));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("uninstallAddonPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Not installed"));
    QTRY_VERIFY(!shown(QStringLiteral("addonSpace_") + quality));
}

// Pausing and resuming keeps the settings the add-on was installed with.
void TestStudio::addOnResumeKeepsItsSettings()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")}, {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1},
            {QStringLiteral("settings"), QJsonObject{{QStringLiteral("required_approvals"), 2}}}}}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Installed"));
    clickItem(waitItem(QStringLiteral("pauseAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("pauseAddonPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    QVERIFY(propertyOf(QStringLiteral("confirmDetail"), "text").toString().contains(QStringLiteral("Nobody holds")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("pauseAddonPanel")));
    // Paused, Pause stays in place, dimmed, saying why.
    QTRY_VERIFY(!propertyOf(QStringLiteral("pauseAddonButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("pauseAddonButton"), "reason").toString(), QStringLiteral("It is not running."));
    QCOMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Paused"));
    QTRY_VERIFY(propertyOf(QStringLiteral("resumeAddonButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("resumeAddonButton")));
    QTRY_VERIFY(propertyOf(QStringLiteral("pauseAddonButton"), "usable").toBool());
    QCOMPARE(m_core.addOnRequest(), (QJsonObject{{QStringLiteral("settings"), QJsonObject{{QStringLiteral("required_approvals"), 2}}}}));
    QTRY_VERIFY(shown(QStringLiteral("addonNotice")));
}

// Installing asks only the add-on's settings, with one Install: it is then
// available in every space and active in none, the installer answering for
// it, and the page lists the roles it adds.
void TestStudio::addOnInstallsWithItsSettings()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("settings_schema"), QJsonObject{
            {QStringLiteral("required_approvals"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}, {QStringLiteral("default"), 1},
                {QStringLiteral("minimum"), 1}, {QStringLiteral("maximum"), 10}}}}},
        {QStringLiteral("skus"), QJsonArray{QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled-docs-poc")},
            {QStringLiteral("version"), 1}, {QStringLiteral("limits"), QJsonObject()}}}}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}}}});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
    QCOMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Not installed"));
    // What was bought waits behind Plan and usage.
    clickItem(waitItem(QStringLiteral("addonPlanButton")));
    QTRY_VERIFY(shown(QStringLiteral("planPanel")));
    QTRY_VERIFY(panelOpen());
    // Without a live subscription the quantity stays as bought.
    QVERIFY(!shown(QStringLiteral("addonQuantity")));
    QVERIFY(!shown(QStringLiteral("sidePanelSave")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("planPanel")));
    // Install opens a panel with only the settings: no space and no
    // responsible member to pick.
    QTRY_VERIFY(propertyOf(QStringLiteral("installAddonButton"), "usable").toBool());
    focusOn(waitItem(QStringLiteral("installAddonButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("addonSettingsPanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(shown(QStringLiteral("addonSettingValue_organization_required_approvals")));
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("addonSettingsPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Installed"));
    QCOMPARE(m_core.addOnRequest(), (QJsonObject{{QStringLiteral("settings"), QJsonObject()}}));
    QTRY_VERIFY(shown(QStringLiteral("addonNotice")));
    QCOMPARE(propertyOf(QStringLiteral("addonNotice"), "text").toString(),
             QStringLiteral("Installed. Turn it on in each space that uses it."));
    clickItem(waitItem(QStringLiteral("addonTab_roles")));
    QTRY_VERIFY(shown(QStringLiteral("addonRole_addon.controlled_docs.reviewer")));
    QVERIFY(shown(QStringLiteral("addonRole_addon.controlled_docs.approver")));
    QVERIFY(shown(QStringLiteral("addonRole_addon.controlled_docs.manager")));
    // It has actions of its own: no responsible member to choose.
    QVERIFY(!shown(QStringLiteral("addonResponsibleButton")));
}

// Manage with reviews says what is missing in place and leads to the fix:
// the owner, without the add-on's managing role in the space, grants it from
// the space's Grant access, that role ticked, and comes back able to manage.
// A member who cannot manage access there reads only why.
void TestStudio::refusalsLeadToTheFix()
{
    window()->resize(1200, 1400);
    openSpace(QStringLiteral("Quality"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    m_session->uploadUrls({scratchFile(QStringLiteral("plan.md"), "# Plan\n")});
    QTRY_VERIFY(!m_core.landed(QStringLiteral("plan.md")).isEmpty());
    QTRY_VERIFY(!m_session->uploadBusy());
    const QJsonObject product{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1}}}};
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")}, {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {product});
    m_core.seedActivation(spaceId, QStringLiteral("controlled_docs"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("ok@localhost"), QStringLiteral("content_contributor"));
    m_session->addOns()->refresh();
    QTRY_VERIFY(!m_session->addOns()->busy());
    m_session->runCommand(QStringLiteral("refresh"));
    QVERIFY(waitIdle());
    m_session->openEntry(QStringLiteral("document"), entryId(QStringLiteral("plan.md")));
    QTRY_VERIFY(m_session->documentView()->active());
    QTRY_VERIFY(shown(QStringLiteral("manage-documentButton")));
    QTRY_COMPARE(propertyOf(QStringLiteral("manage-documentButton"), "reason").toString(),
                 QStringLiteral("You need Controlled documents manager in this space."));
    QVERIFY(!propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QTRY_VERIFY(shown(QStringLiteral("manageFixButton")));
    QCOMPARE(propertyOf(QStringLiteral("manageFixButton"), "text").toString(), QStringLiteral("Grant access"));
    clickItem(waitItem(QStringLiteral("manageFixButton")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QTRY_VERIFY(shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(panelOpen());
    QString me;
    for (const auto &member : m_session->accessDirectory()->members())
        if (member.toMap().value(QStringLiteral("email")) == QLatin1String("ok@localhost")) me = member.toMap().value(QStringLiteral("id")).toString();
    QVERIFY(!me.isEmpty());
    clickItem(waitItem(QStringLiteral("grantPrincipal_user:") + me));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    // The narrowest role that holds it comes ticked.
    QTRY_VERIFY(shown(QStringLiteral("grantRole_role-addon.controlled_docs.manager")));
    QVERIFY(propertyOf(QStringLiteral("grantRole_role-addon.controlled_docs.manager"), "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("grantRole_role-addon.controlled_docs.approver"), "selected").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_user:") + me));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("spacePage")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());
    // Back on the document, it is managed at once.
    QTRY_VERIFY(m_session->documentView()->active());
    QTRY_VERIFY(propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QVERIFY(!shown(QStringLiteral("manageFixButton")));
    clickItem(waitItem(QStringLiteral("manage-documentButton")));
    QTRY_VERIFY(m_core.documentTitled(QStringLiteral("plan.md")).value(QStringLiteral("controlled_docs_enabled")).toBool());
    QTRY_COMPARE(propertyOf(QStringLiteral("manage-documentButton"), "reason").toString(), QStringLiteral("It is managed with reviews already."));
    QVERIFY(!propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QTRY_VERIFY(propertyOf(QStringLiteral("unmanage-documentButton"), "usable").toBool());
    m_session->documentView()->close();
    QTRY_VERIFY(!m_session->documentView()->active());

    // A member of another organization, who edits a space there, reads why
    // and is offered no fix.
    m_core.seedOrganization(QStringLiteral("Team"), QStringLiteral("member"));
    m_session->refreshOrganizations();
    QVERIFY(waitIdle());
    QString team;
    for (int at = 0; at < m_session->organizations()->rowCount(); ++at)
        if (m_session->organizations()->index(at).data(matome::OrgModel::NameRole) == QLatin1String("Team"))
            team = m_session->organizations()->index(at).data(matome::OrgModel::OrgIdRole).toString();
    QVERIFY(!team.isEmpty());
    const QString docs = m_core.seedSpace(team, QStringLiteral("Docs"));
    m_core.seedSpaceGrant(team, docs, QStringLiteral("ok@localhost"), QStringLiteral("content_contributor"));
    m_core.seedAddOns(team, {product});
    m_core.seedActivation(docs, QStringLiteral("controlled_docs"));
    m_core.seedDocument(docs, QStringLiteral("guide.md"), {}, QByteArray("# Guide\n"));
    m_session->navigate(QStringLiteral("org"), team);
    QVERIFY(waitIdle());
    m_session->navigate(QStringLiteral("space"), docs);
    QVERIFY(waitIdle());
    m_session->openEntry(QStringLiteral("document"), m_core.documentTitled(QStringLiteral("guide.md")).value(QStringLiteral("id")).toString());
    QTRY_VERIFY(m_session->documentView()->active());
    QTRY_VERIFY(shown(QStringLiteral("manage-documentButton")));
    QTRY_COMPARE(propertyOf(QStringLiteral("manage-documentButton"), "reason").toString(),
                 QStringLiteral("You need Controlled documents manager in this space, with Controlled documents active here."));
    QVERIFY(!propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QVERIFY(!shown(QStringLiteral("manageFixButton")));
}

// Settings follows what the organization's catalog lets the person do, not
// the built-in roles held directly: a member whose group holds a custom role
// that manages groups opens Groups there, and nothing else of the
// organization; its commands stay, those the role lacks saying why.
void TestStudio::settingsFollowsEffectiveActions()
{
    window()->resize(1200, 1100);
    signInAsOk();
    m_core.seedOrganization(QStringLiteral("Team"), QStringLiteral("member"));
    m_session->refreshOrganizations();
    QVERIFY(waitIdle());
    QString team;
    for (int at = 0; at < m_session->organizations()->rowCount(); ++at)
        if (m_session->organizations()->index(at).data(matome::OrgModel::NameRole) == QLatin1String("Team"))
            team = m_session->organizations()->index(at).data(matome::OrgModel::OrgIdRole).toString();
    QVERIFY(!team.isEmpty());
    m_core.seedGroupRole(team, QStringLiteral("Organizers"), {QStringLiteral("ok@localhost")}, QStringLiteral("Group organizer"),
                         {QStringLiteral("group.create"), QStringLiteral("group.update")});
    m_session->navigate(QStringLiteral("org"), team);
    QVERIFY(waitIdle());
    m_session->permissions()->reload();
    QTRY_VERIFY(m_session->permissions()->sections(team) == QStringList{QStringLiteral("groups")});
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(shown(QStringLiteral("settingsOrganization_%1_groups").arg(team)));
    QVERIFY(!shown(QStringLiteral("settingsOrganization_%1_members").arg(team)));
    QVERIFY(!shown(QStringLiteral("settingsOrganization_%1_roles").arg(team)));
    QVERIFY(!shown(QStringLiteral("settingsOrganization_%1_billing").arg(team)));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_groups").arg(team)));
    QTRY_COMPARE(propertyOf(QStringLiteral("settingsScreen"), "section").toString(), QStringLiteral("groups"));
    QTRY_VERIFY(waitRow(QStringLiteral("group_"), QStringLiteral("Organizers")));
    QTRY_VERIFY(propertyOf(QStringLiteral("accessCreateButton"), "usable").toBool());
    openRow(waitRow(QStringLiteral("group_"), QStringLiteral("Organizers")));
    QTRY_VERIFY(shown(QStringLiteral("groupArchiveButton")));
    // The role renames groups but does not archive them, nor change members.
    QTRY_VERIFY(propertyOf(QStringLiteral("groupRenameButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("groupArchiveButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("groupArchiveButton"), "reason").toString().isEmpty());
    QVERIFY(!propertyOf(QStringLiteral("groupManageMembersButton"), "usable").toBool());
    QVERIFY(!propertyOf(QStringLiteral("groupManageMembersButton"), "reason").toString().isEmpty());
}

// A space's page lists its add-ons; controlled documents turns on there in
// its activation panel, the space's review switch, with its space settings.
// A document there is managed once it is on, and Core's refusal is said
// otherwise. The add-on's page lists the space as active; pausing or
// uninstalling it says first who loses which of its roles and where it
// stops.
void TestStudio::spacePageRequiresReviews()
{
    window()->resize(1200, 1400);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    QVERIFY(createSpace(QStringLiteral("Quality")));
    // A created space reloads the add-ons; the seeds below land after that.
    QTRY_VERIFY(!m_session->addOns()->busy());
    const QString spaceId = m_session->currentSpaceId();
    m_core.seedSpace(orgId, QStringLiteral("Archive"));
    m_session->uploadUrls({scratchFile(QStringLiteral("plan.md"), "# Plan\n")});
    QTRY_VERIFY(!m_core.landed(QStringLiteral("plan.md")).isEmpty());
    QTRY_VERIFY(!m_session->uploadBusy());
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("settings_schema"), QJsonObject{
            {QStringLiteral("required_approvals"), QJsonObject{{QStringLiteral("type"), QStringLiteral("integer")}, {QStringLiteral("default"), 1},
                {QStringLiteral("minimum"), 1}, {QStringLiteral("maximum"), 10}}}}},
        {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1},
            {QStringLiteral("settings"), QJsonObject{{QStringLiteral("required_approvals"), 1}}}}}}});
    // Access is given like any other: the signed-in owner manages documents,
    // Bo reads and approves.
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("ok@localhost"), QStringLiteral("content_contributor"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("ok@localhost"), QStringLiteral("addon.controlled_docs.manager"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("bo@localhost"), QStringLiteral("content_reader"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("bo@localhost"), QStringLiteral("addon.controlled_docs.approver"));

    // Off in the space, Manage with reviews says so in place, and Activate
    // leads to the space's add-on, its switch at hand.
    m_session->addOns()->refresh();
    QTRY_VERIFY(!m_session->addOns()->busy());
    m_session->runCommand(QStringLiteral("refresh"));
    QVERIFY(waitIdle());
    m_session->openEntry(QStringLiteral("document"), entryId(QStringLiteral("plan.md")));
    QTRY_VERIFY(m_session->documentView()->active());
    QTRY_VERIFY(m_session->controlledDocs()->active());
    QTRY_VERIFY(!m_session->controlledDocs()->busy());
    QTRY_VERIFY(shown(QStringLiteral("manage-documentButton")));
    QTRY_COMPARE(propertyOf(QStringLiteral("manage-documentButton"), "reason").toString(),
                 QStringLiteral("Controlled documents is not active in this space."));
    QVERIFY(!propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QVERIFY(shown(QStringLiteral("unmanage-documentButton")));
    QCOMPARE(propertyOf(QStringLiteral("unmanage-documentButton"), "reason").toString(), QStringLiteral("It is not managed with reviews."));
    QTRY_VERIFY(shown(QStringLiteral("manageFixButton")));
    QCOMPARE(propertyOf(QStringLiteral("manageFixButton"), "text").toString(), QStringLiteral("Activate"));
    clickItem(waitItem(QStringLiteral("manageFixButton")));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    // The space lists every installed add-on that works per space.
    QTRY_VERIFY(shown(QStringLiteral("spaceAddOn_controlled_docs")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Inactive"));
    QTRY_VERIFY(shown(QStringLiteral("activationPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Controlled documents"));
    QVERIFY(!propertyOf(QStringLiteral("activationSwitch"), "selected").toBool());
    QVERIFY(!shown(QStringLiteral("addonSettingMode_space_required_approvals")));
    // The switch turns it on from the keyboard, its space settings with it.
    focusOn(waitItem(QStringLiteral("activationSwitch")));
    key(Qt::Key_Space);
    QTRY_VERIFY(propertyOf(QStringLiteral("activationSwitch"), "selected").toBool());
    QTRY_VERIFY(shown(QStringLiteral("addonSettingMode_space_required_approvals")));
    focusOn(waitItem(QStringLiteral("addonSettingMode_space_required_approvals")));
    key(Qt::Key_Down);
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("activationPanel")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Active"));
    QTRY_VERIFY(shown(QStringLiteral("activationNotice")));
    const auto activation = [this, spaceId] {
        for (const auto &row : m_session->addOnActivations()->rows())
            if (row.toMap().value(QStringLiteral("space_id")) == spaceId) return row.toMap();
        return QVariantMap();
    };
    QCOMPARE(activation().value(QStringLiteral("settings")).toMap().value(QStringLiteral("required_approvals")).toInt(), 1);
    // Turning it off keeps the settings.
    QTRY_VERIFY(!shown(QStringLiteral("activationPanel")));
    openRow(waitItem(QStringLiteral("spaceAddOn_controlled_docs")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("activationSwitch")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Inactive"));
    QCOMPARE(activation().value(QStringLiteral("settings")).toMap().value(QStringLiteral("required_approvals")).toInt(), 1);
    QTRY_VERIFY(!shown(QStringLiteral("activationPanel")));
    openRow(waitItem(QStringLiteral("spaceAddOn_controlled_docs")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("activationSwitch")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Active"));

    // On in the space, back on the document, Manage with reviews manages it
    // at once.
    key(Qt::Key_Escape);
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());
    QTRY_VERIFY(m_session->documentView()->active());
    QTRY_VERIFY(m_session->controlledDocs()->active());
    QTRY_VERIFY(!m_session->controlledDocs()->busy());
    QTRY_VERIFY(propertyOf(QStringLiteral("manage-documentButton"), "usable").toBool());
    QVERIFY(!shown(QStringLiteral("manageFixButton")));
    clickItem(waitItem(QStringLiteral("manage-documentButton")));
    QTRY_VERIFY2(m_session->controlledDocs()->notice() == QLatin1String("control_enabled"),
                 qPrintable(m_session->controlledDocs()->errorCode()));
    QTRY_VERIFY(m_core.documentTitled(QStringLiteral("plan.md")).value(QStringLiteral("controlled_docs_enabled")).toBool());
    m_session->documentView()->close();
    QTRY_VERIFY(!m_session->documentView()->active());
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());

    // The add-on's page lists the space as active; uninstalling says who
    // loses what and asks a reason.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    QTRY_COMPARE(cell(QStringLiteral("addon_controlled_docs"), 2), QStringLiteral("Active in 1 space"));
    QCOMPARE(cell(QStringLiteral("addon_controlled_docs"), 1), QStringLiteral("Installed"));
    openRow(waitItem(QStringLiteral("addon_controlled_docs")));
    clickItem(waitItem(QStringLiteral("addonTab_spaces")));
    QTRY_VERIFY(shown(QStringLiteral("addonSpace_") + spaceId));
    QCOMPARE(cell(QStringLiteral("addonSpace_") + spaceId, 1), QStringLiteral("Active"));
    QTRY_VERIFY(shown(QStringLiteral("uninstallAddonButton")));
    clickItem(waitItem(QStringLiteral("uninstallAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("uninstallAddonPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(m_session->addOnAccess()->impact().value(QStringLiteral("known")).toBool());
    const QString detail = propertyOf(QStringLiteral("confirmDetail"), "text").toString();
    QVERIFY2(detail.contains(QStringLiteral("Controlled documents approver: 1 · Controlled documents manager: 1")), qPrintable(detail));
    QVERIFY(detail.contains(QStringLiteral("It stops in 1 space where it is active.")));
    QVERIFY(detail.contains(QStringLiteral("managed with reviews again")));
    QCOMPARE(m_session->addOnAccess()->impact().value(QStringLiteral("holders")).toInt(), 2);
    QCOMPARE(m_session->addOnAccess()->impact().value(QStringLiteral("spaces")).toInt(), 1);
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("uninstallAddonPanel")));
    // Pausing states its own impact, then pauses.
    clickItem(waitItem(QStringLiteral("pauseAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("pauseAddonPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    QVERIFY(propertyOf(QStringLiteral("confirmDetail"), "text").toString().contains(QStringLiteral("Open reviews wait")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_COMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Paused"));
    QTRY_COMPARE(cell(QStringLiteral("addonSpace_") + spaceId, 1), QStringLiteral("Paused in the organization"));
    QTRY_VERIFY(!shown(QStringLiteral("pauseAddonPanel")));
    // Uninstalled, it reads as not installed and installs again.
    // Core keeps the grants of its roles for a reinstall but lists them no
    // more: Bo views the space, and the space no longer lists the add-on.
    QTRY_VERIFY(propertyOf(QStringLiteral("uninstallAddonButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("uninstallAddonButton")));
    QTRY_VERIFY(shown(QStringLiteral("uninstallAddonPanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(m_session->addOnAccess()->impact().value(QStringLiteral("known")).toBool());
    QTRY_VERIFY(waitItem(QStringLiteral("confirmReason"))->hasActiveFocus());
    type(QStringLiteral("Audit over"));
    key(Qt::Key_Return);
    QTRY_COMPARE(m_session->addOns()->notice(), QStringLiteral("installation_removed"));
    QTRY_VERIFY(!shown(QStringLiteral("uninstallAddonPanel")));
    QTRY_VERIFY(shown(QStringLiteral("addonNotice")));
    QTRY_VERIFY(!m_session->addOns()->busy());
    QCOMPARE(propertyOf(QStringLiteral("addonStatus"), "text").toString(), QStringLiteral("Not installed"));
    // Not installed, the commands stay, only Install usable.
    QVERIFY(!propertyOf(QStringLiteral("resumeAddonButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("uninstallAddonButton"), "reason").toString(), QStringLiteral("It is not installed."));
    QTRY_VERIFY(propertyOf(QStringLiteral("installAddonButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("addonBackButton")));
    QTRY_COMPARE(cell(QStringLiteral("addon_controlled_docs"), 1), QStringLiteral("Not installed"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    focusOn(waitItem(QStringLiteral("accessSpace_") + spaceId));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QTRY_VERIFY(!m_session->accessGrants()->busy());
    clickItem(waitItem(QStringLiteral("spaceTab_addons")));
    QTRY_VERIFY(shown(QStringLiteral("spaceAddOn_empty")));
    QVERIFY(!shown(QStringLiteral("spaceAddOn_controlled_docs")));
    for (const auto &holder : m_session->accessGrants()->holders()) {
        const auto row = holder.toMap();
        QVERIFY(row.value(QStringLiteral("archived")).toStringList().isEmpty());
        if (row.value(QStringLiteral("principal")) == QStringLiteral("user:") + bo)
            QCOMPARE(row.value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("role-content_reader")});
    }
}

// A space's Access tab selects many rows from the keyboard and removes them
// at once; its Add-ons tab flags an active add-on whose roles nobody holds
// there until access gives them, and opens the add-on. Commands that do not
// apply stay, unusable, saying why.
void TestStudio::spaceTablesSelectManyAndFlagAddOns()
{
    window()->resize(1200, 1400);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    QVERIFY(createSpace(QStringLiteral("Quality")));
    QTRY_VERIFY(!m_session->addOns()->busy());
    const QString spaceId = m_session->currentSpaceId();
    const QString bo = m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    const QString cy = m_core.seedMember(orgId, QStringLiteral("cy@localhost"), QStringLiteral("member"));
    m_core.seedCatalogProduct({{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("name"), QStringLiteral("Controlled documents")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("settings_schema"), QJsonObject()}, {QStringLiteral("skus"), QJsonArray()}});
    m_core.seedAddOns(orgId, {QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("revision"), 1},
            {QStringLiteral("settings"), QJsonObject()}}}}});
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("bo@localhost"), QStringLiteral("content_reader"));
    m_core.seedSpaceGrant(orgId, spaceId, QStringLiteral("cy@localhost"), QStringLiteral("content_reader"));
    m_session->addOns()->refresh();
    QTRY_VERIFY(!m_session->addOns()->busy());
    m_session->addOnActivations()->open();
    QTRY_VERIFY(!m_session->addOnActivations()->busy());
    m_session->addOnActivations()->activate(spaceId, QStringLiteral("controlled_docs"));
    QTRY_COMPARE(m_session->addOnActivations()->notice(), QStringLiteral("activated"));

    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    QVERIFY(waitIdle());
    QTRY_VERIFY(!m_session->addOnActivations()->busy());
    openRow(waitItem(QStringLiteral("accessSpace_") + spaceId));
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QTRY_VERIFY(!m_session->accessGrants()->busy());
    clickItem(waitItem(QStringLiteral("spaceTab_access")));
    // Shift+Down reaches the next row; Remove asks for both.
    const QString first = QStringLiteral("accessHolder_user:") + bo, second = QStringLiteral("accessHolder_user:") + cy;
    QTRY_VERIFY(shown(first));
    QTRY_VERIFY(shown(second));
    QVERIFY(!propertyOf(QStringLiteral("removeAccessButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("removeAccessButton"), "reason").toString(), QStringLiteral("Select what to remove."));
    clickItem(waitItem(first));
    key(Qt::Key_Down, Qt::ShiftModifier);
    QTRY_VERIFY(propertyOf(second, "selected").toBool());
    QVERIFY(propertyOf(first, "selected").toBool());
    QVERIFY(!propertyOf(QStringLiteral("manageAccessRolesButton"), "usable").toBool());
    // A plain arrow keeps one row; Ctrl+A takes them all, Ctrl+Space drops one.
    key(Qt::Key_Up);
    QTRY_VERIFY(!propertyOf(second, "selected").toBool());
    key(Qt::Key_A, Qt::ControlModifier);
    QTRY_VERIFY(propertyOf(second, "selected").toBool());
    key(Qt::Key_Space, Qt::ControlModifier);
    QTRY_VERIFY(!propertyOf(first, "selected").toBool());
    key(Qt::Key_Space, Qt::ControlModifier);
    QTRY_VERIFY(propertyOf(first, "selected").toBool());
    QTRY_VERIFY(propertyOf(QStringLiteral("removeAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("removeAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeAccessPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Remove access for 2 holders?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("removeAccessPanel")));
    QTRY_VERIFY(m_session->accessGrants()->holders().isEmpty());

    // Active with nobody holding its roles here, the add-on is flagged; its
    // commands wait for a row.
    clickItem(waitItem(QStringLiteral("spaceTab_addons")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Active · nobody holds its roles here"));
    QVERIFY(!shown(QStringLiteral("grantAccessButton")));
    QVERIFY(!propertyOf(QStringLiteral("spaceOpenAddOnButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("spaceOpenAddOnButton"), "reason").toString(), QStringLiteral("Select an add-on."));
    clickItem(waitItem(QStringLiteral("spaceAddOn_controlled_docs")));
    QTRY_VERIFY(propertyOf(QStringLiteral("spaceOpenAddOnButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("spaceActivationButton"), "text").toString(), QStringLiteral("Settings"));
    // Granting one of its roles here clears the flag.
    clickItem(waitItem(QStringLiteral("spaceTab_access")));
    clickItem(waitItem(QStringLiteral("grantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(panelOpen());
    clickItem(waitItem(QStringLiteral("grantPrincipal_user:") + bo));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    clickItem(waitItem(QStringLiteral("grantRole_role-addon.controlled_docs.manager")));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    clickItem(waitItem(QStringLiteral("spaceTab_addons")));
    QTRY_COMPARE(cell(QStringLiteral("spaceAddOn_controlled_docs"), 1), QStringLiteral("Active"));
    // Open goes to its page under Add-ons.
    clickItem(waitItem(QStringLiteral("spaceAddOn_controlled_docs")));
    QTRY_VERIFY(propertyOf(QStringLiteral("spaceOpenAddOnButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("spaceOpenAddOnButton")));
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
    QCOMPARE(propertyOf(QStringLiteral("addonTitle"), "text").toString(), QStringLiteral("Controlled documents"));
}

// Invite opens the side panel with focus in the email. A refused invitation
// keeps the panel and its input, with the reason inside; a sent one closes
// it. An invitation offers roles in the spaces checked. Selecting an
// invitation opens it, and cancelling it asks in the panel. People reloads
// on entry.
void TestStudio::inviteRefusalStaysInThePanel()
{
    window()->resize(1200, 1100);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    QVERIFY(createSpace(QStringLiteral("Contracts")));
    const QString spaceId = m_session->currentSpaceId();
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(propertyOf(QStringLiteral("sendInvitationButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sendInvitationButton")));
    QTRY_VERIFY(shown(QStringLiteral("invitePanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("invitationEmailField"))->hasActiveFocus());
    type(QStringLiteral("bob"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("inviteError")));
    QVERIFY(shown(QStringLiteral("invitePanel")));
    QCOMPARE(propertyOf(QStringLiteral("invitationEmailField"), "text").toString(), QStringLiteral("bob"));
    // The refusal shows once, in the panel, and goes once the address changes.
    QVERIFY(!shown(QStringLiteral("orgAdminError")));
    type(QStringLiteral("@"));
    QVERIFY(!shown(QStringLiteral("inviteError")));
    QVERIFY(!shown(QStringLiteral("orgAdminError")));
    type(QStringLiteral("example.com"));
    key(Qt::Key_Return);
    QTRY_VERIFY(!shown(QStringLiteral("invitePanel")));
    QTRY_VERIFY(waitItem(QStringLiteral("sendInvitationButton"))->hasActiveFocus());
    QTRY_VERIFY(propertyOf(QStringLiteral("sendInvitationButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sendInvitationButton")));
    QTRY_VERIFY(shown(QStringLiteral("invitePanel")));
    QTRY_VERIFY(panelOpen());
    QVERIFY(!shown(QStringLiteral("inviteError")));
    QTRY_VERIFY(waitItem(QStringLiteral("invitationEmailField"))->hasActiveFocus());
    type(QStringLiteral("bob@example.com"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("inviteError")));
    QCOMPARE(m_session->orgAdmin()->errorCode(), QStringLiteral("already_invited"));
    QCOMPARE(propertyOf(QStringLiteral("invitationEmailField"), "text").toString(), QStringLiteral("bob@example.com"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("invitePanel")));
    // People lists members, and on its other tab the invitations sent: one
    // table at a time.
    QTRY_VERIFY(shown(QStringLiteral("memberList")));
    QVERIFY(!shown(QStringLiteral("invitationList")));
    clickItem(waitItem(QStringLiteral("peopleTab_invitations")));
    QTRY_VERIFY(shown(QStringLiteral("invitationList")));
    QVERIFY(!shown(QStringLiteral("memberList")));
    clickItem(waitItem(QStringLiteral("peopleTab_members")));
    QTRY_VERIFY(shown(QStringLiteral("memberList")));
    QTRY_VERIFY(propertyOf(QStringLiteral("memberList"), "count").toInt() > 0);
    const int members = propertyOf(QStringLiteral("memberList"), "count").toInt();
    // Someone joins elsewhere: entering People again lists them.
    m_core.seedMember(orgId, QStringLiteral("carol@example.com"), QStringLiteral("member"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_groups").arg(orgId)));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_COMPARE(propertyOf(QStringLiteral("memberList"), "count").toInt(), members + 1);
    // An invitation offers the roles checked in each space checked, named on its row.
    QTRY_VERIFY(propertyOf(QStringLiteral("sendInvitationButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sendInvitationButton")));
    QTRY_VERIFY(shown(QStringLiteral("invitePanel")));
    QTRY_VERIFY(panelOpen());
    QTRY_VERIFY(waitItem(QStringLiteral("invitationEmailField"))->hasActiveFocus());
    type(QStringLiteral("dee@example.com"));
    const QString space = QStringLiteral("inviteSpace_") + spaceId;
    QTRY_VERIFY(shown(space));
    QVERIFY(!shown(QStringLiteral("inviteRole_%1_role-content_reader").arg(spaceId)));
    clickItem(waitItem(space));
    QTRY_VERIFY(shown(QStringLiteral("inviteRole_%1_role-content_reader").arg(spaceId)));
    QVERIFY(!propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    // Each role is checked from the keyboard, wherever the panel scrolled.
    focusOn(waitItem(QStringLiteral("inviteRole_%1_role-content_reader").arg(spaceId)));
    key(Qt::Key_Space);
    focusOn(waitItem(QStringLiteral("inviteRole_%1_role-content_contributor").arg(spaceId)));
    key(Qt::Key_Space);
    QTRY_VERIFY(propertyOf(QStringLiteral("sidePanelSave"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("invitePanel")));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    auto *invitations = m_session->orgAdmin()->invitations();
    QString dee;
    for (int row = 0; row < invitations->rowCount(); ++row)
        if (invitations->index(row).data(matome::OrgPeopleModel::LabelRole) == QLatin1String("dee@example.com"))
            dee = invitations->index(row).data(matome::OrgPeopleModel::PersonIdRole).toString();
    QVERIFY(!dee.isEmpty());
    clickItem(waitItem(QStringLiteral("peopleTab_invitations")));
    QTRY_COMPARE(cell(QStringLiteral("invitation_") + dee, 3), QStringLiteral("Access to Contracts"));
    // The invitation opens its page, naming the roles it gives in each
    // space; cancelling it asks in a panel first.
    openRow(waitItem(QStringLiteral("invitation_") + dee));
    QTRY_VERIFY(shown(QStringLiteral("invitationPage")));
    QVERIFY(!panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("invitationRoles"), "text").toString(), QStringLiteral("Member"));
    QCOMPARE(propertyOf(QStringLiteral("invitationState"), "text").toString(), QStringLiteral("Pending"));
    clickItem(waitItem(QStringLiteral("invitationTab_spaces")));
    QTRY_COMPARE(cell(QStringLiteral("invitationSpace_") + spaceId, 1), QStringLiteral("Content reader, Content contributor"));
    clickItem(waitItem(QStringLiteral("cancelInvitationButton")));
    QTRY_VERIFY(shown(QStringLiteral("cancelInvitationPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Cancel invitation for dee@example.com?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("cancelInvitationPanel")));
    QTRY_COMPARE(propertyOf(QStringLiteral("invitationState"), "text").toString(), QStringLiteral("Canceled"));
    QVERIFY(!propertyOf(QStringLiteral("cancelInvitationButton"), "usable").toBool());
    QCOMPARE(propertyOf(QStringLiteral("cancelInvitationButton"), "reason").toString(), QStringLiteral("It is no longer pending."));
    clickItem(waitItem(QStringLiteral("invitationBackButton")));
    QTRY_VERIFY(!shown(QStringLiteral("invitationPage")));
    QTRY_VERIFY(cell(QStringLiteral("invitation_") + dee, 2).contains(QStringLiteral("Canceled")));
}

// A token is made from picked actions and shown once; a sign-in Core finds
// too old asks for the password, and a token is revoked after confirming.
void TestStudio::apiTokensCreateAndRevoke()
{
    // The organization's actions are many; the form stands whole in the window.
    window()->resize(1200, 2400);
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    clickItem(waitItem(QStringLiteral("accountButton")));
    QTRY_VERIFY(menuOpen());
    clickItem(waitItem(QStringLiteral("menu_settings")));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsTokensNavigation")));
    QTRY_VERIFY(shown(QStringLiteral("apiTokenList")));
    QTRY_VERIFY(propertyOf(QStringLiteral("newApiTokenButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("newApiTokenButton")));
    QTRY_VERIFY(shown(QStringLiteral("apiTokenForm")));
    QVERIFY(!shown(QStringLiteral("apiTokenPasswordField")));
    clicks(waitItem(QStringLiteral("apiTokenNameField")), QStringLiteral("Laptop"));
    // Across the organization, space-only actions are not offered.
    QTRY_VERIFY(shown(QStringLiteral("apiTokenAction_role.read")));
    QVERIFY(!shown(QStringLiteral("apiTokenAction_content.download")));
    QVERIFY(!propertyOf(QStringLiteral("createApiTokenButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("apiTokenAction_role.read")));
    clickItem(waitItem(QStringLiteral("addApiTokenAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("removeApiTokenAccess_0")));
    // Core finds the sign-in too old: the password signs in again and the token is made.
    m_core.expireSignIn();
    clickItem(waitItem(QStringLiteral("createApiTokenButton")));
    QTRY_VERIFY(shown(QStringLiteral("apiTokenPasswordField")));
    QVERIFY(shown(QStringLiteral("apiTokensError")));
    clicks(waitItem(QStringLiteral("apiTokenPasswordField")), QStringLiteral("secret12"));
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("apiTokenSecret")));
    QCOMPARE(propertyOf(QStringLiteral("apiTokenSecretField"), "text").toString(), QStringLiteral("mat_secret1"));
    const QJsonObject sent = m_core.tokenRequest();
    QCOMPARE(sent.value(QStringLiteral("name")).toString(), QStringLiteral("Laptop"));
    QCOMPARE(sent.value(QStringLiteral("scopes")).toArray(), (QJsonArray{QJsonObject{
        {QStringLiteral("organization_id"), orgId}, {QStringLiteral("action"), QStringLiteral("role.read")}}}));
    QVERIFY(QDateTime::fromString(sent.value(QStringLiteral("expires_at")).toString(), Qt::ISODate)
            > QDateTime::currentDateTimeUtc().addDays(29));
    clickItem(waitItem(QStringLiteral("doneApiTokenButton")));
    QTRY_VERIFY(shown(QStringLiteral("apiToken_1")));
    QVERIFY(m_session->apiTokens()->secret().isEmpty());
    clickItem(waitItem(QStringLiteral("revokeApiToken_1")));
    QTRY_VERIFY(shown(QStringLiteral("revokeApiTokenPanel")));
    QTRY_VERIFY(panelOpen());
    QCOMPARE(propertyOf(QStringLiteral("sidePanelTitle"), "text").toString(), QStringLiteral("Revoke Laptop?"));
    clickItem(waitItem(QStringLiteral("sidePanelSave")));
    QTRY_VERIFY(!shown(QStringLiteral("apiToken_1")));
    QTRY_VERIFY(!shown(QStringLiteral("revokeApiTokenPanel")));
    QCOMPARE(m_core.lastPath(), QStringLiteral("/api/auth/tokens"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!m_session->settingsActive());
    QVERIFY(!m_session->apiTokens()->active());
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
                 QStringLiteral("E-mail, nome de usuário ou senha incorretos."));
    m_theme->setLanguage(QStringLiteral("en"));
    QCOMPARE(propertyOf(QStringLiteral("statusMessage"), "text").toString(),
             QStringLiteral("That email, username, or password is wrong."));

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
    QVERIFY(waitItem(QStringLiteral("menu_lang-pt-BR")));
    for (int i = 0; i < 20 && focusName() != QLatin1String("menu_lang-pt-BR"); ++i)
        key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("menu_lang-pt-BR"));
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
        QCOMPARE(session->identifier(), QStringLiteral("ok@localhost"));
        QCOMPARE(session->apiBaseUrl(), m_core.url());
        QCOMPARE(session->lastOrgId(), org);
        QCOMPARE(itemNamed(QStringLiteral("emailField"), relaunched)->property("text").toString(),
                 QStringLiteral("ok@localhost"));
        QCOMPARE(itemNamed(QStringLiteral("submitButton"), relaunched)->property("text").toString(),
                 QStringLiteral("サインイン"));
        session->signIn(session->identifier(), QStringLiteral("secret12"), session->apiBaseUrl());
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
    const QString inbox = m_session->currentSpaceId();
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
    key(Qt::Key_A);
    QTRY_VERIFY(shown(QStringLiteral("accessPage")));
    QTRY_VERIFY(!m_session->accessGrants()->busy());
    audit(QStringLiteral("access page"));
    QTRY_VERIFY(propertyOf(QStringLiteral("grantAccessButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("grantAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("grantPanel")));
    QTRY_VERIFY(panelOpen());
    audit(QStringLiteral("access"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("grantPanel")));
    clickItem(waitItem(QStringLiteral("checkAccessButton")));
    QTRY_VERIFY(shown(QStringLiteral("checkAccessPanel")));
    QTRY_VERIFY(panelOpen());
    audit(QStringLiteral("check access"));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("checkAccessPanel")));
    key(Qt::Key_Escape);
    QTRY_VERIFY(!shown(QStringLiteral("accessPage")));
    QTRY_VERIFY(rowFocused(QStringLiteral("entryRow"), QStringLiteral("Contracts")));
    key(Qt::Key_Delete);
    QTRY_VERIFY(shown(QStringLiteral("deleteFolderPanel")));
    QTRY_VERIFY(panelOpen());
    audit(QStringLiteral("delete folder"));
    key(Qt::Key_Escape);
    // People, a person's page and a panel of it, and a role's page.
    const QString orgId = m_session->currentOrgId();
    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_members").arg(orgId)));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    QTRY_VERIFY(rowTitled(QStringLiteral("member_"), QStringLiteral("ok@localhost")));
    audit(QStringLiteral("people"));
    openRow(waitRow(QStringLiteral("member_"), QStringLiteral("ok@localhost")));
    QTRY_VERIFY(shown(QStringLiteral("userPage")));
    QTRY_VERIFY(!m_session->principalAccess()->busy());
    audit(QStringLiteral("user"));
    QTRY_VERIFY(propertyOf(QStringLiteral("userManageRolesButton"), "usable").toBool());
    clickItem(waitItem(QStringLiteral("userManageRolesButton")));
    QTRY_VERIFY(panelOpen());
    audit(QStringLiteral("roles panel"));
    key(Qt::Key_Escape);
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_roles").arg(orgId)));
    audit(QStringLiteral("roles"));
    openRow(waitItem(QStringLiteral("role_owner")));
    QTRY_VERIFY(shown(QStringLiteral("rolePage")));
    QTRY_VERIFY(!m_session->roleHolders()->busy());
    audit(QStringLiteral("role"));
    clickItem(waitItem(QStringLiteral("roleTab_holders")));
    QTRY_VERIFY(shown(QStringLiteral("roleAddPeopleButton")));
    audit(QStringLiteral("role holders"));
    // A space's page, and an add-on's.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    openRow(waitItem(QStringLiteral("accessSpace_") + inbox));
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    QTRY_VERIFY(!m_session->accessGrants()->busy());
    audit(QStringLiteral("space"));
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    audit(QStringLiteral("add-ons"));
    m_session->closeSettings();
    QTRY_VERIFY(!m_session->settingsActive());
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
    QTRY_COMPARE(focusName(), QStringLiteral("newSpaceName"));
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
    wheelOn(list);
    QTRY_VERIFY(list->property("contentY").toReal() > top);
    // Rows the flick is still building would be torn down by the next sign-out.
    QTRY_VERIFY(!list->property("moving").toBool());
    settle();
}

// Tab reaches the section past one stop on the navigation, its selected
// row; the arrows move between its rows, and Shift+Tab walks back out.
void TestStudio::settingsNavigationIsOneTabStop()
{
    signInAsOk();
    QVERIFY(openOwnOrg());
    const QString orgId = m_session->currentOrgId();
    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    QTRY_COMPARE(focusName(), QStringLiteral("closeSettingsButton"));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("refreshOrgAdminButton"));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("settingsAppearanceNavigation"));
    QVERIFY(ringShown(QStringLiteral("settingsAppearanceNavigation")));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("themePicker"));
    key(Qt::Key_Backtab);
    QCOMPARE(focusName(), QStringLiteral("settingsAppearanceNavigation"));
    key(Qt::Key_Backtab);
    QCOMPARE(focusName(), QStringLiteral("refreshOrgAdminButton"));
    key(Qt::Key_Tab);

    // Down walks the rows without choosing; Enter chooses; Tab goes on.
    key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("settingsTokensNavigation"));
    key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("settingsOrganization_") + orgId);
    key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("settingsOrganization_%1_general").arg(orgId));
    key(Qt::Key_Down);
    QCOMPARE(focusName(), QStringLiteral("settingsOrganization_%1_members").arg(orgId));
    QCOMPARE(itemNamed(QStringLiteral("settingsScreen"))->property("section").toString(), QStringLiteral("appearance"));
    key(Qt::Key_Return);
    QTRY_COMPARE(itemNamed(QStringLiteral("settingsScreen"))->property("section").toString(), QStringLiteral("members"));
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    QTRY_VERIFY(!m_session->organizations()->busy());
    QCOMPARE(focusName(), QStringLiteral("settingsOrganization_%1_members").arg(orgId));
    key(Qt::Key_Tab);
    QCOMPARE(focusName(), QStringLiteral("newUserButton"));
    // The stop is now the chosen row.
    key(Qt::Key_Backtab);
    QCOMPARE(focusName(), QStringLiteral("settingsOrganization_%1_members").arg(orgId));
    key(Qt::Key_Home);
    QCOMPARE(focusName(), QStringLiteral("settingsAppearanceNavigation"));
    key(Qt::Key_End);
    QCOMPARE(focusName(), QStringLiteral("settingsOpenOrganizations"));
}

// The wheel scrolls a space's page and the side panel beside it.
void TestStudio::wheelScrollsPagesAndPanels()
{
    openSpace(QStringLiteral("Contracts"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    QStringList people;
    for (int i = 1; i <= 12; ++i)
        people << QStringLiteral("user:") + m_core.seedMember(orgId, QStringLiteral("p%1@localhost").arg(i), QStringLiteral("member"));
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Contracts"));
    QTRY_VERIFY(!grants->busy());
    grants->add(people.mid(0, 8), {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_added"));
    grants->close();
    window()->resize(1200, 480);
    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)));
    openRow(waitItem(QStringLiteral("accessSpace_") + spaceId));
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));
    clickItem(waitItem(QStringLiteral("spaceTab_access")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_") + people.first()));
    QVERIFY(waitIdle());
    QQuickItem *page = flickableOf(waitItem(QStringLiteral("spacePage")));
    QVERIFY(page);
    QVERIFY(page->property("contentHeight").toReal() > page->height());
    const qreal top = page->property("contentY").toReal();
    wheelOn(waitItem(QStringLiteral("accessHolder_") + people.first()));
    QTRY_VERIFY(page->property("contentY").toReal() > top);

    focusOn(waitItem(QStringLiteral("grantAccessButton")));
    key(Qt::Key_Return);
    QTRY_VERIFY(panelOpen());
    QQuickItem *row = waitItem(QStringLiteral("grantPrincipal_") + people.last());
    QQuickItem *body = flickableOf(row);
    QVERIFY(body);
    QTRY_VERIFY(body->property("contentHeight").toReal() > body->height());
    const qreal start = body->property("contentY").toReal();
    wheelOn(body);
    QTRY_VERIFY(body->property("contentY").toReal() > start);
    key(Qt::Key_Escape);
    QTRY_VERIFY(!panelOpen());
}

// A reload that lands between the press and the release of a click keeps
// the click: rows whose content did not change stay the same items.
void TestStudio::aReloadKeepsTheClick()
{
    openSpace(QStringLiteral("Contracts"));
    const QString orgId = m_session->currentOrgId(), spaceId = m_session->currentSpaceId();
    const QString bo = QStringLiteral("user:") + m_core.seedMember(orgId, QStringLiteral("bo@localhost"), QStringLiteral("member"));
    auto *directory = m_session->accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    auto *grants = m_session->accessGrants();
    grants->open(QStringLiteral("space"), spaceId, spaceId, QStringLiteral("Contracts"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(bo, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->close();
    m_session->runCommand(QStringLiteral("settings"));
    QTRY_VERIFY(m_session->settingsActive());
    const auto clickAcrossReload = [this](QQuickItem *item, const std::function<void()> &reload) {
        QVERIFY(item);
        const QPoint at = centreOf(item);
        QTest::mouseMove(window(), at);
        settle();
        QTest::mousePress(window(), Qt::LeftButton, Qt::NoModifier, at);
        reload();
        settle();
        QTest::mouseRelease(window(), Qt::LeftButton, Qt::NoModifier, at);
        settle();
    };
    // Entering People reloads the organizations, which the navigation
    // lists: its rows stay, and so does the focus on them.
    const QString people = QStringLiteral("settingsOrganization_%1_members").arg(orgId);
    QPointer<QQuickItem> row = waitItem(people);
    clickItem(row);
    QTRY_VERIFY(!m_session->orgAdmin()->busy());
    QTRY_VERIFY(!m_session->organizations()->busy());
    QVERIFY(row);
    QVERIFY(row->hasActiveFocus());
    clickAcrossReload(waitItem(QStringLiteral("settingsOrganization_%1_spaces").arg(orgId)), [this] {
        m_session->refreshOrganizations();
        QTRY_VERIFY(!m_session->organizations()->busy());
    });
    QTRY_VERIFY(shown(QStringLiteral("accessSpace_") + spaceId));
    openRow(waitItem(QStringLiteral("accessSpace_") + spaceId));
    clickItem(waitItem(QStringLiteral("spaceTab_access")));
    QTRY_VERIFY(shown(QStringLiteral("accessHolder_") + bo));
    QVERIFY(waitIdle());
    QTRY_VERIFY(!grants->busy());
    clickAcrossReload(waitItem(QStringLiteral("accessHolder_") + bo), [&] {
        grants->refresh();
        QTRY_VERIFY(!grants->busy());
        directory->open();
        QTRY_VERIFY(!directory->busy());
    });
    QTRY_VERIFY(propertyOf(QStringLiteral("accessHolder_") + bo, "selected").toBool());

    // A space row while the organizations, their spaces, and the add-on
    // activations reload.
    clickItem(waitItem(QStringLiteral("spaceBackButton")));
    QTRY_VERIFY(shown(QStringLiteral("accessSpace_") + spaceId));
    QPointer<QQuickItem> space = waitItem(QStringLiteral("accessSpace_") + spaceId);
    clickAcrossReload(space, [&] {
        m_session->refreshOrganizations();
        m_session->addOnActivations()->refresh();
        QVERIFY(waitIdle());
        QTRY_VERIFY(!m_session->addOnActivations()->busy());
    });
    QVERIFY(space);
    QTRY_VERIFY(space->property("selected").toBool());
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("spacePage")));

    // An add-on row while billing and the activations reload.
    clickItem(waitItem(QStringLiteral("settingsOrganization_%1_addons").arg(orgId)));
    QPointer<QQuickItem> addOn = waitItem(QStringLiteral("addon_classifier"));
    QVERIFY(addOn);
    QTRY_VERIFY(!m_session->orgBilling()->busy());
    QTRY_VERIFY(!m_session->addOnActivations()->busy());
    clickAcrossReload(addOn, [&] {
        m_session->orgBilling()->refresh();
        m_session->addOnActivations()->refresh();
        QTRY_VERIFY(!m_session->orgBilling()->busy());
        QTRY_VERIFY(!m_session->addOnActivations()->busy());
    });
    QVERIFY(addOn);
    QTRY_VERIFY(addOn->property("selected").toBool());
    key(Qt::Key_Return);
    QTRY_VERIFY(shown(QStringLiteral("addonDetail")));
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
