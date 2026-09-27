#include "Client.h"
#include "FakeCore.h"
#include "JsonList.h"
#include "Session.h"

#include <QDir>
#include <QFile>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QTranslator>
#include <QStandardPaths>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

using matome::Client;
using matome::idempotencyHeader;
using matome::idempotentMatchHeader;
using matome::OrgModel;
using matome::SpaceModel;
using matome::FolderModel;
using matome::DocumentModel;
using matome::EntryModel;
using matome::FolderTreeModel;
using matome::Session;
using matome::test::FakeCore;

class TestCore : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void init();
    void rejectsABadOrigin();
    void logsInAgainstCore();
    void mapsWrongPassword();
    void registersAnAccount();
    void logsInWithUnconfirmedEmail();
    void carriesTheFieldsCoreRefused();
    void sendsAResetAndSignsInWithNewPassword();
    void showsAnAcceptedInvitationAfterRefresh();
    void logsOut();
    void abortsAnInFlightCall();
    void mapsNotFound();
    void mapsForcedCoreErrors();
    void timesOutAHungCall();
    void treatsAHugeBodyAsInvalid();
    void persistsEmailWithoutTokens();
    void rejectsEmptyCredentials();
    void listsOrganizationsAfterLogin();
    void createsAnOrganization();
    void rejectsAnEmptyOrganizationName();
    void selectsAndRemembersAnOrganization();
    void retriesOrganizationsAfter401();
    void authedCallWithoutASessionFails();
    void listsSpacesAfterSelectingAnOrganization();
    void createsASpace();
    void rejectsAnEmptySpaceName();
    void leavingAnOrganizationDropsSpaces();
    void retriesSpacesAfter401();
    void spaceSelectIgnoresUnknownIds();
    void listsFoldersAndDocumentsInASpace();
    void createsAFolderAndOpensIt();
    void rejectsAnEmptyFolderName();
    void downloadsTheCurrentDocument();
    void movesADocumentIntoAFolder();
    void keyboardPayloadMovesAFolder();
    void retriesFilesAfter401();
    void leavingASpaceDropsFiles();
    void walksUpAFolderTree();
    void rejectsAFolderCycleOnMove();
    void downloadWithoutAReadyUrlFails();
    void filesNeedASpace();
    void pasteAndDropIgnoreBadPayloads();
    void entriesFollowTheLocation();
    void entryFilterMatchesNamesAndClearsOnMove();
    void entryViewSignalsOnlyWhatChanged();
    void locationReportsLoadingAndErrors();
    void aPlaceNeverListsAnothersDocuments();
    void listsLoadEveryPage();
    void aSupersededListStopsPaging();
    void fakeCorePagesLikeCore();
    void trailNamesEveryCrumbAndNavigates();
    void folderTreeExpandsCollapsesAndClears();
    void historyGoesBackAndForward();
    void historyRestoresADeepLocation();
    void goUpClimbsEveryLevel();
    void createHereFollowsTheLevel();
    void acceptsOnlyDropsThatMove();
    void refreshAtTheRootStaysThere();
    void keysReachEveryCommand();
    void commandsFollowTheLevel();
    void renamesTrashesRestoresAndPurges();
    void uploadsAQueue();
    void fakeCoreTakesControlOverHttp();
    void fakeCoreKeepsNamesAndRevisions();
    void modelsReportFailures();
    void wordsFollowTheTranslator();

private:
    // Signs in, opens the first organization and creates the Inbox space.
    bool openInbox(FakeCore &core, Session &session)
    {
        session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
        if (!waitFor(&session))
            return false;
        session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
        if (!waitFor(&session))
            return false;
        session.createHere(QStringLiteral("Inbox"));
        return waitFor(&session) && session.level() == QLatin1String("files");
    }

    static QString entry(Session &session, int row, int role)
    {
        return session.entries()->index(row).data(role).toString();
    }

    static QVariant tree(Session &session, int row, int role)
    {
        return session.folderTree()->index(row).data(role);
    }

    static QVariantMap command(Session &session, const QString &id)
    {
        for (const QVariant &row : session.commandList()) {
            if (row.toMap().value(QStringLiteral("id")) == id)
                return row.toMap();
        }
        return {};
    }

    static bool usable(Session &session, const QString &id)
    {
        return command(session, id).value(QStringLiteral("usable")).toBool();
    }

    bool waitFor(Session *session)
    {
        return QTest::qWaitFor(
                [&] {
                    return !session->busy() && !session->organizations()->busy()
                            && !session->spaces()->busy() && !session->folders()->busy()
                            && !session->documents()->busy();
                });
    }

    QTemporaryDir m_home;
};

void TestCore::initTestCase()
{
    QVERIFY(m_home.isValid());
    QStandardPaths::setTestModeEnabled(true);
    qputenv("XDG_CONFIG_HOME", m_home.filePath("config").toUtf8());
    // Downloads default to ~/Downloads; keep them in the scratch home.
    qputenv("HOME", m_home.path().toUtf8());
}

void TestCore::init()
{
    QDir(m_home.filePath(QStringLiteral("config"))).removeRecursively();
    QSettings settings;
    settings.clear();
}

void TestCore::rejectsABadOrigin()
{
    Client client;
    bool finished = false;
    Client::Reply reply;
    client.setBaseUrl(QUrl(QStringLiteral("file:///tmp")));
    client.post(QStringLiteral("/api/auth/login"), {}, [&](const Client::Reply &value) {
        finished = true;
        reply = value;
    });
    QVERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("network"));
    QVERIFY(!reply.ok);
}

void TestCore::logsInAgainstCore()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.email(), QStringLiteral("ok@localhost"));
    QVERIFY(core.lastPath().startsWith(QStringLiteral("/api/v1/organizations")));
    bool finished = false;
    Client::Reply me;
    session.client()->get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &value) {
        finished = true;
        me = value;
    });
    QTRY_VERIFY(finished);
    QVERIFY(me.ok);
}

void TestCore::mapsWrongPassword()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("nope"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.signedIn());
    QCOMPARE(session.errorCode(), QStringLiteral("unauthenticated"));
}

void TestCore::registersAnAccount()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.registerAccount(QStringLiteral("new@localhost"), QStringLiteral("secret12"),
                            core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.confirmationPending());
    QVERIFY(!session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 0);

    session.resendConfirmation();
    QVERIFY(waitFor(&session));
    QVERIFY(session.confirmationResent());

    QVERIFY(core.confirmEmailInBrowser(QStringLiteral("new@localhost")));
    QVERIFY(session.confirmationPending());
    session.signOut();
    session.signIn(QStringLiteral("new@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.confirmationPending());
    QVERIFY(!session.confirmationResent());
    QVERIFY(session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 1);
}

void TestCore::logsInWithUnconfirmedEmail()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.registerAccount(QStringLiteral("new@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.confirmationPending());

    session.signOut();
    QVERIFY(!session.confirmationPending());
    session.signIn(QStringLiteral("new@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.confirmationPending());
    QVERIFY(!session.signedIn());

    QVERIFY(core.confirmEmailInBrowser(QStringLiteral("new@localhost")));
    session.signOut();
    session.signIn(QStringLiteral("new@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 1);
}

void TestCore::carriesTheFieldsCoreRefused()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.registerAccount(QStringLiteral("ok@localhost"), QStringLiteral("short"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.signedIn());
    QCOMPARE(session.errorCode(), QStringLiteral("invalid_request"));
    QCOMPARE(session.errorFields(), (QStringList{QStringLiteral("email"), QStringLiteral("password")}));

}

void TestCore::sendsAResetAndSignsInWithNewPassword()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.requestPasswordReset(QStringLiteral("ok@localhost"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.resetSent());
    QVERIFY(core.resetPasswordInBrowser(QStringLiteral("ok@localhost"), QStringLiteral("fresh-pass1")));
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.signedIn());
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("fresh-pass1"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
}

void TestCore::showsAnAcceptedInvitationAfterRefresh()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->rowCount(), 1);
    QVERIFY(core.acceptInvitationInBrowser(QStringLiteral("ok@localhost"), QStringLiteral("Invited")));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->rowCount(), 2);
}

void TestCore::logsOut()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.runCommand(QStringLiteral("sign-out"));
    QVERIFY(!session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 0);
    QTRY_COMPARE(core.lastPath(), QStringLiteral("/api/auth/logout"));
}

void TestCore::abortsAnInFlightCall()
{
    FakeCore core;
    QVERIFY(core.listen());
    QVERIFY(core.failNext(QStringLiteral("POST"), QStringLiteral("^/api/auth/login$"), 1,
                          FakeCore::FaultMode::Hold));
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    bool finished = false;
    client.post(QStringLiteral("/api/auth/login"),
                QJsonObject{{QStringLiteral("email"), QStringLiteral("ok@localhost")},
                            {QStringLiteral("password"), QStringLiteral("secret12")}},
                [&](const Client::Reply &) { finished = true; });
    QTRY_COMPARE(core.held(), 1);
    client.abortAll();
    core.release();
    // A call made after the abort is answered; the aborted one never is.
    bool after = false;
    client.get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &) { after = true; });
    QTRY_VERIFY(after);
    QVERIFY(!finished);
}

void TestCore::mapsNotFound()
{
    FakeCore core;
    QVERIFY(core.listen());
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    Client::Reply reply;
    bool finished = false;
    client.get(QStringLiteral("/missing"), [&](const Client::Reply &value) {
        finished = true;
        reply = value;
    });
    QTRY_VERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("not_found"));
}

void TestCore::mapsForcedCoreErrors()
{
    FakeCore core;
    QVERIFY(core.listen());
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    const struct {
        int status;
        const char *error;
        const char *code;
    } cases[] = {
        {401, "invalid_credentials", "unauthenticated"},
        {403, "organization_access_denied", "forbidden"},
        {409, "name_conflict", "name_conflict"},
        {422, "invalid_reset_token", "invalid_reset_token"},
        {429, "rate_limited", "rate_limited"},
        {500, "server_error", "server"},
    };
    for (const auto &row : cases) {
        core.forcedStatus = row.status;
        core.forcedError = QString::fromUtf8(row.error);
        Client::Reply reply;
        bool finished = false;
        client.get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &value) {
            finished = true;
            reply = value;
        });
        QTRY_VERIFY(finished);
        QCOMPARE(reply.code, QString::fromUtf8(row.code));
        QVERIFY(!reply.json.value(QStringLiteral("request_id")).toString().isEmpty());
    }
}

void TestCore::timesOutAHungCall()
{
    FakeCore core;
    QVERIFY(core.listen());
    QVERIFY(core.failNext(QStringLiteral("GET"), QStringLiteral("^/api/auth/me$"), 1, FakeCore::FaultMode::Hold));
    Client client;
    client.setTimeoutMs(40);
    client.setBaseUrl(QUrl(core.url()));
    Client::Reply reply;
    bool finished = false;
    client.get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &value) {
        finished = true;
        reply = value;
    });
    QTRY_VERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("network"));
}

void TestCore::treatsAHugeBodyAsInvalid()
{
    FakeCore core;
    core.overflow = true;
    QVERIFY(core.listen());
    Client client;
    client.setTimeoutMs(3000);
    client.setBaseUrl(QUrl(core.url()));
    Client::Reply reply;
    bool finished = false;
    client.get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &value) {
        finished = true;
        reply = value;
    });
    QTRY_VERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("invalid_request"));
}

void TestCore::persistsEmailWithoutTokens()
{
    FakeCore core;
    QVERIFY(core.listen());
    {
        Session session;
        session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
        QVERIFY(waitFor(&session));
        session.runCommand(QStringLiteral("sign-out"));
    }
    Session again;
    QCOMPARE(again.email(), QStringLiteral("ok@localhost"));
    QVERIFY(!again.signedIn());
    QVERIFY(again.apiBaseUrl().startsWith(QStringLiteral("http://127.0.0.1:")));
}

void TestCore::rejectsEmptyCredentials()
{
    Session session;
    session.signIn(QStringLiteral(""), QStringLiteral("x"), QStringLiteral("http://127.0.0.1:1"));
    QCOMPARE(session.errorCode(), QStringLiteral("invalid_request"));
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"),
                   QStringLiteral("not-a-url"));
    QCOMPARE(session.errorCode(), QStringLiteral("network"));
    session.requestPasswordReset(QStringLiteral(""), QStringLiteral("http://127.0.0.1:1"));
    QCOMPARE(session.errorCode(), QStringLiteral("invalid_request"));
    session.setApiBaseUrl(QString());
    QCOMPARE(session.apiBaseUrl(), QString::fromUtf8(qgetenv("MATOME_TEST_DEFAULT_SERVER")));
    session.setApiBaseUrl(QString::fromUtf8(qgetenv("MATOME_TEST_DEFAULT_SERVER")));
}

void TestCore::listsOrganizationsAfterLogin()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    OrgModel *orgs = session.organizations();
    QCOMPARE(orgs->rowCount(), 1);
    QCOMPARE(orgs->data(orgs->index(0), OrgModel::NameRole).toString(),
             QStringLiteral("ok organization"));
    QCOMPARE(orgs->data(orgs->index(0), OrgModel::RoleNameRole).toString(),
             QStringLiteral("owner"));
    QVERIFY(!orgs->data(orgs->index(0), OrgModel::OrgIdRole).toString().isEmpty());
    QCOMPARE(orgs->data(orgs->index(0), Qt::DisplayRole), QVariant());
    QCOMPARE(orgs->rowCount(orgs->index(0)), 0);
}

void TestCore::createsAnOrganization()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.organizations()->create(QStringLiteral("Acme"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->rowCount(), 2);
    QVERIFY(!core.lastIdempotency().isEmpty());
    QVERIFY(session.organizations()->currentOrgId().startsWith(QStringLiteral("org-")));
}

void TestCore::rejectsAnEmptyOrganizationName()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.organizations()->create(QStringLiteral("  "));
    QCOMPARE(session.organizations()->errorCode(), QStringLiteral("invalid_request"));
}

void TestCore::selectsAndRemembersAnOrganization()
{
    FakeCore core;
    QVERIFY(core.listen());
    QString id;
    {
        Session session;
        session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
        QVERIFY(waitFor(&session));
        id = session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                     .toString();
        session.organizations()->select(id);
        QCOMPARE(session.organizations()->currentOrgId(), id);
        QCOMPARE(session.lastOrgId(), id);
        session.organizations()->select(id);
        session.organizations()->select(QStringLiteral("missing"));
        QCOMPARE(session.organizations()->currentOrgId(), id);
        session.runCommand(QStringLiteral("sign-out"));
    }
    Session again;
    again.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&again));
    QCOMPARE(again.organizations()->currentOrgId(), id);
}

void TestCore::retriesOrganizationsAfter401()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    core.failNext(QString(), QStringLiteral("^/api/v1/"), 1, FakeCore::FaultMode::Expire);
    session.organizations()->reload();
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 1);
}

void TestCore::authedCallWithoutASessionFails()
{
    Session session;
    bool finished = false;
    Client::Reply reply;
    session.authedGet(QStringLiteral("/api/v1/organizations"), [&](const Client::Reply &value) {
        finished = true;
        reply = value;
    });
    QVERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("unauthenticated"));
}

void TestCore::listsSpacesAfterSelectingAnOrganization()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    const QString orgId =
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString();
    session.openEntry(QStringLiteral("org"), orgId);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.currentOrgId(), orgId);
    QCOMPARE(session.spaces()->rowCount(), 0);
    QVERIFY(core.lastPath().endsWith(QStringLiteral("/spaces")));
}

void TestCore::createsASpace()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.spaces()->rowCount(), 1);
    QVERIFY(!core.lastIdempotency().isEmpty());
    QCOMPARE(session.spaces()->data(session.spaces()->index(0), SpaceModel::NameRole).toString(),
             QStringLiteral("Inbox"));
    QCOMPARE(session.spaces()->data(session.spaces()->index(0), SpaceModel::StatusRole).toString(),
             QStringLiteral("active"));
    QCOMPARE(session.spaces()->data(session.spaces()->index(0), SpaceModel::ColorIndexRole).toInt(),
             0);
    QVERIFY(!session.currentSpaceId().isEmpty());
}

void TestCore::rejectsAnEmptySpaceName()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("  "));
    QCOMPARE(session.spaces()->errorCode(), QStringLiteral("invalid_request"));
}

void TestCore::leavingAnOrganizationDropsSpaces()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    const QString orgId =
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString();
    session.openEntry(QStringLiteral("org"), orgId);
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("root"), QString());
    QVERIFY(session.currentOrgId().isEmpty());
    QCOMPARE(session.spaces()->rowCount(), 0);
    QCOMPARE(session.lastOrgId(), orgId);
}

void TestCore::retriesSpacesAfter401()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    core.failNext(QString(), QStringLiteral("^/api/v1/"), 1, FakeCore::FaultMode::Expire);
    session.spaces()->reload();
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.spaces()->errorCode(), QString());
}

void TestCore::spaceSelectIgnoresUnknownIds()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    const QString id = session.currentSpaceId();
    session.navigate(QStringLiteral("space"), QStringLiteral("missing"));
    QCOMPARE(session.currentSpaceId(), id);
    session.navigate(QStringLiteral("space"), id);
    QCOMPARE(session.currentSpaceId(), id);
    QCOMPARE(session.spaces()->data(session.spaces()->index(0), Qt::DisplayRole), QVariant());
    QCOMPARE(session.spaces()->rowCount(session.spaces()->index(0)), 0);
}

void TestCore::listsFoldersAndDocumentsInASpace()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"), {}, QByteArray("hello world"));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Draft"));
    session.documents()->reload();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 0);
    QCOMPARE(session.documents()->rowCount(), 2);
    QCOMPARE(session.documents()->data(session.documents()->index(0), DocumentModel::TitleRole)
                     .toString(),
             QStringLiteral("Notes"));
    // The size is the current version's; a document without a ready version has none.
    QCOMPARE(core.documentTitled(QStringLiteral("Notes")).value(QStringLiteral("current_version"))
                     .toObject().value(QStringLiteral("byte_size")).toInt(),
             11);
    QCOMPARE(session.documents()->data(session.documents()->index(0), DocumentModel::ByteSizeRole)
                     .toString(),
             QStringLiteral("11"));
    QVERIFY(core.documentTitled(QStringLiteral("Draft")).value(QStringLiteral("current_version")).isNull());
    QCOMPARE(session.documents()->data(session.documents()->index(1), DocumentModel::ByteSizeRole)
                     .toString(),
             QString());
    QVERIFY(core.lastQuery().contains(QStringLiteral("folder_id=root")));
}

void TestCore::createsAFolderAndOpensIt()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("Contracts"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 1);
    QVERIFY(!core.lastIdempotency().isEmpty());
    const QString id =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    session.openEntry(QStringLiteral("folder"), id);
    QCOMPARE(session.currentFolderId(), id);
    session.openEntry(QStringLiteral("folder"), QStringLiteral("missing"));
    QCOMPARE(session.currentFolderId(), id);
    QCOMPARE(session.folders()->data(session.folders()->index(0), Qt::DisplayRole), QVariant());
    QCOMPARE(session.folders()->rowCount(session.folders()->index(0)), 0);
}

void TestCore::rejectsAnEmptyFolderName()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("  "));
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("invalid_request"));
}

void TestCore::downloadsTheCurrentDocument()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.documents()->reload();
    QVERIFY(waitFor(&session));
    const QString id =
            session.documents()->data(session.documents()->index(0), DocumentModel::DocumentIdRole)
                    .toString();
    QSignalSpy saved(&session, &Session::downloadReady);
    session.documents()->download(id);
    QVERIFY(waitFor(&session));
    QCOMPARE(saved.size(), 1);
    QCOMPARE(core.lastPath(), QStringLiteral("/files/") + id);
    QCOMPARE(session.currentDocumentId(), id);
}

void TestCore::movesADocumentIntoAFolder()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("Contracts"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.documents()->reload();
    QVERIFY(waitFor(&session));
    const QString folderId =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    const QString docId =
            session.documents()->data(session.documents()->index(0), DocumentModel::DocumentIdRole)
                    .toString();
    const int revision =
            session.documents()->data(session.documents()->index(0), DocumentModel::RevisionRole).toInt();
    const QString created = core.lastIdempotency();
    session.dropPayload(folderId, QStringLiteral("document:%1:%2").arg(docId).arg(revision));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 0);
    QVERIFY(!core.lastIdempotency().isEmpty());
    QVERIFY(core.lastIdempotency() != created);
    session.openEntry(QStringLiteral("folder"), folderId);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 1);
}

void TestCore::keyboardPayloadMovesAFolder()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 2);
    const QString a =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    const QString b =
            session.folders()->data(session.folders()->index(1), FolderModel::FolderIdRole).toString();
    session.setFocusPayload(QStringLiteral("folder:%1:1").arg(a));
    session.runCommand(QStringLiteral("cut"));
    QVERIFY(session.hasClipboard());
    const QString created = core.lastIdempotency();
    session.dropPayload(b, QStringLiteral("folder:%1:1").arg(a));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 1);
    QVERIFY(!core.lastIdempotency().isEmpty());
    QVERIFY(core.lastIdempotency() != created);
    session.openEntry(QStringLiteral("folder"), b);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 1);
    session.dropPayload(a, QStringLiteral("folder:%1:1").arg(a));
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("folder_cycle"));
    session.setFocusPayload(QStringLiteral("nope"));
    session.runCommand(QStringLiteral("cut"));
    session.runCommand(QStringLiteral("paste"));
}

void TestCore::retriesFilesAfter401()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    core.failNext(QString(), QStringLiteral("^/api/v1/"), 1, FakeCore::FaultMode::Expire);
    session.folders()->reload();
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.folders()->errorCode(), QString());
}

void TestCore::leavingASpaceDropsFiles()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString spaceId = session.currentSpaceId();
    session.navigate(QStringLiteral("org"), session.currentOrgId());
    QVERIFY(session.currentSpaceId().isEmpty());
    QCOMPARE(session.folders()->rowCount(), 0);
    session.navigate(QStringLiteral("space"), spaceId);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 1);
}

void TestCore::walksUpAFolderTree()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    session.openEntry(QStringLiteral("folder"), a);
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    const QString b =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    session.openEntry(QStringLiteral("folder"), b);
    QCOMPARE(session.currentFolderId(), b);
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.currentFolderId(), a);
    session.runCommand(QStringLiteral("up"));
    QVERIFY(session.currentFolderId().isEmpty());
    session.openEntry(QStringLiteral("folder"), a);
    session.openEntry(QStringLiteral("folder"), a);
    QCOMPARE(session.currentFolderId(), a);
    QCOMPARE(session.documents()->revisionOf(QStringLiteral("missing")), 0);
    QCOMPARE(session.folders()->parentFolderId(), QString());
}

void TestCore::rejectsAFolderCycleOnMove()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.folders()->create(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a =
            session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    session.folders()->move(a, a, 1);
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("folder_cycle"));
    // The refusal belongs to the folder it happened in, not the next one.
    session.openEntry(QStringLiteral("folder"), a);
    QCOMPARE(session.folders()->errorCode(), QString());
    session.runCommand(QStringLiteral("up"));
    session.folders()->move(QString(), QString(), 1);
    session.documents()->move(QString(), QString(), 1);
    session.documents()->download(QString());
}

void TestCore::downloadWithoutAReadyUrlFails()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    core.forcedStatus = 404;
    core.forcedError = QStringLiteral("not_found");
    session.documents()->download(QStringLiteral("1"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->errorCode(), QStringLiteral("not_found"));
}

void TestCore::filesNeedASpace()
{
    Session session;
    session.folders()->create(QStringLiteral("A"));
    session.spaces()->create(QStringLiteral("Inbox"));
    session.folders()->reload();
    session.documents()->reload();
    QCOMPARE(session.folders()->rowCount(), 0);
    QCOMPARE(session.documents()->rowCount(), 0);
    session.openEntry(QStringLiteral("document"), QStringLiteral("1"));
    QVERIFY(session.currentDocumentId().isEmpty());
}

void TestCore::pasteAndDropIgnoreBadPayloads()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"),
            session.organizations()->data(session.organizations()->index(0), OrgModel::OrgIdRole)
                    .toString());
    QVERIFY(waitFor(&session));
    session.spaces()->create(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    session.setFocusPayload(QStringLiteral("nope"));
    session.runCommand(QStringLiteral("cut"));
    QVERIFY(!session.hasClipboard());
    session.runCommand(QStringLiteral("paste"));
    session.dropPayload(QString(), QStringLiteral("folder::1"));
    session.setFocusPayload(QStringLiteral("document:9:1"));
    session.runCommand(QStringLiteral("cut"));
    QVERIFY(session.hasClipboard());
    session.runCommand(QStringLiteral("paste"));
    QVERIFY(waitFor(&session));
}

void TestCore::entriesFollowTheLocation()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QCOMPARE(session.entryCount(), 1);
    QCOMPARE(entry(session, 0, EntryModel::KindRole), QStringLiteral("org"));
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("ok organization"));
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QStringLiteral("owner"));
    QCOMPARE(session.entries()->index(0).data(EntryModel::ColorIndexRole).toInt(), -1);
    QCOMPARE(entry(session, 0, EntryModel::PayloadRole), QString());
    QVERIFY(!session.entries()->index(0).data(EntryModel::CurrentRole).toBool());
    const QString orgId = entry(session, 0, EntryModel::EntryIdRole);
    QCOMPARE(session.organizations()->index(0).data(OrgModel::RevisionRole).toInt(), 1);

    session.openEntry(QStringLiteral("org"), orgId);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    QCOMPARE(session.entryCount(), 0);
    session.createHere(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    const QString spaceId = session.currentSpaceId();
    session.runCommand(QStringLiteral("up"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    QCOMPARE(session.entryCount(), 1);
    QCOMPARE(entry(session, 0, EntryModel::KindRole), QStringLiteral("space"));
    QCOMPARE(entry(session, 0, EntryModel::EntryIdRole), spaceId);
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("Inbox"));
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QStringLiteral("active"));
    QCOMPARE(session.entries()->index(0).data(EntryModel::ColorIndexRole).toInt(), 0);
    QCOMPARE(session.spaces()->index(0).data(SpaceModel::RevisionRole).toInt(), 1);
    session.runCommand(QStringLiteral("up"));
    QVERIFY(session.entries()->index(0).data(EntryModel::CurrentRole).toBool());

    session.openEntry(QStringLiteral("org"), orgId);
    session.openEntry(QStringLiteral("space"), spaceId);
    QVERIFY(waitFor(&session));
    session.createHere(QStringLiteral("Contracts"));
    QVERIFY(waitFor(&session));
    core.seedDocument(spaceId, QStringLiteral("Notes"), {}, QByteArray("hello world\n"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.entryCount(), 2);
    const QString folderId = entry(session, 0, EntryModel::EntryIdRole);
    const QString documentId = entry(session, 1, EntryModel::EntryIdRole);
    QCOMPARE(entry(session, 0, EntryModel::KindRole), QStringLiteral("folder"));
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QString());
    QCOMPARE(entry(session, 0, EntryModel::PayloadRole), QStringLiteral("folder:%1:1").arg(folderId));
    QCOMPARE(entry(session, 1, EntryModel::KindRole), QStringLiteral("document"));
    QCOMPARE(entry(session, 1, EntryModel::NameRole), QStringLiteral("Notes"));
    QCOMPARE(entry(session, 1, EntryModel::DetailRole), QLocale().formattedDataSize(12));
    QCOMPARE(entry(session, 1, EntryModel::PayloadRole),
             QStringLiteral("document:%1:1").arg(documentId));
    QVERIFY(!session.entries()->index(1).data(EntryModel::CurrentRole).toBool());
    QCOMPARE(session.documents()->index(0).data(DocumentModel::FolderIdRole).toString(), QString());
    QCOMPARE(session.documents()->index(0).data(Qt::DisplayRole), QVariant());
    session.openEntry(QStringLiteral("document"), documentId);
    QVERIFY(session.entries()->index(1).data(EntryModel::CurrentRole).toBool());
    QCOMPARE(session.currentDocumentId(), documentId);

    QCOMPARE(session.entries()->index(0).data(Qt::DisplayRole), QVariant());
    QCOMPARE(session.entries()->index(0).data(EntryModel::CurrentRole + 1), QVariant());
    QCOMPARE(session.entries()->index(7).data(EntryModel::NameRole), QVariant());
    QCOMPARE(session.entries()->rowCount(session.entries()->index(0)), 0);
    QCOMPARE(session.entries()->roleNames().value(EntryModel::PayloadRole), QByteArray("payload"));
}

void TestCore::entryFilterMatchesNamesAndClearsOnMove()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("Contracts"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QSignalSpy changed(&session, &Session::changed);
    session.setFilter(QStringLiteral("NOTE"));
    QCOMPARE(changed.size(), 1);
    QCOMPARE(session.filter(), QStringLiteral("NOTE"));
    QCOMPARE(session.entryCount(), 1);
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("Notes"));
    session.setFilter(QStringLiteral("NOTE"));
    QCOMPARE(changed.size(), 1);
    session.setFilter(QStringLiteral("zzz"));
    QCOMPARE(session.entryCount(), 0);
    session.setFilter(QStringLiteral("con"));
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("Contracts"));
    session.openEntry(QStringLiteral("folder"), entry(session, 0, EntryModel::EntryIdRole));
    QCOMPARE(session.filter(), QString());
}

void TestCore::entryViewSignalsOnlyWhatChanged()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("Alpha"));
    QVERIFY(waitFor(&session));
    session.createHere(QStringLiteral("Beta"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.entryCount(), 3);
    EntryModel *entries = session.entries();
    QSignalSpy reset(entries, &QAbstractItemModel::modelReset);
    QSignalSpy inserted(entries, &QAbstractItemModel::rowsInserted);
    QSignalSpy removed(entries, &QAbstractItemModel::rowsRemoved);
    QSignalSpy edited(entries, &QAbstractItemModel::dataChanged);

    session.setFilter(QStringLiteral("l"));
    QCOMPARE(session.entryCount(), 1);
    QCOMPARE(removed.size(), 1);
    QCOMPARE(inserted.size(), 0);
    session.setFilter(QStringLiteral("e"));
    QCOMPARE(session.entryCount(), 2);
    QCOMPARE(removed.size(), 2);
    QCOMPARE(inserted.size(), 1);
    session.setFilter(QString());
    QCOMPARE(session.entryCount(), 3);
    QCOMPARE(removed.size(), 2);
    QCOMPARE(inserted.size(), 2);
    session.openEntry(QStringLiteral("document"), entry(session, 2, EntryModel::EntryIdRole));
    QCOMPARE(edited.size(), 1);
    QCOMPARE(edited.at(0).at(0).toModelIndex().row(), 2);
    entries->refresh();
    QCOMPARE(edited.size(), 1);
    QCOMPARE(reset.size(), 0);
    session.openEntry(QStringLiteral("folder"), entry(session, 0, EntryModel::EntryIdRole));
    QCOMPARE(reset.size(), 1);
}

void TestCore::locationReportsLoadingAndErrors()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.loading());
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));
    session.createHere(QStringLiteral(" "));
    QCOMPARE(session.locationError(), QStringLiteral("invalid_request"));
    session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.locationError(), QString());
    session.createHere(QStringLiteral(" "));
    QCOMPARE(session.locationError(), QStringLiteral("invalid_request"));
    session.createHere(QStringLiteral("Inbox"));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.loading());
    QCOMPARE(session.locationError(), QString());
    session.createHere(QStringLiteral(" "));
    QCOMPARE(session.locationError(), QStringLiteral("invalid_request"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    core.forcedStatus = 404;
    core.forcedError = QStringLiteral("not_found");
    session.documents()->download(QStringLiteral("1"));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.locationError(), QStringLiteral("not_found"));
}

// A refresh that fails keeps the place's rows; a folder whose documents
// fail to load shows none, never the ones of the place before it.
void TestCore::aPlaceNeverListsAnothersDocuments()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 1);

    core.forcedStatus = 500;
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.locationError(), QStringLiteral("server"));
    QCOMPARE(session.documents()->rowCount(), 1);

    session.openEntry(QStringLiteral("folder"), a);
    QCOMPARE(session.documents()->rowCount(), 0);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 0);
    QCOMPARE(session.locationError(), QStringLiteral("server"));
}

// Core answers a list 50 entries at a time: every model follows the cursor
// to the last page, and the documents of a folder stay that folder's.
void TestCore::listsLoadEveryPage()
{
    FakeCore core;
    QVERIFY(core.listen());
    QJsonArray orgs{QJsonObject{
            {QStringLiteral("name"), QStringLiteral("Acme")},
            {QStringLiteral("spaces"),
             QJsonArray{QJsonObject{{QStringLiteral("name"), QStringLiteral("Inbox")},
                                    {QStringLiteral("folders"),
                                     QJsonArray{QJsonObject{{QStringLiteral("name"), QStringLiteral("A")},
                                                            {QStringLiteral("documents"),
                                                             QJsonArray{QJsonObject{
                                                                     {QStringLiteral("title"), QStringLiteral("Inside")},
                                                                     {QStringLiteral("repeat"), 120}}}}},
                                                QJsonObject{{QStringLiteral("name"), QStringLiteral("Box")},
                                                            {QStringLiteral("repeat"), 119}}}},
                                    {QStringLiteral("documents"),
                                     QJsonArray{QJsonObject{{QStringLiteral("title"), QStringLiteral("Row")},
                                                            {QStringLiteral("repeat"), 120}}}}}}}}};
    for (int i = 1; i <= 58; ++i)
        orgs.append(QJsonObject{{QStringLiteral("name"), QStringLiteral("Org %1").arg(i)}});
    core.seed({{QStringLiteral("organizations"), orgs}});
    for (int i = 1; i <= 59; ++i)
        core.seedSpace(QStringLiteral("org-1"), QStringLiteral("Space %1").arg(i, 3, 10, QLatin1Char('0')));

    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->rowCount(), 60);
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("Acme"));
    QCOMPARE(entry(session, 59, EntryModel::NameRole), QStringLiteral("ok organization"));

    session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.spaces()->rowCount(), 60);
    QCOMPARE(entry(session, 59, EntryModel::NameRole), QStringLiteral("Space 059"));

    session.openEntry(QStringLiteral("space"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 120);
    QCOMPARE(session.documents()->rowCount(), 120);
    QCOMPARE(session.entryCount(), 240);
    QVERIFY(core.lastQuery().contains(QStringLiteral("folder_id=root")));
    QVERIFY(core.lastQuery().contains(QStringLiteral("cursor=")));

    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 120);
    QCOMPARE(session.documents()->data(session.documents()->index(119), DocumentModel::TitleRole).toString(),
             QStringLiteral("Inside 120"));
    for (int row = 0; row < 120; ++row)
        QCOMPARE(session.documents()->data(session.documents()->index(row), DocumentModel::FolderIdRole)
                         .toString(),
                 a);
    QVERIFY(core.lastQuery().contains(QStringLiteral("folder_id=") + a));
    QVERIFY(core.lastQuery().contains(QStringLiteral("cursor=")));
}

// A reload that another one supersedes between two pages asks for no more
// pages, and its late page changes nothing; a page that fails keeps the rows.
void TestCore::aSupersededListStopsPaging()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    for (int i = 1; i <= 120; ++i)
        core.seedDocument(session.currentSpaceId(), QStringLiteral("Row %1").arg(i, 3, 10, QLatin1Char('0')));
    const QString documents = QStringLiteral("/documents$");

    // The first page goes through and the second is parked.
    QVERIFY(core.failNext(QStringLiteral("GET"), documents, 2, FakeCore::FaultMode::Hold));
    session.documents()->reload();
    QTRY_COMPARE(core.held(), 1);
    core.release();
    QTRY_COMPARE(core.held(), 1);
    QVERIFY(session.documents()->busy());

    core.seedDocument(session.currentSpaceId(), QStringLiteral("Row 121"));
    session.documents()->reload();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 121);
    const int hits = core.hits();
    core.release();
    QVERIFY(!QTest::qWaitFor([&] { return core.hits() != hits; }, 200));
    QVERIFY(!session.documents()->busy());
    QCOMPARE(session.documents()->rowCount(), 121);
    QCOMPARE(session.locationError(), QString());

    QVERIFY(core.failNext(QStringLiteral("GET"), documents, 1, FakeCore::FaultMode::Hold));
    session.documents()->reload();
    QTRY_COMPARE(core.held(), 1);
    QVERIFY(core.failNext(QStringLiteral("GET"), documents, 1, FakeCore::FaultMode::Status));
    core.release();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.locationError(), QStringLiteral("server"));
    QCOMPARE(session.documents()->rowCount(), 121);
}

// FakeCore pages a list as Core does: ordered by id, 50 at a time unless
// `limit` asks for 1 to 100, under the list's name and "data", with an
// opaque cursor to the next page; a cursor that names no id is refused.
void TestCore::fakeCorePagesLikeCore()
{
    FakeCore core;
    QVERIFY(core.listen());
    core.seed(QJsonDocument::fromJson(R"({"organizations": [{"name": "Acme", "spaces": [{
        "name": "Inbox", "folders": [{"name": "Box", "repeat": 120}]}]}]})").object());
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    client.setAccessToken(QStringLiteral("access-1"));
    Client::Reply reply;
    const auto get = [&](const QString &query) {
        bool finished = false;
        client.get(QStringLiteral("/api/v1/organizations/org-1/spaces/space-1/folders") + query,
                   [&](const Client::Reply &value) {
                       finished = true;
                       reply = value;
                   });
        return QTest::qWaitFor([&] { return finished; }) && reply.ok;
    };
    const auto page = [&] { return reply.json.value(QStringLiteral("page")).toObject(); };
    const auto ids = [&] {
        QStringList out;
        for (const QJsonValue &value : reply.json.value(QStringLiteral("folders")).toArray())
            out.append(value.toObject().value(QStringLiteral("id")).toString());
        return out;
    };

    QVERIFY(get(QString()));
    QCOMPARE(ids().size(), 50);
    QCOMPARE(ids().first(), QStringLiteral("folder-1"));
    QCOMPARE(ids().last(), QStringLiteral("folder-50"));
    QCOMPARE(reply.json.value(QStringLiteral("data")).toArray(), reply.json.value(QStringLiteral("folders")).toArray());
    QVERIFY(reply.json.value(QStringLiteral("request_id")).isString());
    QCOMPARE(page().value(QStringLiteral("limit")).toInt(), 50);
    QVERIFY(page().value(QStringLiteral("has_more")).toBool());
    const QString cursor = page().value(QStringLiteral("next_cursor")).toString();
    QCOMPARE(QByteArray::fromBase64(cursor.toLatin1(), QByteArray::Base64UrlEncoding), QByteArray("folder-50"));

    QVERIFY(get(QStringLiteral("?limit=100&cursor=") + cursor));
    QCOMPARE(ids().size(), 70);
    QCOMPARE(ids().first(), QStringLiteral("folder-51"));
    QCOMPARE(ids().last(), QStringLiteral("folder-120"));
    QCOMPARE(page().value(QStringLiteral("limit")).toInt(), 100);
    QVERIFY(!page().value(QStringLiteral("has_more")).toBool());
    QVERIFY(page().value(QStringLiteral("next_cursor")).isNull());

    QVERIFY(get(QStringLiteral("?limit=101")));
    QCOMPARE(page().value(QStringLiteral("limit")).toInt(), 50);

    for (const QString &bad : {QStringLiteral("!!"), QStringLiteral("Zm9sZGVy"), QString()}) {
        QVERIFY(!get(QStringLiteral("?cursor=") + bad));
        QCOMPARE(reply.status, 400);
        QCOMPARE(reply.code, QStringLiteral("invalid_cursor"));
    }
}

void TestCore::trailNamesEveryCrumbAndNavigates()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QSignalSpy moved(&session, &Session::trailChanged);
    QCOMPARE(session.trail().size(), 1);
    const QVariantMap root = session.trail().at(0).toMap();
    QCOMPARE(root.value(QStringLiteral("kind")).toString(), QStringLiteral("root"));
    QCOMPARE(root.value(QStringLiteral("id")).toString(), QString());
    QCOMPARE(root.value(QStringLiteral("name")).toString(), QStringLiteral("Matome"));
    const QString orgId = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("org"), orgId);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.trail().size(), 2);
    QCOMPARE(session.trail().at(1).toMap().value(QStringLiteral("name")).toString(),
             QStringLiteral("ok organization"));
    const int crumbs = moved.size();
    QVERIFY(crumbs > 0);
    session.setFilter(QStringLiteral("x"));
    session.setFilter(QString());
    QCOMPARE(moved.size(), crumbs);
    session.createHere(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    const QString spaceId = session.currentSpaceId();
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    session.createHere(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    const QString b = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), b);
    const QVariantList trail = session.trail();
    QCOMPARE(trail.size(), 5);
    QCOMPARE(trail.at(1).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("org"));
    QCOMPARE(trail.at(1).toMap().value(QStringLiteral("id")).toString(), orgId);
    QCOMPARE(trail.at(2).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("space"));
    QCOMPARE(trail.at(2).toMap().value(QStringLiteral("name")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(trail.at(3).toMap().value(QStringLiteral("id")).toString(), a);
    QCOMPARE(trail.at(4).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("folder"));
    QCOMPARE(trail.at(4).toMap().value(QStringLiteral("name")).toString(), QStringLiteral("B"));

    session.navigate(QStringLiteral("folder"), a);
    QCOMPARE(session.currentFolderId(), a);
    session.navigate(QStringLiteral("space"), spaceId);
    QCOMPARE(session.currentFolderId(), QString());
    QCOMPARE(session.currentSpaceId(), spaceId);
    session.navigate(QStringLiteral("org"), orgId);
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    session.navigate(QStringLiteral("bogus"), orgId);
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    session.navigate(QStringLiteral("root"), QString());
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QCOMPARE(session.trail().size(), 1);
}

void TestCore::folderTreeExpandsCollapsesAndClears()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString spaceId = session.currentSpaceId();
    FolderTreeModel *folders = session.folderTree();
    QCOMPARE(folders->rowCount(), 1);
    QCOMPARE(tree(session, 0, FolderTreeModel::NameRole).toString(), QStringLiteral("Inbox"));
    QVERIFY(!tree(session, 0, FolderTreeModel::HasChildrenRole).toBool());
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    session.createHere(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    const QString b = entry(session, 0, EntryModel::EntryIdRole);
    session.runCommand(QStringLiteral("up"));
    session.createHere(QStringLiteral("C"));
    QVERIFY(waitFor(&session));

    QCOMPARE(folders->rowCount(), 4);
    QCOMPARE(tree(session, 0, FolderTreeModel::FolderIdRole).toString(), QString());
    QCOMPARE(tree(session, 0, FolderTreeModel::DepthRole).toInt(), 0);
    QVERIFY(tree(session, 0, FolderTreeModel::HasChildrenRole).toBool());
    QVERIFY(tree(session, 0, FolderTreeModel::ExpandedRole).toBool());
    QVERIFY(tree(session, 0, FolderTreeModel::CurrentRole).toBool());
    QCOMPARE(tree(session, 1, FolderTreeModel::FolderIdRole).toString(), a);
    QVERIFY(tree(session, 1, FolderTreeModel::ExpandedRole).toBool());
    QCOMPARE(tree(session, 2, FolderTreeModel::FolderIdRole).toString(), b);
    QCOMPARE(tree(session, 2, FolderTreeModel::DepthRole).toInt(), 2);
    QVERIFY(!tree(session, 2, FolderTreeModel::HasChildrenRole).toBool());
    QCOMPARE(tree(session, 3, FolderTreeModel::NameRole).toString(), QStringLiteral("C"));

    session.toggleFolder(a);
    QCOMPARE(folders->rowCount(), 3);
    QVERIFY(!tree(session, 1, FolderTreeModel::ExpandedRole).toBool());
    session.navigate(QStringLiteral("folder"), b);
    QCOMPARE(folders->rowCount(), 4);
    QVERIFY(tree(session, 2, FolderTreeModel::CurrentRole).toBool());
    QVERIFY(!tree(session, 0, FolderTreeModel::CurrentRole).toBool());
    session.toggleFolder(a);
    QCOMPARE(folders->rowCount(), 3);
    session.toggleFolder(a);
    QCOMPARE(folders->rowCount(), 4);
    session.toggleFolder(a);

    session.navigate(QStringLiteral("org"), session.currentOrgId());
    QCOMPARE(folders->rowCount(), 0);
    session.openEntry(QStringLiteral("space"), spaceId);
    QVERIFY(waitFor(&session));
    QCOMPARE(folders->rowCount(), 3);
    QVERIFY(!tree(session, 1, FolderTreeModel::ExpandedRole).toBool());
}

void TestCore::historyGoesBackAndForward()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(!session.canGoBack());
    QVERIFY(openInbox(core, session));
    const QString spaceId = session.currentSpaceId();
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    QVERIFY(session.canGoBack());
    QVERIFY(!session.canGoForward());
    session.runCommand(QStringLiteral("forward"));
    QCOMPARE(session.currentFolderId(), a);

    session.runCommand(QStringLiteral("back"));
    QCOMPARE(session.currentFolderId(), QString());
    QCOMPARE(session.currentSpaceId(), spaceId);
    QVERIFY(session.canGoForward());
    session.runCommand(QStringLiteral("back"));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    session.runCommand(QStringLiteral("back"));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QVERIFY(!session.canGoBack());
    session.runCommand(QStringLiteral("back"));
    QCOMPARE(session.level(), QStringLiteral("orgs"));

    session.runCommand(QStringLiteral("forward"));
    session.runCommand(QStringLiteral("forward"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.currentSpaceId(), spaceId);
    session.runCommand(QStringLiteral("forward"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.currentFolderId(), a);
    QVERIFY(!session.canGoForward());

    session.runCommand(QStringLiteral("back"));
    session.runCommand(QStringLiteral("back"));
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("root"), QString());
    QVERIFY(!session.canGoForward());
    session.runCommand(QStringLiteral("back"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
}

void TestCore::historyRestoresADeepLocation()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString spaceId = session.currentSpaceId();
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("root"), QString());
    QCOMPARE(session.folderTree()->rowCount(), 0);
    session.runCommand(QStringLiteral("back"));
    QCOMPARE(session.currentSpaceId(), spaceId);
    QCOMPARE(session.currentFolderId(), a);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.currentFolderId(), a);
    QCOMPARE(session.trail().size(), 4);
    QCOMPARE(session.folderTree()->rowCount(), 2);
    QVERIFY(tree(session, 1, FolderTreeModel::CurrentRole).toBool());
}

void TestCore::goUpClimbsEveryLevel()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    session.createHere(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("folder"), entry(session, 0, EntryModel::EntryIdRole));
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.currentFolderId(), a);
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.currentFolderId(), QString());
    QCOMPARE(session.level(), QStringLiteral("files"));
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QVERIFY(session.canGoBack());
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    session.runCommand(QStringLiteral("up"));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
}

void TestCore::createHereFollowsTheLevel()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.childKind(), QStringLiteral("org"));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New organization"));
    session.createHere(QStringLiteral("Acme"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->rowCount(), 2);
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    QCOMPARE(session.childKind(), QStringLiteral("space"));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New space"));
    session.createHere(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.spaces()->rowCount(), 1);
    QCOMPARE(session.level(), QStringLiteral("files"));
    QCOMPARE(session.childKind(), QStringLiteral("folder"));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 1);
}

void TestCore::acceptsOnlyDropsThatMove()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(!session.acceptsDrop(QString(), QStringLiteral("document:1:1")));
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    session.createHere(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    const QString b = entry(session, 0, EntryModel::EntryIdRole);
    session.runCommand(QStringLiteral("up"));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    const QString folderA = QStringLiteral("folder:%1:1").arg(a);
    const QString folderB = QStringLiteral("folder:%1:1").arg(b);
    const QString notes = entry(session, 1, EntryModel::PayloadRole);

    QVERIFY(!session.acceptsDrop(a, QStringLiteral("nope")));
    QVERIFY(!session.acceptsDrop(QString(), folderA)); // already there
    QVERIFY(!session.acceptsDrop(a, folderA));         // onto itself
    QVERIFY(!session.acceptsDrop(b, folderA));         // into its own child
    QVERIFY(!session.acceptsDrop(a, folderB));         // already there
    QVERIFY(session.acceptsDrop(QString(), folderB));
    QVERIFY(!session.acceptsDrop(QString(), notes));   // listed here
    QVERIFY(session.acceptsDrop(a, notes));
}

void TestCore::refreshAtTheRootStaysThere()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(waitFor(&session));
    session.runCommand(QStringLiteral("up"));
    QVERIFY(!session.lastOrgId().isEmpty());
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QCOMPARE(session.organizations()->rowCount(), 1);
}

void TestCore::keysReachEveryCommand()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(!session.handleKey(Qt::Key_Escape, Qt::NoModifier, false));
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    const QString doc = entry(session, 1, EntryModel::EntryIdRole);

    QSignalSpy keymap(&session, &Session::showKeymap);
    QSignalSpy sheet(&session, &Session::showSheet);
    QSignalSpy filter(&session, &Session::focusFilter);
    QSignalSpy make(&session, &Session::promptNew);
    QSignalSpy upload(&session, &Session::promptUpload);
    QSignalSpy rename(&session, &Session::promptRename);
    QSignalSpy saved(&session, &Session::downloadReady);

    QVERIFY(session.handleKey(Qt::Key_Question, Qt::ShiftModifier, false));
    QVERIFY(session.handleKey(Qt::Key_Slash, Qt::ShiftModifier, false));
    QVERIFY(!session.handleKey(Qt::Key_Slash, Qt::NoModifier, false));
    QVERIFY(!session.handleKey(Qt::Key_Question, Qt::NoModifier, true));
    QCOMPARE(keymap.size(), 2);
    QVERIFY(session.handleKey(Qt::Key_Colon, Qt::NoModifier, false));
    QVERIFY(session.handleKey(Qt::Key_Semicolon, Qt::ShiftModifier, false));
    QVERIFY(session.handleKey(Qt::Key_K, Qt::ControlModifier, true));
    QCOMPARE(sheet.size(), 3);
    QVERIFY(session.handleKey(Qt::Key_F, Qt::ControlModifier, true));
    QCOMPARE(filter.size(), 1);
    QSignalSpy region(&session, &Session::cycleRegion);
    QVERIFY(session.handleKey(Qt::Key_F6, Qt::NoModifier, true));
    QVERIFY(session.handleKey(Qt::Key_F6, Qt::ShiftModifier, false));
    QCOMPARE(region.size(), 2);
    QCOMPARE(region.at(0).at(0).toInt(), 1);
    QCOMPARE(region.at(1).at(0).toInt(), -1);
    session.runCommand(QStringLiteral("theme-dark"));
    session.runCommand(QStringLiteral("missing"));
    QVERIFY(session.handleKey(Qt::Key_N, Qt::NoModifier, false));
    QVERIFY(session.handleKey(Qt::Key_N, Qt::ControlModifier | Qt::ShiftModifier, true));
    QVERIFY(!session.handleKey(Qt::Key_N, Qt::ControlModifier, false));
    QCOMPARE(make.size(), 2);
    QVERIFY(session.handleKey(Qt::Key_U, Qt::NoModifier, false));
    QCOMPARE(upload.size(), 1);
    QVERIFY(!session.handleKey(Qt::Key_Q, Qt::NoModifier, false));

    QVERIFY(session.handleKey(Qt::Key_F5, Qt::NoModifier, false));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));
    QVERIFY(session.handleKey(Qt::Key_R, Qt::ControlModifier, true));
    QVERIFY(session.loading());
    QVERIFY(waitFor(&session));

    QVERIFY(!session.handleKey(Qt::Key_D, Qt::NoModifier, false));
    session.openEntry(QStringLiteral("document"), doc);
    QVERIFY(session.handleKey(Qt::Key_D, Qt::NoModifier, false));
    QVERIFY(waitFor(&session));
    QCOMPARE(saved.size(), 1);
    QVERIFY(saved.at(0).at(0).toUrl().isLocalFile());

    QVERIFY(!session.handleKey(Qt::Key_F2, Qt::NoModifier, false));
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    QVERIFY(session.handleKey(Qt::Key_F2, Qt::NoModifier, false));
    session.setFocusPayload(entry(session, 1, EntryModel::PayloadRole));
    QVERIFY(session.handleKey(Qt::Key_F2, Qt::NoModifier, false));
    QCOMPARE(rename.size(), 2);
    QCOMPARE(rename.at(0).at(0).toString(), QStringLiteral("A"));
    QCOMPARE(rename.at(1).at(0).toString(), QStringLiteral("Notes"));

    QVERIFY(!session.handleKey(Qt::Key_V, Qt::ControlModifier, false));
    QVERIFY(!session.handleKey(Qt::Key_X, Qt::ControlModifier, true));
    QVERIFY(session.handleKey(Qt::Key_X, Qt::ControlModifier, false));
    QVERIFY(session.hasClipboard());
    session.openEntry(QStringLiteral("folder"), a);
    QVERIFY(waitFor(&session));
    QVERIFY(session.handleKey(Qt::Key_V, Qt::ControlModifier, false));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 1);

    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    QVERIFY(!session.handleKey(Qt::Key_Z, Qt::ControlModifier, false));
    QVERIFY(session.handleKey(Qt::Key_Delete, Qt::NoModifier, false));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 0);
    QVERIFY(session.handleKey(Qt::Key_Z, Qt::ControlModifier, false));
    QTRY_COMPARE(session.documents()->rowCount(), 1);
    QVERIFY(waitFor(&session));

    QVERIFY(session.handleKey(Qt::Key_Left, Qt::AltModifier, true));
    QCOMPARE(session.currentFolderId(), QString());
    QVERIFY(session.handleKey(Qt::Key_Right, Qt::AltModifier, true));
    QCOMPARE(session.currentFolderId(), a);
    QVERIFY(!session.handleKey(Qt::Key_Right, Qt::AltModifier, true));
    QVERIFY(!session.handleKey(Qt::Key_Backspace, Qt::NoModifier, true));
    QVERIFY(session.handleKey(Qt::Key_Backspace, Qt::NoModifier, false));
    QCOMPARE(session.currentFolderId(), QString());
    QVERIFY(session.handleKey(Qt::Key_Up, Qt::AltModifier, true));
    QCOMPARE(session.level(), QStringLiteral("spaces"));
    QVERIFY(session.handleKey(Qt::Key_Escape, Qt::NoModifier, true));
    QCOMPARE(session.level(), QStringLiteral("orgs"));
    QVERIFY(!session.handleKey(Qt::Key_Escape, Qt::NoModifier, false));
}

void TestCore::commandsFollowTheLevel()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(usable(session, QStringLiteral("keymap")));
    QVERIFY(usable(session, QStringLiteral("theme-dark")));
    QVERIFY(!usable(session, QStringLiteral("new")));
    QVERIFY(!usable(session, QStringLiteral("sign-out")));
    QVERIFY(!usable(session, QStringLiteral("up")));
    QCOMPARE(command(session, QStringLiteral("up")).value(QStringLiteral("shortcut")).toString(),
             QStringLiteral("Backspace / Alt+Up / Esc"));
    QCOMPARE(command(session, QStringLiteral("keymap")).value(QStringLiteral("shortcut")).toString(),
             QStringLiteral("?"));
    QCOMPARE(command(session, QStringLiteral("purge")).value(QStringLiteral("shortcut")).toString(),
             QString());
    QCOMPARE(command(session, QStringLiteral("back")).value(QStringLiteral("title")).toString(),
             QStringLiteral("Back"));
    QVERIFY(!session.handleKey(Qt::Key_F5, Qt::NoModifier, false));

    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New organization"));
    for (const char *id : {"new", "refresh", "filter", "sign-out"})
        QVERIFY(usable(session, QString::fromLatin1(id)));
    for (const char *id : {"up", "back", "forward", "upload", "download", "cut", "paste", "rename",
                           "trash", "restore", "purge", "unknown"})
        QVERIFY(!usable(session, QString::fromLatin1(id)));

    session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(waitFor(&session));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New space"));
    QVERIFY(usable(session, QStringLiteral("up")));
    QVERIFY(usable(session, QStringLiteral("back")));
    QVERIFY(!usable(session, QStringLiteral("upload")));
    session.setFocusPayload(QStringLiteral("folder:1:1"));
    QVERIFY(!usable(session, QStringLiteral("rename")));

    session.createHere(QStringLiteral("Inbox"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.setFocusPayload(QString());
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New folder"));
    QVERIFY(usable(session, QStringLiteral("upload")));
    for (const char *id : {"download", "cut", "paste", "rename", "trash"})
        QVERIFY(!usable(session, QString::fromLatin1(id)));
    session.openEntry(QStringLiteral("document"), entry(session, 0, EntryModel::EntryIdRole));
    QVERIFY(usable(session, QStringLiteral("download")));
    QVERIFY(usable(session, QStringLiteral("trash")));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("title")).toString(),
             QStringLiteral("Move to trash"));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("icon")).toString(),
             QStringLiteral("trash"));
    QVERIFY(!usable(session, QStringLiteral("cut")));
    // A focused folder has nothing to download, even with a document open,
    // and no trash: it is deleted for good.
    session.setFocusPayload(QStringLiteral("folder:1:1"));
    QVERIFY(!usable(session, QStringLiteral("download")));
    QVERIFY(usable(session, QStringLiteral("trash")));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("title")).toString(),
             QStringLiteral("Delete folder"));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("icon")).toString(),
             QStringLiteral("purge"));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("icon")).toString(),
             QStringLiteral("new"));
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    QVERIFY(usable(session, QStringLiteral("cut")));
    QVERIFY(usable(session, QStringLiteral("rename")));
    session.runCommand(QStringLiteral("cut"));
    QVERIFY(usable(session, QStringLiteral("paste")));

    session.runCommand(QStringLiteral("theme-dark"));
    session.runCommand(QStringLiteral("unknown"));
    session.runCommand(QStringLiteral("sign-out"));
    QVERIFY(!session.signedIn());
}

void TestCore::renamesTrashesRestoresAndPurges()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    session.renameFocused(QStringLiteral("Archive"));
    QVERIFY(waitFor(&session));
    QCOMPARE(entry(session, 0, EntryModel::NameRole), QStringLiteral("Archive"));
    session.setFocusPayload(entry(session, 1, EntryModel::PayloadRole));
    session.renameFocused(QStringLiteral("Memo"));
    QVERIFY(waitFor(&session));
    QCOMPARE(entry(session, 1, EntryModel::NameRole), QStringLiteral("Memo"));
    session.renameFocused(QStringLiteral(" "));
    QCOMPARE(session.documents()->errorCode(), QStringLiteral("invalid_request"));
    session.setFocusPayload(QStringLiteral("nope"));
    session.renameFocused(QStringLiteral("x"));
    session.folders()->rename(entry(session, 0, EntryModel::EntryIdRole), QStringLiteral(" "), 1);
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("invalid_request"));

    session.runCommand(QStringLiteral("trash"));
    QVERIFY(session.lastTrashedId().isEmpty());
    QVERIFY(waitFor(&session));
    session.openEntry(QStringLiteral("document"), entry(session, 1, EntryModel::EntryIdRole));
    session.runCommand(QStringLiteral("trash"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->rowCount(), 0);
    session.runCommand(QStringLiteral("purge"));
    QTRY_VERIFY(session.lastTrashedId().isEmpty());
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 0);
    session.runCommand(QStringLiteral("restore"));
    session.runCommand(QStringLiteral("purge"));

    // A folder asks first, then goes for good and leaves nothing to restore.
    QSignalSpy asked(&session, &Session::promptDelete);
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    session.runCommand(QStringLiteral("trash"));
    QCOMPARE(asked.size(), 1);
    QCOMPARE(asked.at(0).at(0).toString(), QStringLiteral("Archive"));
    QCOMPARE(session.folders()->rowCount(), 1);
    session.deleteFocusedFolder();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 0);
    QVERIFY(session.lastTrashedId().isEmpty());
    QVERIFY(!usable(session, QStringLiteral("restore")));
    QVERIFY(!usable(session, QStringLiteral("purge")));

    core.seedDocument(session.currentSpaceId(), QStringLiteral("Draft"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    session.runCommand(QStringLiteral("trash"));
    QVERIFY(waitFor(&session));
    QCOMPARE(asked.size(), 1);
    QVERIFY(usable(session, QStringLiteral("restore")));
    session.runCommand(QStringLiteral("restore"));
    QTRY_COMPARE(session.documents()->rowCount(), 1);
    QVERIFY(waitFor(&session));
    QVERIFY(session.lastTrashedId().isEmpty());
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 0);

    // Del while the list loads trashes nothing and offers no restore.
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    session.documents()->reload();
    session.runCommand(QStringLiteral("trash"));
    QVERIFY(session.lastTrashedId().isEmpty());
    QVERIFY(waitFor(&session));
    QVERIFY(session.lastTrashedId().isEmpty());
    QVERIFY(!usable(session, QStringLiteral("restore")));
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 0);

    session.runCommand(QStringLiteral("trash"));
    QVERIFY(waitFor(&session));
    QVERIFY(usable(session, QStringLiteral("restore")));
    core.forcedStatus = 404;
    core.forcedError = QStringLiteral("not_found");
    session.runCommand(QStringLiteral("restore"));
    QTRY_COMPARE(session.documents()->errorCode(), QStringLiteral("not_found"));
    core.forcedStatus = 403;
    core.forcedError = QStringLiteral("forbidden");
    session.runCommand(QStringLiteral("purge"));
    QTRY_COMPARE(session.documents()->errorCode(), QStringLiteral("forbidden"));
    QVERIFY(!session.lastTrashedId().isEmpty());

    // Changed in the trash elsewhere: Core refuses the stale revision, and
    // there is nothing left to restore.
    core.forcedStatus = 0;
    core.changeTrashedElsewhere(QStringLiteral("Draft"));
    session.runCommand(QStringLiteral("restore"));
    QTRY_COMPARE(session.documents()->errorCode(), QStringLiteral("revision_conflict"));
    QVERIFY(session.lastTrashedId().isEmpty());
    QVERIFY(!usable(session, QStringLiteral("restore")));
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 1);
}

// Every file goes up in turn and lands with its bytes; one that cannot be
// read or that a step refuses is named, and the rest still land.
void TestCore::uploadsAQueue()
{
    FakeCore core;
    QVERIFY(core.listen());
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const auto write = [&dir](const QString &name, const QByteArray &bytes) {
        QFile file(dir.filePath(name));
        if (file.open(QIODevice::WriteOnly))
            file.write(bytes);
        return QUrl::fromLocalFile(file.fileName());
    };
    const QUrl hello = write(QStringLiteral("hello.txt"), "hello world");
    const QUrl notes = write(QStringLiteral("notes.txt"), "some notes");
    Session session;
    session.uploadUrls({hello});
    QVERIFY(!session.uploadBusy());
    QVERIFY(openInbox(core, session));

    session.uploadUrls({QUrl(QStringLiteral("https://example.com/x")), hello, notes});
    QVERIFY(session.uploadBusy());
    QCOMPARE(session.uploadIndex(), 1);
    QCOMPARE(session.uploadCount(), 2);
    QCOMPARE(session.uploadError(), QStringLiteral("unreadable"));
    QCOMPARE(session.uploadErrorName(), QStringLiteral("x"));
    session.upload(QStringLiteral("late.txt"), "late");
    QCOMPARE(session.uploadCount(), 3);
    QTRY_COMPARE(session.uploadIndex(), 2);
    QTRY_VERIFY(!session.uploadBusy());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.uploadIndex(), 0);
    QCOMPARE(session.uploadCount(), 0);
    QCOMPARE(session.uploadProgress(), 0.0);
    QCOMPARE(session.entryCount(), 3);
    QCOMPARE(core.landed(QStringLiteral("hello.txt")), FakeCore::sha256("hello world"));
    QCOMPARE(core.landed(QStringLiteral("notes.txt")), FakeCore::sha256("some notes"));
    QCOMPARE(core.landed(QStringLiteral("late.txt")), FakeCore::sha256("late"));
    // A completed upload is the document's first ready version, none pending.
    const QJsonObject landed = core.documentTitled(QStringLiteral("hello.txt"));
    const QJsonObject version = landed.value(QStringLiteral("current_version")).toObject();
    QCOMPARE(version.value(QStringLiteral("version_number")).toInt(), 1);
    QCOMPARE(version.value(QStringLiteral("state")).toString(), QStringLiteral("ready"));
    QVERIFY(version.value(QStringLiteral("current")).toBool());
    QCOMPARE(version.value(QStringLiteral("filename")).toString(), QStringLiteral("hello.txt"));
    QCOMPARE(version.value(QStringLiteral("byte_size")).toInt(), 11);
    QCOMPARE(version.value(QStringLiteral("checksum_sha256")).toString(), FakeCore::sha256("hello world"));
    QVERIFY(landed.value(QStringLiteral("pending_version_id")).isNull());
    QCOMPARE(session.uploadError(), QStringLiteral("unreadable"));

    // A step that fails ends that file with its reason; a new batch starts clean.
    const struct {
        const char *name;
        const char *method;
        const char *path;
        FakeCore::FaultMode mode;
        int status;
        const char *error;
        const char *code;
        int count;
    } steps[] = {
            {"server.txt", "POST", "/documents$", FakeCore::FaultMode::Status, 500, "", "server", 1},
            {"empty.txt", "POST", "/documents$", FakeCore::FaultMode::Status, 201, "", "invalid_request", 1},
            {"forbidden.txt", "POST", "/uploads$", FakeCore::FaultMode::Status, 403, "forbidden", "forbidden", 1},
            // Qt sends an idempotent request once more when the connection drops.
            {"dropped.txt", "PUT", "^/files/", FakeCore::FaultMode::Drop, 0, "", "network", 2},
    };
    for (const auto &step : steps) {
        QVERIFY(core.failNext(QLatin1String(step.method), QLatin1String(step.path), step.count, step.mode,
                              step.status, QLatin1String(step.error)));
        session.upload(QLatin1String(step.name), "bad");
        QTRY_VERIFY(!session.uploadBusy());
        QCOMPARE(session.uploadError(), QLatin1String(step.code));
        QCOMPARE(session.uploadErrorName(), QLatin1String(step.name));
        QCOMPARE(core.state().value(QStringLiteral("faults")).toArray().size(), 0);
    }
    // A name the place already holds, in any case, is refused before any bytes move.
    session.upload(QStringLiteral("HELLO.txt"), "again");
    QTRY_VERIFY(!session.uploadBusy());
    QCOMPARE(session.uploadError(), QStringLiteral("name_conflict"));
    QCOMPARE(core.landed(QStringLiteral("hello.txt")), FakeCore::sha256("hello world"));
    // Stored bytes that differ from the checksum declared at creation fail
    // completion.
    QVERIFY(core.failNext(QStringLiteral("PUT"), QStringLiteral("^/files/"), 1, FakeCore::FaultMode::Hold));
    session.upload(QStringLiteral("tampered.txt"), "bad");
    QTRY_COMPARE(core.held(), 1);
    QNetworkAccessManager storage;
    QNetworkReply *tamper = storage.put(QNetworkRequest(QUrl(core.url() + core.lastPath())), "tampered");
    QTRY_VERIFY(tamper->isFinished());
    tamper->deleteLater();
    core.release();
    QTRY_VERIFY(!session.uploadBusy());
    QCOMPARE(session.uploadError(), QStringLiteral("verification_failed"));
    QCOMPARE(session.uploadErrorName(), QStringLiteral("tampered.txt"));
    // Uploads that never completed leave their documents without a version,
    // pending while their session is open.
    int pending = 0;
    for (const char *title : {"forbidden.txt", "dropped.txt", "tampered.txt"}) {
        const QJsonObject doc = core.documentTitled(QLatin1String(title));
        QVERIFY(doc.value(QStringLiteral("current_version")).isNull());
        pending += doc.value(QStringLiteral("pending_version_id")).isString();
    }
    QCOMPARE(pending, 2);
    session.upload(QStringLiteral("good.txt"), "good");
    QCOMPARE(session.uploadError(), QString());
    QTRY_VERIFY(!session.uploadBusy());
    session.navigate(QStringLiteral("folder"), QString());
    QCOMPARE(session.uploadError(), QString());

    // The session ends mid-upload: the queue goes with it and later replies
    // change nothing.
    QVERIFY(core.failNext(QStringLiteral("POST"), QStringLiteral("/documents$"), 1,
                          FakeCore::FaultMode::Expire));
    QVERIFY(core.failNext(QStringLiteral("POST"), QStringLiteral("^/api/auth/refresh$"), 1,
                          FakeCore::FaultMode::Status, 401, QStringLiteral("invalid_refresh_token")));
    session.upload(QStringLiteral("gone.txt"), "gone");
    session.upload(QStringLiteral("queued.txt"), "queued");
    QTRY_VERIFY(!session.signedIn());
    QCOMPARE(session.errorCode(), QStringLiteral("session_expired"));
    QVERIFY(!session.uploadBusy());
    QCOMPARE(session.uploadCount(), 0);
    QVERIFY(core.documentTitled(QStringLiteral("queued.txt")).isEmpty());
}

// The e2e suites drive FakeCore over HTTP: reset, seed, faults, and state.
void TestCore::fakeCoreTakesControlOverHttp()
{
    FakeCore core;
    QVERIFY(core.listen());
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    Client::Reply reply;
    const auto call = [&](const QByteArray &method, const QString &path, const QJsonObject &body = {}) {
        bool finished = false;
        const auto done = [&](const Client::Reply &value) {
            finished = true;
            reply = value;
        };
        if (method == "GET")
            client.get(path, done);
        else
            client.post(path, body, done);
        return QTest::qWaitFor([&] { return finished; });
    };
    const QJsonObject spec = QJsonDocument::fromJson(R"({
        "users": [{"email": "ada@localhost", "password": "lovelace1"}],
        "organizations": [{"name": "Acme 日本", "user": "ada@localhost", "spaces": [{
            "name": "Inbox",
            "folders": [{"name": "Box", "repeat": 2,
                         "documents": [{"title": "inner", "content": "abc"}]}],
            "documents": [{"title": "Row", "repeat": 3}]}]}]})").object();
    QVERIFY(call("POST", QStringLiteral("/__e2e/seed"), spec));
    QVERIFY(reply.ok);
    QCOMPARE(reply.json.value(QStringLiteral("users")).toArray().size(), 2);
    QCOMPARE(reply.json.value(QStringLiteral("folders")).toArray().size(), 2);
    const QJsonArray documents = reply.json.value(QStringLiteral("documents")).toArray();
    QCOMPARE(documents.size(), 5);
    QCOMPARE(documents.at(0).toObject().value(QStringLiteral("content_sha256")), FakeCore::sha256("abc"));
    const QJsonObject seeded = documents.at(0).toObject().value(QStringLiteral("current_version")).toObject();
    QCOMPARE(seeded.value(QStringLiteral("filename")), QStringLiteral("inner"));
    QCOMPARE(seeded.value(QStringLiteral("byte_size")), 3);
    QCOMPARE(seeded.value(QStringLiteral("checksum_sha256")), FakeCore::sha256("abc"));
    QVERIFY(documents.at(4).toObject().value(QStringLiteral("current_version")).isNull());
    QCOMPARE(documents.at(4).toObject().value(QStringLiteral("title")), QStringLiteral("Row 003"));
    QVERIFY(documents.at(4).toObject().value(QStringLiteral("content_sha256")).isNull());
    const QJsonObject org = reply.json.value(QStringLiteral("organizations")).toArray().at(0).toObject();
    QCOMPARE(org.value(QStringLiteral("name")), QStringLiteral("Acme 日本"));
    QCOMPARE(org.value(QStringLiteral("user")), QStringLiteral("ada@localhost"));

    QVERIFY(call("POST", QStringLiteral("/__e2e/fail"),
                 {{QStringLiteral("path"), QStringLiteral("^/api/auth/login$")},
                  {QStringLiteral("mode"), QStringLiteral("drop")}}));
    QCOMPARE(reply.json.value(QStringLiteral("faults")).toArray().size(), 1);
    const QJsonObject ada{{QStringLiteral("email"), QStringLiteral("ada@localhost")},
                          {QStringLiteral("password"), QStringLiteral("lovelace1")}};
    QVERIFY(call("POST", QStringLiteral("/api/auth/login"), ada));
    QCOMPARE(reply.code, QStringLiteral("network"));
    QVERIFY(call("POST", QStringLiteral("/api/auth/login"), ada));
    QVERIFY(reply.ok);
    client.setAccessToken(reply.json.value(QStringLiteral("access_token")).toString());

    QVERIFY(call("POST", QStringLiteral("/__e2e/fail"),
                 {{QStringLiteral("method"), QStringLiteral("get")},
                  {QStringLiteral("path"), QStringLiteral("^/api/v1/organizations$")},
                  {QStringLiteral("mode"), QStringLiteral("expire")},
                  {QStringLiteral("count"), 2}}));
    for (int i = 0; i < 2; ++i) {
        QVERIFY(call("GET", QStringLiteral("/api/v1/organizations")));
        QCOMPARE(reply.code, QStringLiteral("unauthenticated"));
    }
    QVERIFY(call("POST", QStringLiteral("/__e2e/fail"),
                 {{QStringLiteral("path"), QStringLiteral("^/api/v1/organizations$")},
                  {QStringLiteral("status"), 503}}));
    QVERIFY(call("GET", QStringLiteral("/api/v1/organizations")));
    QCOMPARE(reply.code, QStringLiteral("server"));
    QVERIFY(call("GET", QStringLiteral("/api/v1/organizations")));
    QVERIFY(reply.ok);
    QCOMPARE(reply.json.value(QStringLiteral("organizations")).toArray().size(), 2);
    for (const QJsonObject &bad : {QJsonObject{{QStringLiteral("path"), QStringLiteral("(")}},
                                   QJsonObject{{QStringLiteral("path"), QStringLiteral("x")},
                                               {QStringLiteral("mode"), QStringLiteral("melt")}},
                                   QJsonObject{}}) {
        QVERIFY(call("POST", QStringLiteral("/__e2e/fail"), bad));
        QCOMPARE(reply.code, QStringLiteral("invalid_fault"));
    }

    // A held answer waits for /__e2e/release; a reset drops it.
    int answered = 0;
    Client::Reply held;
    const auto hold = [&] {
        if (!call("POST", QStringLiteral("/__e2e/fail"),
                  {{QStringLiteral("path"), QStringLiteral("^/api/v1/organizations$")},
                   {QStringLiteral("mode"), QStringLiteral("hold")}}))
            return false;
        client.get(QStringLiteral("/api/v1/organizations"), [&](const Client::Reply &value) {
            ++answered;
            held = value;
        });
        return QTest::qWaitFor([&] { return core.held() == 1; });
    };
    QVERIFY(hold());
    QVERIFY(call("POST", QStringLiteral("/__e2e/release")));
    QCOMPARE(reply.json.value(QStringLiteral("held")).toInt(), 0);
    QTRY_COMPARE(answered, 1);
    QVERIFY(held.ok);
    QVERIFY(hold());
    QVERIFY(call("GET", QStringLiteral("/__e2e/state")));
    QCOMPARE(reply.json.value(QStringLiteral("held")).toInt(), 1);
    QCOMPARE(reply.json.value(QStringLiteral("user")), QStringLiteral("ada@localhost"));
    QVERIFY(reply.json.value(QStringLiteral("hits")).toInt() > 0);
    QVERIFY(call("GET", QStringLiteral("/__e2e/nope")));
    QCOMPARE(reply.code, QStringLiteral("not_found"));
    QVERIFY(call("POST", QStringLiteral("/__e2e/nope")));
    QCOMPARE(reply.code, QStringLiteral("not_found"));
    QVERIFY(call("POST", QStringLiteral("/__e2e/reset")));
    QCOMPARE(reply.json.value(QStringLiteral("documents")).toArray().size(), 0);
    QCOMPARE(reply.json.value(QStringLiteral("held")).toInt(), 0);
    // The dropped call is Qt's to retry, against the Core that started over.
    QTRY_COMPARE(answered, 2);

    // Signed URLs follow the host the client came by (10.0.2.2 on Android),
    // and a browser's preflight is answered for any origin. The open upload
    // is its document's pending version.
    const QJsonObject target = core.seed(spec).value(QStringLiteral("documents")).toArray().at(4).toObject();
    QNetworkAccessManager network;
    QNetworkRequest request(QUrl(core.url() + QStringLiteral("/api/v1/organizations/org-1/uploads")));
    request.setRawHeader("Host", "10.0.2.2:7011");
    request.setRawHeader("Authorization", "Bearer access-1");
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject body{{QStringLiteral("space_id"), target.value(QStringLiteral("space_id"))},
                     {QStringLiteral("document_id"), target.value(QStringLiteral("id"))}};
    const auto post = [&](const QNetworkRequest &to, const QJsonObject &json) {
        QNetworkReply *sent = network.post(to, QJsonDocument(json).toJson());
        return QTest::qWaitFor([sent] { return sent->isFinished(); }) ? sent : nullptr;
    };
    // Every POST under /api/v1/ carries a well-formed Idempotency-Key.
    QNetworkReply *refused = post(request, body);
    QVERIFY(refused);
    QCOMPARE(refused->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 428);
    QCOMPARE(QJsonDocument::fromJson(refused->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("idempotency_key_required"));
    request.setRawHeader("Idempotency-Key", QByteArray(129, 'k'));
    refused = post(request, body);
    QVERIFY(refused);
    QCOMPARE(refused->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 422);
    QCOMPARE(QJsonDocument::fromJson(refused->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("invalid_idempotency_key"));
    const auto key = idempotencyHeader().first();
    request.setRawHeader(key.first, key.second);
    // Creating an upload requires the file's checksum, well formed.
    refused = post(request, body);
    QVERIFY(refused);
    QCOMPARE(refused->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 422);
    QCOMPARE(QJsonDocument::fromJson(refused->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("checksum_required"));
    body.insert(QStringLiteral("checksum_sha256"), FakeCore::sha256("abc").toUpper());
    refused = post(request, body);
    QVERIFY(refused);
    QCOMPARE(QJsonDocument::fromJson(refused->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("invalid_checksum"));
    body.insert(QStringLiteral("checksum_sha256"), FakeCore::sha256("abc"));
    QNetworkReply *upload = post(request, body);
    QVERIFY(upload);
    QVERIFY(QJsonDocument::fromJson(upload->readAll())
                    .object().value(QStringLiteral("data")).toObject()
                    .value(QStringLiteral("request")).toObject()
                    .value(QStringLiteral("url")).toString()
                    .startsWith(QStringLiteral("http://10.0.2.2:7011/files/")));
    QVERIFY(core.documentTitled(target.value(QStringLiteral("title")).toString())
                    .value(QStringLiteral("pending_version_id")).isString());
    QNetworkRequest ask(QUrl(core.url() + QStringLiteral("/files/upl-1")));
    ask.setRawHeader("Access-Control-Request-Headers", "authorization");
    QNetworkReply *preflight = network.sendCustomRequest(ask, "OPTIONS");
    QTRY_VERIFY(preflight->isFinished());
    QCOMPARE(preflight->rawHeader("Access-Control-Allow-Origin"), QByteArray("*"));
    QCOMPARE(preflight->rawHeader("Access-Control-Allow-Headers"), QByteArray("authorization"));
    preflight->deleteLater();

    // Completion takes the session's generation and checks the stored bytes
    // against the checksum declared at creation.
    QNetworkReply *stored = network.put(QNetworkRequest(QUrl(core.url() + QStringLiteral("/files/upl-1"))), "abd");
    QTRY_VERIFY(stored->isFinished());
    request.setUrl(QUrl(core.url() + QStringLiteral("/api/v1/organizations/org-1/uploads/upl-1/complete")));
    QNetworkReply *completed = post(request, {{QStringLiteral("generation"), 2}});
    QVERIFY(completed);
    QCOMPARE(completed->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 409);
    QCOMPARE(QJsonDocument::fromJson(completed->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("stale_upload_generation"));
    completed = post(request, {{QStringLiteral("generation"), 1}});
    QVERIFY(completed);
    QCOMPARE(completed->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 422);
    QCOMPARE(QJsonDocument::fromJson(completed->readAll()).object().value(QStringLiteral("error")),
             QStringLiteral("verification_failed"));
    stored = network.put(QNetworkRequest(QUrl(core.url() + QStringLiteral("/files/upl-1"))), "abc");
    QTRY_VERIFY(stored->isFinished());
    completed = post(request, {{QStringLiteral("generation"), 1}});
    QVERIFY(completed);
    QCOMPARE(completed->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 200);
    QCOMPARE(core.landed(target.value(QStringLiteral("title")).toString()), FakeCore::sha256("abc"));
}

// FakeCore holds Core's naming rule: the folders and live documents of one
// parent hold distinct names after NFC, trimming and lowercasing, stored
// NFC and trimmed; every route that places a name refuses an unusable one
// (422 invalid_name) and a held one (409 name_conflict). Every route that
// changes a folder or document refuses an If-Match other than the revision
// it holds (409 revision_conflict). A folder is deleted for good, and only
// once it holds no folder and no document, trashed ones included (409
// non_empty_resource); the trash holds documents only.
void TestCore::fakeCoreKeepsNamesAndRevisions()
{
    FakeCore core;
    QVERIFY(core.listen());
    core.seed(QJsonDocument::fromJson(R"({"organizations": [{"name": "Acme", "spaces": [{
        "name": "Inbox", "folders": [{"name": "Box"}]}]}]})").object());
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    client.setAccessToken(QStringLiteral("access-1"));
    const QString space = QStringLiteral("/api/v1/organizations/org-1/spaces/space-1/");
    Client::Reply reply;
    // The revision FakeCore holds for the folder, document, or trashed
    // document `path` names; 0 when it names none.
    const auto stored = [&](const QString &path) {
        const QString itemId = path.startsWith(QLatin1Char('/')) ? path.section(QLatin1Char('/'), -2, -2)
                                                                  : path.section(QLatin1Char('/'), 1, 1);
        const QJsonObject held = core.state();
        for (const QString &kind : {QStringLiteral("folders"), QStringLiteral("documents"), QStringLiteral("trash")}) {
            for (const QJsonValue &value : held.value(kind).toArray()) {
                if (value.toObject().value(QStringLiteral("id")).toString() == itemId)
                    return value.toObject().value(QStringLiteral("revision")).toInt();
            }
        }
        return 0;
    };
    const auto send = [&](const QByteArray &method, const QString &path, const QJsonObject &body,
                          const Client::Headers &headers) {
        bool finished = false;
        const auto done = [&](const Client::Reply &value) {
            finished = true;
            reply = value;
        };
        if (method == "PATCH")
            client.patch(space + path, body, done, headers);
        else if (method == "DELETE")
            client.del(space + path, done, headers);
        else
            client.post(path.startsWith(QLatin1Char('/')) ? path : space + path, body, done, headers);
        return QTest::qWaitFor([&] { return finished; });
    };
    // Sends If-Match `behind` revisions before the one FakeCore holds.
    const auto call = [&](const QByteArray &method, const QString &path, const QJsonObject &body = {},
                          int behind = 0) {
        return send(method, path, body, idempotentMatchHeader(stored(path) - behind));
    };
    const auto id = [&](const char *kind) {
        return reply.json.value(QLatin1String(kind)).toObject().value(QStringLiteral("id")).toString();
    };
    const auto refuses = [&](const QByteArray &method, const QString &path, const QJsonObject &body,
                             int status, const QString &code) {
        return call(method, path, body) && reply.status == status && reply.code == code;
    };
    const auto restore = [](const QString &documentId) {
        return QStringLiteral("/api/v1/organizations/org-1/trash/%1/restore").arg(documentId);
    };
    const auto purge = [](const QString &documentId) {
        return QStringLiteral("/api/v1/organizations/org-1/trash/%1/purge").arg(documentId);
    };

    for (const QString &name : {QString(), QStringLiteral("  "), QStringLiteral("."), QStringLiteral(" .. "),
                                QStringLiteral("a/b"), QStringLiteral("a\\b"), QStringLiteral("a\x01"),
                                QStringLiteral("\x7f")}) {
        QVERIFY(refuses("POST", QStringLiteral("folders"), {{QStringLiteral("name"), name}}, 422,
                        QStringLiteral("invalid_name")));
        QVERIFY(refuses("POST", QStringLiteral("documents"), {{QStringLiteral("title"), name}}, 422,
                        QStringLiteral("invalid_name")));
    }

    // Stored NFC and trimmed; a folder and a document collide across case
    // and normal form.
    QVERIFY(call("POST", QStringLiteral("folders"), {{QStringLiteral("name"), QStringLiteral("  Cafe\u0301 ")}}));
    QCOMPARE(reply.status, 201);
    QCOMPARE(reply.json.value(QStringLiteral("folder")).toObject().value(QStringLiteral("name")),
             QStringLiteral("Caf\u00e9"));
    const QString cafe = id("folder");
    QVERIFY(refuses("POST", QStringLiteral("documents"), {{QStringLiteral("title"), QStringLiteral("CAF\u00c9")}},
                    409, QStringLiteral("name_conflict")));
    QVERIFY(refuses("POST", QStringLiteral("folders"), {{QStringLiteral("name"), QStringLiteral("box")}}, 409,
                    QStringLiteral("name_conflict")));

    // Another parent is another namespace.
    QVERIFY(call("POST", QStringLiteral("documents"),
                 {{QStringLiteral("title"), QStringLiteral("Box")}, {QStringLiteral("folder_id"), cafe}}));
    QCOMPARE(reply.status, 201);
    const QString boxDocument = id("document");

    // Renames: never onto a held name, always onto the entry's own.
    QVERIFY(refuses("PATCH", QStringLiteral("folders/") + cafe, {{QStringLiteral("name"), QStringLiteral("BOX")}},
                    409, QStringLiteral("name_conflict")));
    QVERIFY(refuses("PATCH", QStringLiteral("folders/") + cafe, {{QStringLiteral("name"), QStringLiteral("..")}},
                    422, QStringLiteral("invalid_name")));
    QVERIFY(call("PATCH", QStringLiteral("folders/") + cafe, {{QStringLiteral("name"), QStringLiteral("caf\u00e9 ")}}));
    QVERIFY(reply.ok);
    QCOMPARE(reply.json.value(QStringLiteral("folder")).toObject().value(QStringLiteral("name")),
             QStringLiteral("caf\u00e9"));
    QVERIFY(refuses("PATCH", QStringLiteral("documents/") + boxDocument,
                    {{QStringLiteral("title"), QStringLiteral("a/b")}}, 422, QStringLiteral("invalid_name")));
    QVERIFY(refuses("PATCH", QStringLiteral("documents/nope"), {{QStringLiteral("title"), QStringLiteral("x")}},
                    404, QStringLiteral("not_found")));

    // Moves: the destination parent decides.
    QVERIFY(refuses("POST", QStringLiteral("documents/%1/move").arg(boxDocument), {}, 409,
                    QStringLiteral("name_conflict")));
    QVERIFY(refuses("POST", QStringLiteral("folders/folder-1/move"), {{QStringLiteral("parent_id"), cafe}}, 409,
                    QStringLiteral("name_conflict")));
    QVERIFY(refuses("POST", QStringLiteral("folders/nope/move"), {}, 404, QStringLiteral("not_found")));
    QVERIFY(refuses("POST", QStringLiteral("documents/nope/move"), {}, 404, QStringLiteral("not_found")));
    QCOMPARE(core.state().value(QStringLiteral("folders")).toArray().at(0).toObject()
                     .value(QStringLiteral("parent_id")), QJsonValue(QJsonValue::Null));

    // A trashed document is outside the namespace: its name is free, and
    // taking it keeps the trashed one from coming back until it frees again.
    QVERIFY(call("POST", QStringLiteral("documents"), {{QStringLiteral("title"), QStringLiteral("Draft")}}));
    const QString draft = id("document");
    QVERIFY(call("DELETE", QStringLiteral("documents/") + draft));
    QCOMPARE(reply.json.value(QStringLiteral("document")).toObject().value(QStringLiteral("revision")).toInt(), 2);
    QCOMPARE(stored(restore(draft)), 2);
    QVERIFY(call("POST", QStringLiteral("documents"), {{QStringLiteral("title"), QStringLiteral("draft")}}));
    QCOMPARE(reply.status, 201);
    const QString taker = id("document");
    QVERIFY(refuses("POST", restore(draft), {}, 409, QStringLiteral("name_conflict")));
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 1);
    // Restore and purge name the trashed revision.
    for (const QString &path : {restore(draft), purge(draft)}) {
        QVERIFY(send("POST", path, {}, idempotencyHeader()));
        QCOMPARE(reply.status, 422);
        QCOMPARE(reply.code, QStringLiteral("revision_required"));
        QVERIFY(call("POST", path, {}, 1));
        QCOMPARE(reply.code, QStringLiteral("revision_conflict"));
    }
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 1);
    QVERIFY(call("PATCH", QStringLiteral("documents/") + taker, {{QStringLiteral("title"), QStringLiteral("Draft 2")}}));
    QVERIFY(reply.ok);
    QVERIFY(call("POST", restore(draft)));
    QVERIFY(reply.ok);
    QCOMPARE(core.documentTitled(QStringLiteral("Draft")).value(QStringLiteral("folder_id")),
             QJsonValue(QJsonValue::Null));

    // A revision behind changes nothing.
    for (const QString &target : {QStringLiteral("folders/") + cafe, QStringLiteral("documents/") + boxDocument}) {
        const int held = stored(target);
        for (const auto &[method, path] : {std::pair{QByteArray("PATCH"), target},
                                           std::pair{QByteArray("DELETE"), target},
                                           std::pair{QByteArray("POST"), target + QStringLiteral("/move")}}) {
            QVERIFY(call(method, path, {{QStringLiteral("name"), QStringLiteral("Fresh")},
                                        {QStringLiteral("title"), QStringLiteral("Fresh")}}, 1));
            QCOMPARE(reply.code, QStringLiteral("revision_conflict"));
        }
        QCOMPARE(stored(target), held);
    }

    const auto folderNames = [&] {
        QStringList names;
        for (const QJsonValue &value : core.state().value(QStringLiteral("folders")).toArray())
            names.append(value.toObject().value(QStringLiteral("name")).toString());
        return names;
    };
    QVERIFY(refuses("DELETE", QStringLiteral("folders/") + cafe, {}, 409, QStringLiteral("non_empty_resource")));
    QVERIFY(call("DELETE", QStringLiteral("documents/") + boxDocument));
    QVERIFY(refuses("DELETE", QStringLiteral("folders/") + cafe, {}, 409, QStringLiteral("non_empty_resource")));
    QVERIFY(call("POST", QStringLiteral("folders"), {{QStringLiteral("name"), QStringLiteral("Outer")}}));
    const QString outer = id("folder");
    QVERIFY(call("POST", QStringLiteral("folders"),
                 {{QStringLiteral("name"), QStringLiteral("Inner")}, {QStringLiteral("parent_id"), outer}}));
    const QString inner = id("folder");
    QVERIFY(refuses("DELETE", QStringLiteral("folders/") + outer, {}, 409, QStringLiteral("non_empty_resource")));
    QVERIFY(call("DELETE", QStringLiteral("folders/") + inner));
    QCOMPARE(reply.status, 204);
    QVERIFY(call("DELETE", QStringLiteral("folders/") + outer));
    QCOMPARE(reply.status, 204);
    QVERIFY(!folderNames().contains(QStringLiteral("Outer")));
    QCOMPARE(core.state().value(QStringLiteral("trash")).toArray().size(), 1);
    QVERIFY(refuses("POST", restore(outer), {}, 404, QStringLiteral("not_found")));
    QVERIFY(refuses("POST", purge(outer), {}, 404, QStringLiteral("not_found")));
    QVERIFY(refuses("DELETE", QStringLiteral("folders/") + outer, {}, 404, QStringLiteral("not_found")));
}

void TestCore::modelsReportFailures()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.organizations()->reload();
    session.spaces()->reload();
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("A"));
    QVERIFY(waitFor(&session));
    const QString a = entry(session, 0, EntryModel::EntryIdRole);
    session.openEntry(QStringLiteral("folder"), a);
    session.createHere(QStringLiteral("B"));
    QVERIFY(waitFor(&session));
    const QString b = entry(session, 0, EntryModel::EntryIdRole);
    QCOMPARE(session.folders()->index(0).data(FolderModel::ParentIdRole).toString(), a);
    QCOMPARE(session.folders()->index(0).data(Qt::DisplayRole), QVariant());
    session.runCommand(QStringLiteral("up"));
    session.dropPayload(QString(), QStringLiteral("folder:%1:1").arg(b));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->rowCount(), 2);
    session.folders()->remove(QString(), 1);
    session.documents()->trash(QString(), 1);

    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QSignalSpy saved(&session, &Session::downloadReady);
    session.documents()->download(session.documents()->index(0).data(DocumentModel::DocumentIdRole).toString());
    QVERIFY(waitFor(&session));
    QCOMPARE(saved.size(), 1);
    QVERIFY(saved.at(0).at(0).toUrl().toLocalFile().endsWith(QStringLiteral("/Notes")));

    core.renameElsewhere(QStringLiteral("A"), QStringLiteral("A2"));
    session.folders()->rename(a, QStringLiteral("C"), 1);
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("revision_conflict"));
    QCOMPARE(session.folders()->nameOf(a), QStringLiteral("A2"));
    const QString notes = session.documents()->index(0).data(DocumentModel::DocumentIdRole).toString();
    core.renameElsewhere(QStringLiteral("Notes"), QStringLiteral("Notes 2"));
    session.documents()->rename(notes, QStringLiteral("C"), session.documents()->revisionOf(notes));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->errorCode(), QStringLiteral("revision_conflict"));
    QCOMPARE(session.documents()->titleOf(notes), QStringLiteral("Notes 2"));

    core.forcedStatus = 500;
    core.forcedError = QStringLiteral("server_error");
    session.createHere(QStringLiteral("C"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.folders()->errorCode(), QStringLiteral("server"));
    session.documents()->reload();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.documents()->errorCode(), QStringLiteral("server"));
    session.spaces()->create(QStringLiteral("C"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.spaces()->errorCode(), QStringLiteral("server"));
    session.spaces()->reload();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.spaces()->errorCode(), QStringLiteral("server"));
    session.organizations()->create(QStringLiteral("C"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->errorCode(), QStringLiteral("server"));
    session.organizations()->reload();
    QVERIFY(waitFor(&session));
    QCOMPARE(session.organizations()->errorCode(), QStringLiteral("server"));
}

namespace {

// Stands in for a compiled catalogue: a few words in Portuguese.
class Portuguese : public QTranslator
{
public:
    bool isEmpty() const override { return false; }
    QString translate(const char *context, const char *source, const char *, int) const override
    {
        const QByteArray key = QByteArray(context) + '|' + source;
        if (key == "matome::Session|Keyboard map")
            return QStringLiteral("Mapa do teclado");
        if (key == "matome::Session|New organization")
            return QStringLiteral("Nova organização");
        if (key == "matome::EntryModel|owner")
            return QStringLiteral("proprietário");
        return {};
    }
};

} // namespace

// Command titles, the root crumb, and Core's words are read through the
// translator, so installing one retitles them without a restart. Language
// commands name themselves and are the window's to carry out.
void TestCore::wordsFollowTheTranslator()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    core.seedOrganization(QStringLiteral("Guests"), QStringLiteral("steward"));
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(session.entryCount(), 2);
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QStringLiteral("owner"));
    QCOMPARE(entry(session, 1, EntryModel::DetailRole), QStringLiteral("steward"));
    QCOMPARE(command(session, QStringLiteral("keymap")).value(QStringLiteral("title")),
             QStringLiteral("Keyboard map"));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")),
             QStringLiteral("New organization"));
    QCOMPARE(command(session, QStringLiteral("lang-pt-BR")).value(QStringLiteral("title")),
             QStringLiteral("Português"));
    QCOMPARE(command(session, QStringLiteral("lang-ja")).value(QStringLiteral("title")),
             QStringLiteral("日本語"));
    QVERIFY(usable(session, QStringLiteral("lang-en")));
    session.runCommand(QStringLiteral("lang-ja"));
    QCOMPARE(session.trail().first().toMap().value(QStringLiteral("name")), QStringLiteral("Matome"));

    Portuguese portuguese;
    QSignalSpy changed(&session, &Session::changed);
    QVERIFY(QCoreApplication::installTranslator(&portuguese));
    QVERIFY(changed.count() > 0);
    QCOMPARE(command(session, QStringLiteral("keymap")).value(QStringLiteral("title")),
             QStringLiteral("Mapa do teclado"));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")),
             QStringLiteral("Nova organização"));
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QStringLiteral("proprietário"));
    QCOMPARE(entry(session, 1, EntryModel::DetailRole), QStringLiteral("steward"));
    QCOMPARE(command(session, QStringLiteral("lang-en")).value(QStringLiteral("title")),
             QStringLiteral("English"));

    QVERIFY(QCoreApplication::removeTranslator(&portuguese));
    QCOMPARE(command(session, QStringLiteral("keymap")).value(QStringLiteral("title")),
             QStringLiteral("Keyboard map"));
    QCOMPARE(entry(session, 0, EntryModel::DetailRole), QStringLiteral("owner"));
}

QTEST_GUILESS_MAIN(TestCore)
#include "tst_core.moc"
