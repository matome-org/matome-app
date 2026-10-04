#include "Client.h"
#include "FakeCore.h"
#include "JsonList.h"
#include "Session.h"
#include "MockAddOnBackend.h"

#include <QCryptographicHash>
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
    void deleteCarriesItsBody();
    void logsInAgainstCore();
    void mapsWrongPassword();
    void registersAnAccount();
    void logsInWithUnconfirmedEmail();
    void carriesTheFieldsCoreRefused();
    void setsUpAManagedAccount();
    void sendsAResetAndSignsInWithNewPassword();
    void showsAnAcceptedInvitationAfterRefresh();
    void logsOut();
    void abortsAnInFlightCall();
    void mapsNotFound();
    void mapsForcedCoreErrors();
    void timesOutAHungCall();
    void retriesAShortRateLimit();
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
    void settingsAvailableWithoutAdminOrganization();
    void settingsSelectsOrganizationsAndDiscardsReplies();
    void addOnsUseMockBackend();
    void addOnsDiscardStaleMockReplies();
    void documentViewPreviewsAndSaves();
    void documentViewListsRelated();
    void controlledDocsExtendDocumentView();
    void controlledDocsRunParallelReviews();
    void controlledDocsCountApprovals();
    void controlledDocsSayCoreRefusals();
    void controlledDocsManageFromTheExplorer();
    void uploadsManagedWithReviews();
    void spaceSettingsManageAccessAndRule();
    void addOnAccessCountsRoleHolders();
    void accessDirectoryManagesGroupsRolesTagsAndSpaces();
    void accessGrantsCoverFoldersDocumentsAndTags();
    void accessGrantsStopInheritingAndExplain();
    void principalAccessListsPlacesAndRoles();
    void roleHoldersListAndAddPeople();
    void explorerFollowsTheSpaceCatalog();
    void permissionsExplainRefusals();
    void accessGrantsCountRestrictedTags();
    void markdownReferencesFollowAssetLinks();
    void assetsSearchFindsFilesByName();
    void assetsResolvePathLinks();
    void assetsUploadIntoAssetsFolder();
    void assetsSignThroughViaVersion();
    void uploadsFillBeforeCompleting();
    void orgBillingPermissionsAndStaleReplies();
    void orgBillingPreservesPurchasesAndGrants();
    void orgBillingConfiguresInstallation();
    void orgBillingSelectsVersionedPackages();
    void orgBillingExpiresCheckoutLinks();
    void orgBillingReportsPackageFailures();
    void orgAdminLoadsAndPreservesLocation();
    void orgAdminMutatesMembersAndInvitations();
    void orgAdminCreatesManagedMembers();
    void orgAdminGuardsLastOwnerAndReportsErrors();
    void orgAdminDiscardsStaleReplies();
    void orgAdminClosesWhenAdminAccessIsLost();
    void orgAdminRestrictsEntryAndPaginates();

private:
    // The directory of `org`: two members, a group holding the second, the
    // owner, space viewer and one custom role, a restricted tag, and a catalog
    // with one reserved action.
    static void seedDirectory(matome::test::MockAddOnBackend &backend, const QString &org)
    {
        const auto row = [](std::initializer_list<std::pair<QString, QJsonValue>> fields) {
            QJsonObject object;
            for (const auto &[key, value] : fields) object.insert(key, value);
            return object;
        };
        backend.respond("GET", matome::orgPath(org, QStringLiteral("members")), {{QStringLiteral("members"), QJsonArray{
            row({{QStringLiteral("id"), QStringLiteral("m1")}, {QStringLiteral("email"), QStringLiteral("ana@example.com")}, {QStringLiteral("roles"), QJsonArray{QStringLiteral("owner")}}}),
            row({{QStringLiteral("id"), QStringLiteral("m2")}, {QStringLiteral("email"), QStringLiteral("bo@example.com")}, {QStringLiteral("roles"), QJsonArray{QStringLiteral("member")}}})}}});
        backend.respond("GET", matome::orgPath(org, QStringLiteral("roles")), {{QStringLiteral("roles"), QJsonArray{
            row({{QStringLiteral("id"), QStringLiteral("owner-role")}, {QStringLiteral("key"), QStringLiteral("owner")}, {QStringLiteral("name"), QStringLiteral("Owner")},
                 {QStringLiteral("origin"), QStringLiteral("system")}, {QStringLiteral("actions"), QJsonArray{QStringLiteral("role.read")}}}),
            row({{QStringLiteral("id"), QStringLiteral("viewer-role")}, {QStringLiteral("key"), QStringLiteral("content_reader")}, {QStringLiteral("name"), QStringLiteral("Content reader")},
                 {QStringLiteral("origin"), QStringLiteral("system")}, {QStringLiteral("actions"), QJsonArray{QStringLiteral("content.download")}}}),
            row({{QStringLiteral("id"), QStringLiteral("custom-role")}, {QStringLiteral("key"), QStringLiteral("custom-1")}, {QStringLiteral("name"), QStringLiteral("Reviewers")},
                 {QStringLiteral("origin"), QStringLiteral("organization")},
                 {QStringLiteral("actions"), QJsonArray{QStringLiteral("addon.controlled_docs.review_read"), QStringLiteral("role.read")}}})}}});
        backend.respond("GET", matome::orgPath(org, QStringLiteral("tags")), {{QStringLiteral("tags"), QJsonArray{
            row({{QStringLiteral("id"), QStringLiteral("t1")}, {QStringLiteral("name"), QStringLiteral("Secret")}, {QStringLiteral("access_controlled"), true},
                 {QStringLiteral("revision"), 1}})}}});
        backend.respond("GET", matome::orgPath(org, QStringLiteral("action-catalog")), {{QStringLiteral("actions"), QJsonArray{
            row({{QStringLiteral("key"), QStringLiteral("content.download")}, {QStringLiteral("axis"), QStringLiteral("space")}, {QStringLiteral("system_only"), false}}),
            row({{QStringLiteral("key"), QStringLiteral("addon.controlled_docs.review_read")}, {QStringLiteral("axis"), QStringLiteral("space")}, {QStringLiteral("system_only"), false},
                 {QStringLiteral("product_key"), QStringLiteral("controlled_docs")}}),
            row({{QStringLiteral("key"), QStringLiteral("role.read")}, {QStringLiteral("axis"), QStringLiteral("organization")}, {QStringLiteral("system_only"), false}}),
            row({{QStringLiteral("key"), QStringLiteral("organization.transfer_ownership")}, {QStringLiteral("axis"), QStringLiteral("organization")},
                 {QStringLiteral("system_only"), true}})}}});
        backend.respond("GET", matome::orgPath(org, QStringLiteral("groups")), {{QStringLiteral("groups"), QJsonArray{
            row({{QStringLiteral("id"), QStringLiteral("g1")}, {QStringLiteral("name"), QStringLiteral("Legal")}, {QStringLiteral("revision"), 1}})}}});
        backend.respond("GET", matome::orgPath(org, QStringLiteral("groups/g1/members")), {{QStringLiteral("members"), QJsonArray{
            row({{QStringLiteral("id"), QStringLiteral("gm1")}, {QStringLiteral("group_id"), QStringLiteral("g1")},
                 {QStringLiteral("organization_membership_id"), QStringLiteral("m2")}})}}});
    }

    // The last call `method` made to `path`.
    static matome::test::MockAddOnBackend::Call lastCall(const matome::test::MockAddOnBackend &backend,
                                                         const QByteArray &method, const QString &path)
    {
        for (auto at = backend.calls.size() - 1; at >= 0; --at)
            if (backend.calls.at(at).method == method && backend.calls.at(at).path == path) return backend.calls.at(at);
        return {};
    }

    // Signs in, opens the first organization and creates the Inbox space.
    bool openInbox(FakeCore &core, Session &session)
    {
        session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
        if (!waitFor(&session))
            return false;
        session.openEntry(QStringLiteral("org"), entry(session, 0, EntryModel::EntryIdRole));
        if (!waitFor(&session))
            return false;
        session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
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

// Core reads a removal's reason from the DELETE body and refuses query
// parameters its routes do not declare.
void TestCore::deleteCarriesItsBody()
{
    FakeCore core;
    QVERIFY(core.listen());
    Client client;
    client.setBaseUrl(core.url());
    bool finished = false;
    const auto done = [&finished](const Client::Reply &) { finished = true; };
    client.del(QStringLiteral("/api/v1/anything"), done, {}, {{QStringLiteral("reason"), QStringLiteral("Retire")}});
    QTRY_VERIFY(finished);
    QCOMPARE(core.lastPath(), QStringLiteral("/api/v1/anything"));
    QCOMPARE(QJsonDocument::fromJson(core.lastBody()).object().value(QStringLiteral("reason")).toString(),
             QStringLiteral("Retire"));
    finished = false;
    client.del(QStringLiteral("/api/v1/anything"), done);
    QTRY_VERIFY(finished);
    QVERIFY(core.lastBody().isEmpty());
}

void TestCore::logsInAgainstCore()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.identifier(), QStringLiteral("ok@localhost"));
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
    QCOMPARE(QJsonDocument::fromJson(core.lastBody()).object(),
             (QJsonObject{{QStringLiteral("identifier"), QStringLiteral("ok@localhost")}, {QStringLiteral("password"), QStringLiteral("nope")}}));
}

// Registering starts no session: the person confirms the emailed link, which
// a new one may replace, then signs in.
void TestCore::registersAnAccount()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.registerAccount(QStringLiteral("new@localhost"), QStringLiteral("secret12"),
                            core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(core.lastPath(), QStringLiteral("/api/auth/register"));
    QVERIFY(session.confirmationPending());
    QVERIFY(!session.signedIn());
    QCOMPARE(session.organizations()->rowCount(), 0);

    session.resendConfirmation();
    QVERIFY(waitFor(&session));
    QVERIFY(session.confirmationResent());
    QCOMPARE(core.lastPath(), QStringLiteral("/api/auth/resend-confirmation"));
    QCOMPARE(QJsonDocument::fromJson(core.lastBody()).object(),
             (QJsonObject{{QStringLiteral("email"), QStringLiteral("new@localhost")}}));

    core.failNext(QStringLiteral("POST"), QStringLiteral("^/api/auth/resend-confirmation$"), 1,
                  FakeCore::FaultMode::Status, 429, QStringLiteral("rate_limited"));
    session.resendConfirmation();
    QVERIFY(waitFor(&session));
    QVERIFY(!session.confirmationResent());
    QCOMPARE(session.errorCode(), QStringLiteral("rate_limited"));

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
    QVERIFY(session.errorCode().isEmpty());

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

// An account an organization made signs in as `org-slug/username`, first
// with the setup code an administrator gave, which then sets its password.
void TestCore::setsUpAManagedAccount()
{
    FakeCore core;
    QVERIFY(core.listen());
    core.seedOrganization(QStringLiteral("Acme"), QStringLiteral("owner"));
    const QString identifier = core.seedManagedMember(QStringLiteral("org-1"), QStringLiteral("bo"), QStringLiteral("member"),
                                                      QStringLiteral("mst_code"));
    Session session;
    session.setUpAccount(identifier, QStringLiteral(" "), QStringLiteral("fresh-pass1"), core.url());
    QCOMPARE(session.errorCode(), QStringLiteral("invalid_request"));
    session.setUpAccount(identifier, QStringLiteral("mst_wrong"), QStringLiteral("fresh-pass1"), core.url());
    QVERIFY(waitFor(&session));
    QCOMPARE(session.errorCode(), QStringLiteral("invalid_setup_code"));
    QVERIFY(!session.signedIn());

    session.setUpAccount(identifier, QStringLiteral(" mst_code "), QStringLiteral("fresh-pass1"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
    QCOMPARE(session.identifier(), identifier);
    QCOMPARE(session.organizations()->rowCount(), 1);
    QCOMPARE(session.organizations()->data(session.organizations()->index(0), OrgModel::RolesRole).toStringList(),
             QStringList{QStringLiteral("member")});

    session.signOut();
    session.signIn(identifier.toUpper(), QStringLiteral("fresh-pass1"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.signedIn());
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
        {503, "billing_disabled", "billing_disabled"},
        {502, "billing_provider_error", "billing_provider_error"},
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

// A rate limit asking for a short wait is waited out twice at most; a long
// one is answered at once.
void TestCore::retriesAShortRateLimit()
{
    FakeCore core;
    QVERIFY(core.listen());
    core.retryAfter = 1;
    Client client;
    client.setBaseUrl(QUrl(core.url()));
    Client::Reply reply;
    bool finished = false;
    const auto me = [&] {
        finished = false;
        client.get(QStringLiteral("/api/auth/me"), [&](const Client::Reply &value) {
            finished = true;
            reply = value;
        });
    };
    QVERIFY(core.failNext(QStringLiteral("GET"), QStringLiteral("^/api/auth/me$"), 2,
                          FakeCore::FaultMode::Status, 429, QStringLiteral("rate_limited")));
    int hits = core.hits();
    me();
    QTRY_VERIFY_WITH_TIMEOUT(finished, 5000);
    QVERIFY(reply.ok);
    QCOMPARE(core.hits() - hits, 3);
    QVERIFY(core.failNext(QStringLiteral("GET"), QStringLiteral("^/api/auth/me$"), 3,
                          FakeCore::FaultMode::Status, 429, QStringLiteral("rate_limited")));
    hits = core.hits();
    me();
    QTRY_VERIFY_WITH_TIMEOUT(finished, 5000);
    QCOMPARE(reply.code, QStringLiteral("rate_limited"));
    QCOMPARE(core.hits() - hits, 3);
    core.retryAfter = 30;
    QVERIFY(core.failNext(QStringLiteral("GET"), QStringLiteral("^/api/auth/me$"), 1,
                          FakeCore::FaultMode::Status, 429, QStringLiteral("rate_limited")));
    hits = core.hits();
    me();
    QTRY_VERIFY(finished);
    QCOMPARE(reply.code, QStringLiteral("rate_limited"));
    QCOMPARE(core.hits() - hits, 1);
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
    QCOMPARE(again.identifier(), QStringLiteral("ok@localhost"));
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
    QCOMPARE(orgs->data(orgs->index(0), OrgModel::RolesRole).toStringList(), QStringList{QStringLiteral("owner")});
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("  "), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.spaces()->create(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.createHere(QStringLiteral("Contracts"), QStringLiteral("private"));
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
    QVERIFY(!session.entries()->index(0).data(EntryModel::ControlledRole).toBool());
    QCOMPARE(entry(session, 1, EntryModel::KindRole), QStringLiteral("document"));
    QCOMPARE(entry(session, 1, EntryModel::NameRole), QStringLiteral("Notes"));
    QCOMPARE(entry(session, 1, EntryModel::DetailRole), QLocale().formattedDataSize(12));
    QVERIFY(!session.entries()->index(1).data(EntryModel::ControlledRole).toBool());
    QCOMPARE(entry(session, 1, EntryModel::PayloadRole),
             QStringLiteral("document:%1:1").arg(documentId));
    QVERIFY(!session.entries()->index(1).data(EntryModel::CurrentRole).toBool());
    QCOMPARE(session.documents()->index(0).data(DocumentModel::FolderIdRole).toString(), QString());
    QCOMPARE(session.documents()->index(0).data(Qt::DisplayRole), QVariant());
    session.openEntry(QStringLiteral("document"), documentId);
    QVERIFY(session.entries()->index(1).data(EntryModel::CurrentRole).toBool());
    QCOMPARE(session.currentDocumentId(), documentId);

    QCOMPARE(session.entries()->index(0).data(Qt::DisplayRole), QVariant());
    QCOMPARE(session.entries()->index(0).data(EntryModel::ControlledRole + 1), QVariant());
    QCOMPARE(session.entries()->index(7).data(EntryModel::NameRole), QVariant());
    QCOMPARE(session.entries()->rowCount(session.entries()->index(0)), 0);
    QCOMPARE(session.entries()->roleNames().value(EntryModel::PayloadRole), QByteArray("payload"));
    QCOMPARE(session.entries()->roleNames().value(EntryModel::ControlledRole), QByteArray("controlled"));
}

void TestCore::entryFilterMatchesNamesAndClearsOnMove()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    session.createHere(QStringLiteral("Contracts"), QStringLiteral("private"));
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
    session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
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
    session.setFocusPayload(entry(session, 1, EntryModel::PayloadRole));
    QVERIFY(session.handleKey(Qt::Key_D, Qt::NoModifier, false));
    QVERIFY(waitFor(&session));
    QCOMPARE(saved.size(), 1);
    QVERIFY(saved.at(0).at(0).toUrl().isLocalFile());

    session.setFocusPayload(QString());
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

    session.createHere(QStringLiteral("Inbox"), QStringLiteral("private"));
    QVERIFY(waitFor(&session));
    core.seedDocument(session.currentSpaceId(), QStringLiteral("Notes.md"));
    session.setFocusPayload(QString());
    session.runCommand(QStringLiteral("refresh"));
    QVERIFY(waitFor(&session));
    QCOMPARE(command(session, QStringLiteral("new")).value(QStringLiteral("title")).toString(),
             QStringLiteral("New folder"));
    QVERIFY(usable(session, QStringLiteral("upload")));
    for (const char *id : {"download", "cut", "paste", "rename", "trash"})
        QVERIFY(!usable(session, QString::fromLatin1(id)));
    session.setFocusPayload(entry(session, 0, EntryModel::PayloadRole));
    QVERIFY(usable(session, QStringLiteral("download")));
    QVERIFY(usable(session, QStringLiteral("open")));
    QVERIFY(usable(session, QStringLiteral("trash")));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("title")).toString(),
             QStringLiteral("Move to trash"));
    QCOMPARE(command(session, QStringLiteral("trash")).value(QStringLiteral("icon")).toString(),
             QStringLiteral("trash"));
    QVERIFY(usable(session, QStringLiteral("cut")));
    // A focused folder opens but has nothing to download, and no trash: it
    // is deleted for good.
    session.setFocusPayload(QStringLiteral("folder:1:1"));
    QVERIFY(!usable(session, QStringLiteral("download")));
    QVERIFY(usable(session, QStringLiteral("open")));
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
    session.setFocusPayload(entry(session, 1, EntryModel::PayloadRole));
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
    const QJsonObject ada{{QStringLiteral("identifier"), QStringLiteral("ada@localhost")},
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
    session.spaces()->create(QStringLiteral("C"), QStringLiteral("private"));
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


void TestCore::settingsAvailableWithoutAdminOrganization()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(!usable(session, QStringLiteral("settings")));
    session.openSettings();
    QVERIFY(!session.settingsActive());
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    QVERIFY(session.currentOrgId().isEmpty());
    QVERIFY(usable(session, QStringLiteral("settings")));
    int hits = core.hits();
    session.runCommand(QStringLiteral("settings"));
    QVERIFY(session.settingsActive());
    QVERIFY(!session.orgAdmin()->active());
    QCOMPARE(core.hits(), hits);
    session.closeSettings();
    QVERIFY(!session.settingsActive());

    core.seedOrganization(QStringLiteral("Guest team"), QStringLiteral("guest"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("org"), session.organizations()->index(session.organizations()->rowCount() - 1).data(OrgModel::OrgIdRole).toString());
    QVERIFY(waitFor(&session));
    QVERIFY(!session.orgAdmin()->available());
    QVERIFY(usable(session, QStringLiteral("settings")));
    hits = core.hits();
    session.runCommand(QStringLiteral("settings"));
    QVERIFY(session.settingsActive());
    QVERIFY(!session.orgAdmin()->active());
    QCOMPARE(core.hits(), hits);
    session.signOut();
    QVERIFY(!session.settingsActive());
    QVERIFY(!usable(session, QStringLiteral("settings")));
}

void TestCore::settingsSelectsOrganizationsAndDiscardsReplies()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    session.signIn(QStringLiteral("ok@localhost"), QStringLiteral("secret12"), core.url());
    QVERIFY(waitFor(&session));
    core.seedOrganization(QStringLiteral("Other"), QStringLiteral("admin"));
    core.seedOrganization(QStringLiteral("Guest team"), QStringLiteral("guest"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    auto *orgs = session.organizations();
    const QString first = orgs->index(0).data(OrgModel::OrgIdRole).toString();
    const QString second = orgs->index(1).data(OrgModel::OrgIdRole).toString();
    const QString guest = orgs->index(2).data(OrgModel::OrgIdRole).toString();
    // Each organization's catalog decides the sections it opens.
    auto *permissions = session.permissions();
    QTRY_VERIFY(permissions->known(first) && permissions->known(second) && permissions->known(guest));
    QVERIFY(permissions->sections(first).contains(QStringLiteral("members")));
    QVERIFY(permissions->sections(second).contains(QStringLiteral("members")));
    QVERIFY(permissions->sections(guest).isEmpty());
    session.openSettings();
    QVERIFY(session.settingsActive());
    auto *admin = session.orgAdmin();
    QVERIFY(!admin->active());
    QVERIFY(core.failNext(QStringLiteral("GET"), matome::orgPath(first, QStringLiteral("members")),
                          1, FakeCore::FaultMode::Hold));
    session.navigate(QStringLiteral("org"), first);
    QTRY_COMPARE(core.held(), 1);
    QVERIFY(admin->active());
    session.navigate(QStringLiteral("org"), second);
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->name(), QStringLiteral("Other"));
    QVERIFY(session.settingsActive());
    core.release();
    QTest::qWait(20);
    QCOMPARE(admin->name(), QStringLiteral("Other"));
    QCOMPARE(admin->members()->rowCount(), 1);
    session.navigate(QStringLiteral("org"), guest);
    QVERIFY(!admin->active());
    QVERIFY(session.settingsActive());
    QCOMPARE(admin->members()->rowCount(), 0);
    session.closeSettings();
    session.navigate(QStringLiteral("root"), QString());
    QVERIFY(session.currentOrgId().isEmpty());
    QVERIFY(!session.settingsActive());
}

void TestCore::orgAdminLoadsAndPreservesLocation()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString spaceId = session.currentSpaceId();
    session.runCommand(QStringLiteral("settings"));
    auto *admin = session.orgAdmin();
    QVERIFY(session.settingsActive());
    QVERIFY(admin->active());
    QTRY_VERIFY(!admin->busy());
    QTRY_VERIFY(!session.orgBilling()->busy());
    QVERIFY(admin->generalError().isEmpty());
    QVERIFY(admin->membersError().isEmpty());
    QVERIFY(admin->invitationsError().isEmpty());
    QVERIFY(session.orgBilling()->usageError().isEmpty());
    QCOMPARE(admin->members()->rowCount(), 1);
    QCOMPARE(session.orgBilling()->plan(), QStringLiteral("free"));
    QCOMPARE(session.orgBilling()->usage().size(), 4);
    QCOMPARE(session.orgBilling()->usage().first().toMap().value(QStringLiteral("used")).toInt(), 1048576);
    admin->rename(QStringLiteral("  Team  "));
    QTRY_VERIFY(!admin->busy());
    QVERIFY(waitFor(&session));
    QCOMPARE(admin->name(), QStringLiteral("Team"));
    QCOMPARE(session.organizations()->nameOf(session.currentOrgId()), QStringLiteral("Team"));
    session.closeSettings();
    QVERIFY(!session.settingsActive());
    QCOMPARE(session.currentSpaceId(), spaceId);
    QCOMPARE(admin->members()->rowCount(), 0);
    QVERIFY(admin->name().isEmpty());
}

void TestCore::orgAdminMutatesMembersAndInvitations()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString id = core.seedMember(session.currentOrgId(), QStringLiteral("colleague@example.com"), QStringLiteral("member"));
    auto *admin = session.orgAdmin();
    admin->open();
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->members()->rowCount(), 2);
    QCOMPARE(admin->members()->index(1).data(matome::OrgPeopleModel::LabelRole).toString(), QStringLiteral("colleague@example.com"));
    // Organization roles, built-in ones included, are principal roles: Save
    // grants the checked ones before taking back the others.
    auto *directory = session.accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    auto *held = session.principalAccess();
    held->open(QStringLiteral("user:") + id);
    QTRY_VERIFY(!held->busy());
    QCOMPARE(held->roleIds(), QStringList{QStringLiteral("role-member")});
    held->setRoles({QStringLiteral("role-admin"), QStringLiteral("role-billing")});
    QTRY_VERIFY(!held->busy());
    QVERIFY(held->errorCode().isEmpty());
    QCOMPARE(held->notice(), QStringLiteral("roles_saved"));
    QCOMPARE(held->roleIds(), (QStringList{QStringLiteral("role-admin"), QStringLiteral("role-billing")}));
    QTRY_COMPARE(admin->members()->index(1).data(matome::OrgPeopleModel::RolesRole).toStringList(),
                 (QStringList{QStringLiteral("admin"), QStringLiteral("billing")}));
    // The reload the role change asked for ends before the next change.
    QTRY_VERIFY(!admin->busy());
    admin->invite(QStringLiteral(" invitee@example.com "), {QStringLiteral("member"), QStringLiteral("billing")});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->invitations()->rowCount(), 1);
    QCOMPARE(admin->invitations()->index(0).data(matome::OrgPeopleModel::RolesRole).toStringList(),
             (QStringList{QStringLiteral("member"), QStringLiteral("billing")}));
    admin->invite(QStringLiteral("owner@example.com"), {QStringLiteral("owner")});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_role"));
    QCOMPARE(admin->invitations()->index(0).data(matome::OrgPeopleModel::StatusRole).toString(), QStringLiteral("pending"));
    QVERIFY(admin->invitations()->index(0).data(matome::OrgPeopleModel::SpacesRole).toStringList().isEmpty());
    // An invitation offers access to spaces, each named on its row; Core
    // refuses a space it does not have or one named twice.
    const QString space = session.currentSpaceId();
    const QVariantMap offer{{QStringLiteral("space_id"), space}, {QStringLiteral("role_ids"), QStringList{QStringLiteral("role-content_reader")}}};
    admin->invite(QStringLiteral("gone@example.com"), {QStringLiteral("member")},
                  {QVariantMap{{QStringLiteral("space_id"), QStringLiteral("space-404")},
                               {QStringLiteral("role_ids"), QStringList{QStringLiteral("role-content_reader")}}}});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("not_found"));
    admin->invite(QStringLiteral("twice@example.com"), {QStringLiteral("member")}, {offer, offer});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_request"));
    admin->invite(QStringLiteral("offered@example.com"), {QStringLiteral("member")}, {offer});
    QTRY_VERIFY(!admin->busy());
    QVERIFY(admin->errorCode().isEmpty());
    QCOMPARE(admin->invitations()->rowCount(), 2);
    QCOMPARE(admin->invitations()->index(1).data(matome::OrgPeopleModel::SpacesRole).toStringList(), QStringList{QStringLiteral("Inbox")});
    // An invitation's page names the roles it gives in each space.
    const QVariantMap offered = admin->invitation(admin->invitations()->index(1).data(matome::OrgPeopleModel::PersonIdRole).toString());
    QCOMPARE(offered.value(QStringLiteral("label")).toString(), QStringLiteral("offered@example.com"));
    QCOMPARE(offered.value(QStringLiteral("status")).toString(), QStringLiteral("pending"));
    QCOMPARE(offered.value(QStringLiteral("roles")).toStringList(), QStringList{QStringLiteral("member")});
    const QVariantMap spaceOffer = offered.value(QStringLiteral("spaces")).toList().constFirst().toMap();
    QCOMPARE(spaceOffer.value(QStringLiteral("spaceId")).toString(), space);
    QCOMPARE(spaceOffer.value(QStringLiteral("name")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(spaceOffer.value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("role-content_reader")});
    QVERIFY(admin->invitation(QStringLiteral("missing")).isEmpty());
    const QString invitationId = admin->invitations()->index(0).data(matome::OrgPeopleModel::PersonIdRole).toString();
    admin->cancelInvitation(invitationId);
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->invitations()->index(0).data(matome::OrgPeopleModel::StatusRole).toString(), QStringLiteral("canceled"));
    admin->removeMember(id);
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->members()->rowCount(), 1);
}

// An account the organization manages is created with a username, its
// roles, and a password or a one-time setup code; a new code replaces it,
// and Core's refusals are kept as given.
void TestCore::orgAdminCreatesManagedMembers()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    auto *admin = session.orgAdmin();
    admin->open();
    QTRY_VERIFY(!admin->busy());
    QVERIFY(!admin->slug().isEmpty());
    QSignalSpy saved(admin, &matome::OrgAdmin::changeSaved);
    admin->createMember(QStringLiteral("Ana.Lima"), QStringLiteral(" Ana Lima "), {QStringLiteral("member")}, {});
    QTRY_COMPARE(saved.size(), 1);
    QCOMPARE(saved.constLast().at(0).toString(), QStringLiteral("member_created"));
    QVERIFY(admin->setupCode().value(QStringLiteral("code")).toString().startsWith(QLatin1String("mst_")));
    QVERIFY(!admin->setupCode().value(QStringLiteral("expiresAt")).toString().isEmpty());
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->members()->rowCount(), 2);
    QCOMPARE(admin->members()->index(1).data(matome::OrgPeopleModel::LabelRole).toString(), QStringLiteral("Ana Lima"));
    // The code shows until cleared; a password leaves none.
    admin->clearSetupCode();
    QVERIFY(admin->setupCode().isEmpty());
    admin->createMember(QStringLiteral("robot"), {}, {QStringLiteral("admin"), QStringLiteral("billing")}, QStringLiteral("long-secret"));
    QTRY_COMPARE(saved.size(), 2);
    QVERIFY(admin->setupCode().isEmpty());
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->members()->index(2).data(matome::OrgPeopleModel::RolesRole).toStringList(),
             (QStringList{QStringLiteral("admin"), QStringLiteral("billing")}));
    // Refusals: a taken or invalid username, a short password.
    admin->createMember(QStringLiteral("ana.lima"), {}, {QStringLiteral("member")}, {});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("username_taken"));
    admin->createMember(QStringLiteral("a"), {}, {QStringLiteral("member")}, {});
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_username"));
    admin->createMember(QStringLiteral("short"), {}, {QStringLiteral("member")}, QStringLiteral("abc"));
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_request"));
    QCOMPARE(saved.size(), 2);
    // A new code for a managed account; a personal one has none.
    const QString ana = admin->members()->index(1).data(matome::OrgPeopleModel::PersonIdRole).toString();
    admin->issueSetupCode(ana);
    QTRY_COMPARE(saved.size(), 3);
    QCOMPARE(saved.constLast().at(0).toString(), QStringLiteral("setup_code_issued"));
    QVERIFY(admin->setupCode().value(QStringLiteral("code")).toString().startsWith(QLatin1String("mst_")));
    QTRY_VERIFY(!admin->busy());
    admin->clearSetupCode();
    admin->issueSetupCode(admin->members()->index(0).data(matome::OrgPeopleModel::PersonIdRole).toString());
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("not_managed"));
    QVERIFY(admin->setupCode().isEmpty());
    admin->close();
    QVERIFY(admin->setupCode().isEmpty());
}

void TestCore::orgAdminGuardsLastOwnerAndReportsErrors()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    auto *admin = session.orgAdmin();
    admin->open();
    QTRY_VERIFY(!admin->busy());
    const QString owner = admin->members()->index(0).data(matome::OrgPeopleModel::PersonIdRole).toString();
    admin->removeMember(owner);
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("last_owner"));
    session.accessDirectory()->open();
    QTRY_VERIFY(!session.accessDirectory()->busy());
    auto *held = session.principalAccess();
    held->open(QStringLiteral("user:") + owner);
    QTRY_VERIFY(!held->busy());
    held->setRoles({QStringLiteral("role-member")});
    QTRY_VERIFY(!held->busy());
    QCOMPARE(held->errorCode(), QStringLiteral("last_owner"));
    QCOMPARE(held->roleIds(), (QStringList{QStringLiteral("role-owner"), QStringLiteral("role-member")}));
    QTRY_VERIFY(!admin->busy());
    const int hits = core.hits();
    admin->invite(QStringLiteral("bad"), {QStringLiteral("member")});
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_email"));
    admin->rename(QStringLiteral(" "));
    QCOMPARE(admin->errorCode(), QStringLiteral("invalid_request"));
    admin->removeMember(QStringLiteral("missing"));
    QCOMPARE(core.hits(), hits);
    const QString path = matome::orgPath(session.currentOrgId(), QStringLiteral("members"));
    QVERIFY(core.failNext(QStringLiteral("GET"), path, 1, FakeCore::FaultMode::Status, 403, QStringLiteral("forbidden")));
    admin->refresh();
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->membersError(), QStringLiteral("forbidden"));
    QCOMPARE(admin->members()->rowCount(), 0);
    QVERIFY(admin->generalError().isEmpty());
    QVERIFY(admin->invitationsError().isEmpty());
    const QString orgPath = matome::orgsPath() + QLatin1Char('/') + session.currentOrgId();
    QVERIFY(core.failNext(QStringLiteral("PATCH"), orgPath, 1, FakeCore::FaultMode::Status, 409, QStringLiteral("revision_conflict")));
    admin->rename(QStringLiteral("Changed"));
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->errorCode(), QStringLiteral("revision_conflict"));
    QVERIFY(admin->name() != QStringLiteral("Changed"));
}

void TestCore::orgAdminDiscardsStaleReplies()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    core.seedOrganization(QStringLiteral("Other"), QStringLiteral("admin"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    const QString membersPath = matome::orgPath(session.currentOrgId(), QStringLiteral("members"));
    QVERIFY(core.failNext(QStringLiteral("GET"), membersPath, 1, FakeCore::FaultMode::Hold));
    auto *admin = session.orgAdmin();
    admin->open();
    QTRY_COMPARE(core.held(), 1);
    session.navigate(QStringLiteral("org"), session.organizations()->index(1).data(OrgModel::OrgIdRole).toString());
    QVERIFY(!admin->active());
    admin->open();
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->name(), QStringLiteral("Other"));
    core.release();
    QTest::qWait(20);
    QCOMPARE(admin->name(), QStringLiteral("Other"));
    QCOMPARE(admin->members()->rowCount(), 1);
    const QString newPath = matome::orgPath(session.currentOrgId(), QStringLiteral("members"));
    QVERIFY(core.failNext(QStringLiteral("GET"), newPath, 1, FakeCore::FaultMode::Hold));
    admin->refresh();
    QTRY_COMPARE(core.held(), 1);
    session.signOut();
    QVERIFY(!admin->active());
    core.release();
    QTest::qWait(20);
    QCOMPARE(admin->members()->rowCount(), 0);
    QVERIFY(!admin->busy());
}

void TestCore::orgAdminClosesWhenAdminAccessIsLost()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    core.seedMember(session.currentOrgId(), QStringLiteral("other-owner@example.com"), QStringLiteral("owner"));
    auto *admin = session.orgAdmin();
    session.openSettings();
    QTRY_VERIFY(!admin->busy());
    const QString id = admin->members()->index(0).data(matome::OrgPeopleModel::PersonIdRole).toString();
    session.accessDirectory()->open();
    QTRY_VERIFY(!session.accessDirectory()->busy());
    session.principalAccess()->open(QStringLiteral("user:") + id);
    QTRY_VERIFY(!session.principalAccess()->busy());
    session.principalAccess()->setRoles({QStringLiteral("role-member")});
    QTRY_VERIFY(!admin->active());
    QVERIFY(!admin->available());
    QVERIFY(session.settingsActive());
    QVERIFY(!usable(session, QStringLiteral("settings")));
    QCOMPARE(admin->members()->rowCount(), 0);
    admin->open();
    QVERIFY(!admin->active());
    session.closeSettings();
    QVERIFY(usable(session, QStringLiteral("settings")));
}

void TestCore::orgAdminRestrictsEntryAndPaginates()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    for (int i = 0; i < 120; ++i)
        core.seedMember(session.currentOrgId(), QStringLiteral("person%1@example.com").arg(i), QStringLiteral("member"));
    auto *admin = session.orgAdmin();
    admin->open();
    QTRY_VERIFY(!admin->busy());
    QCOMPARE(admin->members()->rowCount(), 121);
    admin->close();
    core.seedOrganization(QStringLiteral("Guest team"), QStringLiteral("guest"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("org"), session.organizations()->index(1).data(OrgModel::OrgIdRole).toString());
    QVERIFY(!admin->available());
    const int hits = core.hits();
    admin->open();
    admin->invite(QStringLiteral("person@example.com"), {QStringLiteral("admin")});
    QVERIFY(!admin->active());
    QCOMPARE(core.hits(), hits);
}

void TestCore::addOnsUseMockBackend()
{
    matome::test::MockAddOnBackend backend;
    matome::AddOnManager manager(backend);
    const QString org = QStringLiteral("org-mock");
    const QString path = matome::orgPath(org, QStringLiteral("add-ons"));
    QJsonObject installation{{QStringLiteral("status"), QStringLiteral("active")},
        {QStringLiteral("revision"), 7}, {QStringLiteral("settings"), QJsonObject{{QStringLiteral("keep"), true}}}};
    const auto product = [&installation] {
        return QJsonObject{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
            {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
            {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("quantity"), 1}}}},
            {QStringLiteral("installation"), installation}};
    };
    backend.respond("GET", QStringLiteral("/api/v1/add-ons"),
                    {{QStringLiteral("products"), QJsonArray{product()}}});
    backend.respond("GET", path, {{QStringLiteral("products"), QJsonArray{product()}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")),
                    {{QStringLiteral("spaces"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("space-a")}}}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")), {{QStringLiteral("members"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), QStringLiteral("m1")}, {QStringLiteral("email"), QStringLiteral("ana@example.com")},
                    {QStringLiteral("status"), QStringLiteral("active")}},
        QJsonObject{{QStringLiteral("id"), QStringLiteral("m2")}, {QStringLiteral("email"), QStringLiteral("bo@example.com")},
                    {QStringLiteral("status"), QStringLiteral("removed")}},
        QJsonObject{{QStringLiteral("id"), QStringLiteral("m3")}, {QStringLiteral("email"), QJsonValue::Null},
                    {QStringLiteral("username"), QStringLiteral("robot")}, {QStringLiteral("status"), QStringLiteral("active")}}}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("entitlements")),
        {{QStringLiteral("entitlements"), QJsonObject{{QStringLiteral("capabilities"), QJsonObject{{QStringLiteral("addon.controlled_docs"), true}}}}}});
    manager.setContext(org, true, true);
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    QVERIFY(manager.state(QStringLiteral("controlled_docs")).value(QStringLiteral("available")).toBool());
    // Only active memberships may answer for an installation; a managed
    // account reads as its username.
    QCOMPARE(manager.members().size(), 2);
    QCOMPARE(manager.members().constFirst().toMap().value(QStringLiteral("value")).toString(), QStringLiteral("m1"));
    QCOMPARE(manager.members().constLast().toMap().value(QStringLiteral("label")).toString(), QStringLiteral("robot"));
    // A refresh asked for while one loads, such as after a new space, loads once more after it.
    const auto loads = [&backend, &path] {
        return std::count_if(backend.calls.cbegin(), backend.calls.cend(),
                             [&path](const auto &call) { return call.method == "GET" && call.path == path; });
    };
    const auto loaded = loads();
    manager.refresh();
    QVERIFY(manager.busy());
    manager.refresh();
    manager.refresh();
    QTRY_COMPARE(loads(), loaded + 2);
    QTRY_VERIFY(!manager.busy());
    QCOMPARE(loads(), loaded + 2);
    backend.respond("GET", matome::orgPath(org, QStringLiteral("entitlements")),
        {{QStringLiteral("entitlements"), QJsonObject{{QStringLiteral("capabilities"), QJsonObject{{QStringLiteral("addon.controlled_docs"), false}}}}}});
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    QVERIFY(!manager.state(QStringLiteral("controlled_docs")).value(QStringLiteral("entitled")).toBool());
    const int forbiddenCalls = backend.calls.size();
    manager.install(QStringLiteral("controlled_docs"));
    QCOMPARE(backend.calls.size(), forbiddenCalls);
    backend.respond("GET", matome::orgPath(org, QStringLiteral("entitlements")),
        {{QStringLiteral("entitlements"), QJsonObject{{QStringLiteral("capabilities"), QJsonObject{{QStringLiteral("addon.controlled_docs"), true}}}}}});
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    backend.respond("POST", path + QStringLiteral("/controlled_docs/installation/pause"), {});
    installation.insert(QStringLiteral("status"), QStringLiteral("paused"));
    backend.respond("GET", path, {{QStringLiteral("products"), QJsonArray{product()}}});
    manager.pause(QStringLiteral("controlled_docs"));
    QTRY_VERIFY(!manager.busy());
    QVERIFY(!manager.state(QStringLiteral("controlled_docs")).value(QStringLiteral("available")).toBool());
    QCOMPARE(manager.notice(), QStringLiteral("installation_paused"));
    backend.respond("PUT", path + QStringLiteral("/controlled_docs/installation"), {});
    // Resuming sends the saved settings back unchanged.
    manager.resume(QStringLiteral("controlled_docs"));
    const auto resume = backend.calls.constLast();
    QCOMPARE(resume.method, QByteArray("PUT"));
    QCOMPARE(resume.body, (QJsonObject{{QStringLiteral("settings"), QJsonObject{{QStringLiteral("keep"), true}}}}));
    QVERIFY(!resume.headers.isEmpty());
    QTRY_VERIFY(!manager.busy());
    QCOMPARE(manager.notice(), QStringLiteral("installation_resumed"));
    installation.insert(QStringLiteral("status"), QStringLiteral("active"));
    backend.respond("GET", path, {{QStringLiteral("products"), QJsonArray{product()}}});
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    const int active = backend.calls.size();
    manager.resume(QStringLiteral("controlled_docs"));
    QCOMPARE(backend.calls.size(), active);
    backend.respond("PATCH", path + QStringLiteral("/controlled_docs/installation"), {});
    manager.saveSettings(QStringLiteral("controlled_docs"), {{QStringLiteral("required_approvals"), 3}});
    const auto patch = backend.calls.constLast();
    QCOMPARE(patch.method, QByteArray("PATCH"));
    QCOMPARE(patch.body.value(QStringLiteral("settings")).toObject().value(QStringLiteral("required_approvals")).toInt(), 3);
    QTRY_VERIFY(!manager.busy());
    QCOMPARE(manager.notice(), QStringLiteral("settings_saved"));
    manager.install(QStringLiteral("controlled_docs"), {{QStringLiteral("required_approvals"), 2}});
    const auto configured = backend.calls.constLast().body;
    QCOMPARE(configured.keys(), QStringList{QStringLiteral("settings")});
    QVERIFY(configured.value(QStringLiteral("settings")).toObject().value(QStringLiteral("keep")).toBool());
    QCOMPARE(configured.value(QStringLiteral("settings")).toObject().value(QStringLiteral("required_approvals")).toInt(), 2);
    QTRY_VERIFY(!manager.busy());
    // Reassigning sends only the membership; a refusal says Core's reason.
    backend.respond("PATCH", path + QStringLiteral("/controlled_docs/installation"), {}, 422, QStringLiteral("invalid_responsible_membership"));
    manager.assign(QStringLiteral("controlled_docs"), QStringLiteral("m1"));
    const auto assigned = backend.calls.constLast();
    QCOMPARE(assigned.method, QByteArray("PATCH"));
    QCOMPARE(assigned.body, (QJsonObject{{QStringLiteral("responsible_membership_id"), QStringLiteral("m1")}}));
    QTRY_VERIFY(!manager.busy());
    QCOMPARE(manager.errorCode(), QStringLiteral("invalid_responsible_membership"));
    installation.insert(QStringLiteral("responsible_membership_id"), QStringLiteral("m1"));
    backend.respond("GET", path, {{QStringLiteral("products"), QJsonArray{product()}}});
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    const int unchanged = backend.calls.size();
    manager.assign(QStringLiteral("controlled_docs"), QStringLiteral("m1"));
    QCOMPARE(backend.calls.size(), unchanged);
    // Uninstalling sends the reason; Core marks the installation
    // uninstalled, which reads as not installed.
    installation.insert(QStringLiteral("status"), QStringLiteral("uninstalled"));
    backend.respond("DELETE", path + QStringLiteral("/controlled_docs/installation"),
                    {{QStringLiteral("installation"), installation}});
    backend.respond("GET", path, {{QStringLiteral("products"), QJsonArray{product()}}});
    manager.uninstall(QStringLiteral("controlled_docs"), QStringLiteral(" Retire "));
    const auto removal = backend.calls.constLast();
    QCOMPARE(removal.method, QByteArray("DELETE"));
    QCOMPARE(removal.path, path + QStringLiteral("/controlled_docs/installation"));
    QCOMPARE(removal.body.value(QStringLiteral("reason")).toString(), QStringLiteral("Retire"));
    QTRY_VERIFY(!manager.busy());
    QCOMPARE(manager.notice(), QStringLiteral("installation_removed"));
    QVERIFY(manager.state(QStringLiteral("controlled_docs")).value(QStringLiteral("status")).toString().isEmpty());
    QVERIFY(manager.product(QStringLiteral("controlled_docs")).value(QStringLiteral("installation")).isNull());
    // Uninstalled, nothing is uninstalled again, resumed, or changed, and
    // installing again names no space and no responsible member: Core makes
    // it available everywhere and answers for the installer.
    const int absent = backend.calls.size();
    manager.resume(QStringLiteral("controlled_docs"));
    manager.uninstall(QStringLiteral("controlled_docs"), QStringLiteral("Again"));
    manager.saveSettings(QStringLiteral("controlled_docs"), {{QStringLiteral("required_approvals"), 2}});
    QCOMPARE(backend.calls.size(), absent);
    manager.install(QStringLiteral("controlled_docs"));
    QCOMPARE(backend.calls.constLast().body, (QJsonObject{{QStringLiteral("settings"), QJsonObject()}}));
    QTRY_VERIFY(!manager.busy());
    manager.setContext(org, true, false);
    manager.refresh();
    QTRY_VERIFY(!manager.busy());
    const int readonlyCalls = backend.calls.size();
    manager.install(QStringLiteral("controlled_docs"));
    manager.pause(QStringLiteral("controlled_docs"));
    manager.saveSettings(QStringLiteral("controlled_docs"), {{QStringLiteral("required_approvals"), 2}});
    QCOMPARE(backend.calls.size(), readonlyCalls);
}

void TestCore::addOnsDiscardStaleMockReplies()
{
    matome::test::MockAddOnBackend backend;
    backend.delayMs = 25;
    matome::AddOnManager manager(backend);
    backend.respond("GET", QStringLiteral("/api/v1/add-ons"), {{QStringLiteral("products"), QJsonArray()}});
    manager.setContext(QStringLiteral("old-org"), true, true);
    manager.refresh();
    QVERIFY(manager.busy());
    manager.setContext(QStringLiteral("new-org"), false, false);
    QTest::qWait(60);
    QVERIFY(!manager.busy());
    QVERIFY(manager.products().isEmpty());
    QVERIFY(manager.errorCode().isEmpty());
    QVERIFY(!manager.state(QStringLiteral("controlled_docs")).value(QStringLiteral("known")).toBool());
}

namespace {

QJsonObject markdownVersion(const QString &id, int number, bool current, const QByteArray &bytes)
{
    return {{QStringLiteral("id"), id}, {QStringLiteral("version_number"), number}, {QStringLiteral("current"), current},
            {QStringLiteral("publication_state"), QStringLiteral("published")},
            {QStringLiteral("filename"), QStringLiteral("procedure.md")}, {QStringLiteral("content_type"), QStringLiteral("text/markdown")},
            {QStringLiteral("byte_size"), bytes.size()}};
}

// A document with its versions and each version's text, as Core serves them.
void serveDocument(matome::test::MockAddOnBackend &backend, const QString &doc, const QJsonObject &document,
                   const QList<QPair<QJsonObject, QByteArray>> &versions)
{
    backend.respond("GET", doc, {{QStringLiteral("document"), document}});
    QJsonArray rows;
    for (const auto &[version, bytes] : versions) {
        rows.append(version);
        const QString id = version.value(QStringLiteral("id")).toString();
        const QString url = QStringLiteral("https://storage.invalid/") + id;
        backend.respond("GET", doc + QStringLiteral("/download?version_id=") + id,
                        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("url"), url}}}});
        backend.file(QUrl(url), bytes);
    }
    backend.respond("GET", doc + QStringLiteral("/versions"), {{QStringLiteral("data"), rows}});
}

// The controlled-documents add-on installed in `org`.
// Reads the organization's catalog again, and waits until the add-ons
// follow what it allows.
bool followCatalog(Session &session)
{
    session.permissions()->reload();
    return QTest::qWaitFor([&session] { return session.addOns()->canInstall(); });
}

void serveControlledDocs(matome::test::MockAddOnBackend &backend, const QString &org,
                         const QString &status = QStringLiteral("active"))
{
    // An owner reads and installs add-ons.
    const auto allowed = [](const QString &key) {
        return QJsonObject{{QStringLiteral("key"), key}, {QStringLiteral("axis"), QStringLiteral("organization")},
                           {QStringLiteral("token_scope"), QStringLiteral("organization")}, {QStringLiteral("allowed"), true}};
    };
    backend.respond("GET", matome::orgPath(org, QStringLiteral("action-catalog")),
                    {{QStringLiteral("actions"), QJsonArray{allowed(QStringLiteral("add_on.read")), allowed(QStringLiteral("add_on.install"))}}});
    const QJsonObject product{{QStringLiteral("key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("capability"), QStringLiteral("addon.controlled_docs")},
        {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), status}, {QStringLiteral("revision"), 1}}}};
    backend.respond("GET", QStringLiteral("/api/v1/add-ons"), {{QStringLiteral("products"), QJsonArray{product}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("add-ons")), {{QStringLiteral("products"), QJsonArray{product}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")), {{QStringLiteral("spaces"), QJsonArray()}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")), {{QStringLiteral("members"), QJsonArray()}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("entitlements")),
        {{QStringLiteral("entitlements"), QJsonObject{{QStringLiteral("capabilities"),
            QJsonObject{{QStringLiteral("addon.controlled_docs"), true}}}}}});
}

// The space's add-ons as `GET …/add-ons` lists them: controlled documents,
// turned on there when `active`, with the space's `settings` overrides
// in effect.
QJsonObject spaceAddOns(bool active, const QJsonObject &settings = {}, const QJsonValue &revision = 2)
{
    return {{QStringLiteral("add_ons"), QJsonArray{QJsonObject{
        {QStringLiteral("product_key"), QStringLiteral("controlled_docs")},
        {QStringLiteral("installation_status"), QStringLiteral("active")},
        {QStringLiteral("status"), active ? QStringLiteral("active") : QStringLiteral("inactive")}, {QStringLiteral("active"), active},
        {QStringLiteral("settings"), settings}, {QStringLiteral("effective_settings"), settings},
        {QStringLiteral("revision"), revision}}}}};
}

Client::Reply refusal(int status, const QString &code)
{
    Client::Reply reply;
    reply.status = status;
    reply.code = code;
    return reply;
}

// The first call to `path` with `method` from `from` on, or -1.
qsizetype callAt(const matome::test::MockAddOnBackend &backend, const QByteArray &method, const QString &path,
                 qsizetype from = 0)
{
    for (auto at = from; at < backend.calls.size(); ++at)
        if (backend.calls.at(at).method == method && backend.calls.at(at).path == path) return at;
    return -1;
}

} // namespace

void TestCore::documentViewPreviewsAndSaves()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QByteArray current("# Current\n"), older("# Older\n");
    QJsonObject candidate = markdownVersion(QStringLiteral("candidate"), 3, false, "# Candidate\n");
    candidate.insert(QStringLiteral("publication_state"), QStringLiteral("candidate"));
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")}},
                  {{markdownVersion(QStringLiteral("older"), 1, false, older), older},
                   {markdownVersion(QStringLiteral("base"), 2, true, current), current},
                   {candidate, "# Candidate\n"}});
    auto *view = session.documentView();
    QSignalSpy opened(view, &matome::DocumentView::opened);
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QCOMPARE(opened.size(), 1);
    QVERIFY(view->active());
    QVERIFY(!usable(session, QStringLiteral("new")));
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->title(), QStringLiteral("procedure.md"));
    QCOMPARE(view->versions().size(), 2);
    QCOMPARE(view->versions().constFirst().toMap().value(QStringLiteral("version_number")).toInt(), 2);
    QCOMPARE(view->kind(), QStringLiteral("markdown"));
    QCOMPARE(view->text(), QString::fromUtf8(current));
    QVERIFY(view->latest());
    QVERIFY(view->editable());
    QVERIFY(usable(session, QStringLiteral("edit-tab")));
    QVERIFY(!usable(session, QStringLiteral("reviews-tab")));
    view->selectVersion(QStringLiteral("older"));
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->text(), QString::fromUtf8(older));
    QVERIFY(!view->latest());
    QVERIFY(!view->editable());
    view->selectVersion(QStringLiteral("base"));
    QTRY_VERIFY(!view->busy());
    session.runCommand(QStringLiteral("edit-tab"));
    QCOMPARE(view->tab(), QStringLiteral("edit"));
    QVERIFY(usable(session, QStringLiteral("save-document")));
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("upload_id"), QStringLiteral("next")},
            {QStringLiteral("generation"), 1}, {QStringLiteral("request"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/next")}}}}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads/next/complete")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("version"), QJsonObject{{QStringLiteral("id"), QStringLiteral("next-version")}}},
                                              {QStringLiteral("review"), QJsonValue::Null}}}});
    QSignalSpy saved(view, &matome::DocumentView::saved);
    const QString image = QStringLiteral("0b6f0c2e-3f7a-4c55-9d3e-8a1b2c3d4e5f");
    view->save(QStringLiteral("# Current\n\n![logo](matome:asset/7?version=%1)\nSee [plan](/Specs/plan.md).\n").arg(image), QStringLiteral("  "));
    QTRY_COMPARE(saved.size(), 1);
    QCOMPARE(view->notice(), QStringLiteral("version_published"));
    bool uploaded = false;
    for (const auto &call : backend.calls) if (call.method == "POST" && call.path.endsWith(QLatin1String("/uploads"))) {
        QCOMPARE(call.body.value(QStringLiteral("document_id")).toString(), QStringLiteral("41"));
        QCOMPARE(call.body.value(QStringLiteral("filename")).toString(), QStringLiteral("procedure.md"));
        QVERIFY(!call.body.contains(QStringLiteral("reason")));
        const QJsonArray references = call.body.value(QStringLiteral("references")).toArray();
        QCOMPARE(references.size(), 2);
        QCOMPARE(references.at(0).toObject().value(QStringLiteral("document_id")).toInteger(), 7);
        QCOMPARE(references.at(0).toObject().value(QStringLiteral("version_id")).toString(), image);
        QCOMPARE(references.at(1).toObject().value(QStringLiteral("path")).toString(), QStringLiteral("/Specs/plan.md"));
        uploaded = true;
    }
    QVERIFY(uploaded);
    QTRY_VERIFY(!view->busy());
    session.runCommand(QStringLiteral("edit-tab"));
    Client::Reply refused;
    refused.status = 422;
    refused.code = QStringLiteral("reference_not_found");
    refused.json = {{QStringLiteral("details"), QJsonObject{{QStringLiteral("index"), 0}}}};
    backend.queue("POST", matome::orgPath(org, QStringLiteral("uploads")), refused);
    view->save(QStringLiteral("![gone](matome:asset/8?version=%1)").arg(image), QStringLiteral("Swap"));
    QTRY_COMPARE(view->errorCode(), QStringLiteral("reference_not_found"));
    QCOMPARE(view->errorIndex(), 0);
    const QString pdf = matome::contentPath(org, space, QStringLiteral("documents/42"));
    QJsonObject manual{{QStringLiteral("id"), QStringLiteral("manual")}, {QStringLiteral("version_number"), 1},
                       {QStringLiteral("current"), true}, {QStringLiteral("publication_state"), QStringLiteral("published")},
                       {QStringLiteral("filename"), QStringLiteral("manual.pdf")}, {QStringLiteral("content_type"), QStringLiteral("application/pdf")},
                       {QStringLiteral("byte_size"), 2048}};
    serveDocument(backend, pdf, {{QStringLiteral("id"), 42}, {QStringLiteral("title"), QStringLiteral("manual.pdf")}}, {{manual, "%PDF"}});
    session.openEntry(QStringLiteral("document"), QStringLiteral("42"));
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->kind(), QStringLiteral("none"));
    QVERIFY(!view->textLoaded());
    QVERIFY(!usable(session, QStringLiteral("edit-tab")));
    QVERIFY(usable(session, QStringLiteral("download-version")));
    manual.insert(QStringLiteral("detected_content_type"), QStringLiteral("image/png"));
    serveDocument(backend, pdf, {{QStringLiteral("id"), 42}, {QStringLiteral("title"), QStringLiteral("photo.png")}}, {{manual, "\x89PNG"}});
    view->refresh();
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->kind(), QStringLiteral("image"));
    view->close();
    QVERIFY(!view->active());
    QVERIFY(usable(session, QStringLiteral("new")));
}

void TestCore::documentViewListsRelated()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QString other = matome::contentPath(org, space, QStringLiteral("documents/43"));
    const QByteArray current("# Current\n");
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")}},
                  {{markdownVersion(QStringLiteral("base"), 1, true, current), current}});
    serveDocument(backend, other, {{QStringLiteral("id"), 43}, {QStringLiteral("title"), QStringLiteral("notes.md")}},
                  {{markdownVersion(QStringLiteral("notes"), 1, true, current), current}});
    const QJsonObject logo{{QStringLiteral("position"), 0}, {QStringLiteral("mode"), QStringLiteral("version")},
        {QStringLiteral("document_id"), 7}, {QStringLiteral("target"), QJsonObject{{QStringLiteral("document_id"), 7},
            {QStringLiteral("title"), QStringLiteral("logo.png")}, {QStringLiteral("path"), QStringLiteral("/assets/logo.png")},
            {QStringLiteral("state"), QStringLiteral("ok")}}}};
    const QJsonObject gone{{QStringLiteral("position"), 1}, {QStringLiteral("mode"), QStringLiteral("path")},
        {QStringLiteral("path"), QStringLiteral("/gone.md")}, {QStringLiteral("target"), QJsonObject{{QStringLiteral("state"), QStringLiteral("broken")}}}};
    const QJsonObject index{{QStringLiteral("document_id"), 50}, {QStringLiteral("title"), QStringLiteral("index.md")},
                            {QStringLiteral("path"), QStringLiteral("/index.md")}, {QStringLiteral("modes"), QJsonArray{QStringLiteral("document")}}};
    backend.respond("GET", doc + QStringLiteral("/references?direction=both"), {{QStringLiteral("data"), QJsonObject{
        {QStringLiteral("incoming"), QJsonObject{{QStringLiteral("references"), QJsonArray{index}}, {QStringLiteral("hidden_count"), 2},
            {QStringLiteral("page"), QJsonObject{{QStringLiteral("has_more"), true}, {QStringLiteral("next_cursor"), QStringLiteral("c1")}}}}},
        {QStringLiteral("outgoing"), QJsonObject{{QStringLiteral("version_id"), QStringLiteral("base")}, {QStringLiteral("references"), QJsonArray{logo, gone}},
            {QStringLiteral("page"), QJsonObject{{QStringLiteral("has_more"), false}}}}}}}});
    backend.respond("GET", doc + QStringLiteral("/references?direction=incoming&cursor=c1"), {{QStringLiteral("data"), QJsonObject{
        {QStringLiteral("incoming"), QJsonObject{{QStringLiteral("references"), QJsonArray{QJsonObject{{QStringLiteral("document_id"), 51},
            {QStringLiteral("title"), QStringLiteral("plan.md")}}}}, {QStringLiteral("hidden_count"), 2},
            {QStringLiteral("page"), QJsonObject{{QStringLiteral("has_more"), false}}}}}}}});
    backend.respond("GET", other + QStringLiteral("/references?direction=both"), {{QStringLiteral("data"), QJsonObject{
        {QStringLiteral("incoming"), QJsonObject{{QStringLiteral("references"), QJsonArray()}, {QStringLiteral("hidden_count"), 0}}},
        {QStringLiteral("outgoing"), QJsonObject{{QStringLiteral("references"), QJsonArray()}}}}}});
    const auto asked = [&backend](const QString &path) {
        return std::count_if(backend.calls.cbegin(), backend.calls.cend(), [&path](const auto &call) {
            return call.path.startsWith(path + QStringLiteral("/references"));
        });
    };
    auto *view = session.documentView();
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QTRY_VERIFY(!view->busy());
    QVERIFY(usable(session, QStringLiteral("related-tab")));
    // Only the Related tab asks Core for the references.
    QCOMPARE(asked(doc), 0);
    session.runCommand(QStringLiteral("related-tab"));
    QCOMPARE(view->tab(), QStringLiteral("related"));
    QTRY_VERIFY(view->relatedLoaded());
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->incoming().size(), 1);
    QCOMPARE(view->incoming().constFirst().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("index.md"));
    QCOMPARE(view->hiddenCount(), 2);
    QVERIFY(view->incomingMore());
    QVERIFY(!view->outgoingMore());
    QCOMPARE(view->outgoing().size(), 2);
    QCOMPARE(view->outgoing().at(1).toMap().value(QStringLiteral("target")).toMap().value(QStringLiteral("state")).toString(),
             QStringLiteral("broken"));
    session.runCommand(QStringLiteral("view-tab"));
    session.runCommand(QStringLiteral("related-tab"));
    QCOMPARE(asked(doc), 1);
    view->loadMoreRelated(QStringLiteral("outgoing"));
    QCOMPARE(asked(doc), 1);
    view->loadMoreRelated(QStringLiteral("incoming"));
    QTRY_VERIFY(!view->busy());
    QCOMPARE(view->incoming().size(), 2);
    QCOMPARE(view->incoming().at(1).toMap().value(QStringLiteral("title")).toString(), QStringLiteral("plan.md"));
    QCOMPARE(view->outgoing().size(), 2);
    QVERIFY(!view->incomingMore());
    // Refreshing on the tab lists again; a reply for a document left behind
    // never lands on the next one.
    backend.delayMs = 30;
    view->refresh();
    QVERIFY(!view->relatedLoaded());
    session.openEntry(QStringLiteral("document"), QStringLiteral("43"));
    QTRY_VERIFY(!view->busy());
    QVERIFY(!view->relatedLoaded());
    QVERIFY(view->incoming().isEmpty());
    session.runCommand(QStringLiteral("related-tab"));
    QTRY_VERIFY(view->relatedLoaded());
    QVERIFY(view->incoming().isEmpty());
    QVERIFY(view->outgoing().isEmpty());
    QCOMPARE(view->hiddenCount(), 0);
    QTest::qWait(90);
    QVERIFY(view->incoming().isEmpty());
    view->close();
    QVERIFY(!view->relatedLoaded());
}

void TestCore::controlledDocsExtendDocumentView()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QString reviewPath = matome::orgPath(org, QStringLiteral("reviews/review-one"));
    const QByteArray current("# Current\n");
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")},
                                 {QStringLiteral("revision"), 3}, {QStringLiteral("controlled_docs_enabled"), true}},
                  {{markdownVersion(QStringLiteral("base"), 1, true, current), current}});
    QJsonObject review{{QStringLiteral("id"), QStringLiteral("review-one")}, {QStringLiteral("revision"), 5},
        {QStringLiteral("status"), QStringLiteral("open")}, {QStringLiteral("author_membership_id"), QStringLiteral("author")},
        {QStringLiteral("candidate_version_id"), QStringLiteral("candidate")}};
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), spaceAddOns(true));
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{review}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")),
                    {{QStringLiteral("members"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("author")},
                        {QStringLiteral("email"), session.identifier()}, {QStringLiteral("user_id"), session.userId()}}}}});
    const QJsonObject changedImage{{QStringLiteral("document_id"), 7}, {QStringLiteral("from_version_id"), QStringLiteral("before")},
                                   {QStringLiteral("to_version_id"), QStringLiteral("after")}};
    backend.respond("GET", reviewPath + QStringLiteral("/diff"), {{QStringLiteral("data"), QJsonObject{{QStringLiteral("diff"), QStringLiteral("-old\n+new")},
        {QStringLiteral("references"), QJsonObject{{QStringLiteral("added"), QJsonArray()}, {QStringLiteral("removed"), QJsonArray()},
                                                   {QStringLiteral("changed"), QJsonArray{changedImage}}}}}}});
    backend.respond("GET", reviewPath + QStringLiteral("/candidate/download"), {{QStringLiteral("data"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/candidate")}}}});
    backend.file(QUrl(QStringLiteral("https://storage.invalid/candidate")), QByteArray("# Candidate\n"));
    auto *view = session.documentView();
    auto *control = session.controlledDocs();
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QTRY_VERIFY(!view->busy());
    QTRY_VERIFY(control->active());
    QTRY_VERIFY(!control->busy());
    QVERIFY(control->controlled());
    QCOMPARE(control->openReviews(), 1);
    QVERIFY(usable(session, QStringLiteral("reviews-tab")));
    QVERIFY(!usable(session, QStringLiteral("manage-document")));
    QVERIFY(usable(session, QStringLiteral("unmanage-document")));
    // The list selects the first review; only opening it loads it and
    // brings its decisions.
    QCOMPARE(control->selectedReviewId(), QStringLiteral("review-one"));
    QVERIFY(control->review().isEmpty());
    QVERIFY(!usable(session, QStringLiteral("open-review")));
    QVERIFY(!usable(session, QStringLiteral("cancel-review")));
    session.runCommand(QStringLiteral("reviews-tab"));
    QVERIFY(usable(session, QStringLiteral("open-review")));
    session.runCommand(QStringLiteral("open-review"));
    QTRY_VERIFY(!control->busy());
    QVERIFY(usable(session, QStringLiteral("close-review")));
    QVERIFY(usable(session, QStringLiteral("cancel-review")));
    QVERIFY(!usable(session, QStringLiteral("open-review")));
    QCOMPARE(control->diff(), QStringLiteral("-old\n+new"));
    QCOMPARE(control->candidate(), QStringLiteral("# Candidate\n"));
    QCOMPARE(control->diffReferences().value(QStringLiteral("changed")).toList().constFirst().toMap()
                     .value(QStringLiteral("to_version_id")).toString(), QStringLiteral("after"));
    QVERIFY(!control->canReject());
    const int hits = backend.calls.size();
    control->decide(QStringLiteral("approve"), {});
    QCOMPARE(backend.calls.size(), hits);
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")),
                    {{QStringLiteral("members"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("reviewer")},
                        {QStringLiteral("email"), session.identifier()}, {QStringLiteral("user_id"), session.userId()}}}}});
    control->refresh();
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->review().value(QStringLiteral("id")).toString(), QStringLiteral("review-one"));
    QCOMPARE(control->candidate(), QStringLiteral("# Candidate\n"));
    QVERIFY(control->canReject());
    backend.respond("POST", reviewPath + QStringLiteral("/approve"), {}, 409, QStringLiteral("review_closed"));
    control->decide(QStringLiteral("approve"), QStringLiteral("checked"));
    const auto decision = backend.calls.constLast();
    QCOMPARE(decision.body.value(QStringLiteral("candidate_version_id")).toString(), QStringLiteral("candidate"));
    QCOMPARE(decision.headers.first().second, QByteArray("5"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->errorCode(), QStringLiteral("review_closed"));
    session.runCommand(QStringLiteral("close-review"));
    QVERIFY(control->review().isEmpty());
    QVERIFY(control->candidate().isEmpty());
    session.runCommand(QStringLiteral("open-review"));
    QTRY_VERIFY(!control->busy());
    // Leaving the Reviews tab closes the review.
    session.runCommand(QStringLiteral("view-tab"));
    QVERIFY(control->review().isEmpty());
    // Saving opens a second review; it becomes the selected one, not the
    // older review that was still selected.
    QJsonObject second = review;
    second.insert(QStringLiteral("id"), QStringLiteral("review-two"));
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{second, review}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("upload_id"), QStringLiteral("proposal")},
            {QStringLiteral("generation"), 1}, {QStringLiteral("request"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/proposal")}}}}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads/proposal/complete")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("version"), QJsonObject{{QStringLiteral("id"), QStringLiteral("proposed")}}},
            {QStringLiteral("review"), QJsonObject{{QStringLiteral("id"), QStringLiteral("review-two")}, {QStringLiteral("status"), QStringLiteral("open")}}}}}});
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->selectedReviewId(), QStringLiteral("review-one"));
    session.runCommand(QStringLiteral("edit-tab"));
    QSignalSpy saved(view, &matome::DocumentView::saved);
    view->save(QStringLiteral("# Proposal\n"), QStringLiteral("Second change"));
    QTRY_COMPARE(saved.size(), 1);
    QCOMPARE(saved.constFirst().constFirst().toString(), QStringLiteral("review-two"));
    QCOMPARE(view->notice(), QStringLiteral("review_requested"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->selectedReviewId(), QStringLiteral("review-two"));
    session.runCommand(QStringLiteral("reviews-tab"));
    session.runCommand(QStringLiteral("open-review"));
    QCOMPARE(control->review().value(QStringLiteral("id")).toString(), QStringLiteral("review-two"));
    session.runCommand(QStringLiteral("close-review"));
    QTRY_VERIFY(!control->busy());
    backend.respond("DELETE", doc + QStringLiteral("/controlled-docs"), {});
    control->setControlled(false, QStringLiteral(" Retire "));
    const auto unmanaged = backend.calls.constLast();
    QCOMPARE(unmanaged.method, QByteArray("DELETE"));
    QCOMPARE(unmanaged.path, doc + QStringLiteral("/controlled-docs"));
    QCOMPARE(unmanaged.body.value(QStringLiteral("reason")).toString(), QStringLiteral("Retire"));
    QVERIFY(unmanaged.headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("3"))));
    QTRY_VERIFY(!control->busy());
    view->close();
    QVERIFY(!control->active());
    QVERIFY(control->reviews().isEmpty());
    const QString plain = matome::contentPath(org, space, QStringLiteral("documents/43"));
    serveDocument(backend, plain, {{QStringLiteral("id"), 43}, {QStringLiteral("title"), QStringLiteral("notes.md")}},
                  {{markdownVersion(QStringLiteral("notes"), 1, true, current), current}});
    session.openEntry(QStringLiteral("document"), QStringLiteral("43"));
    QTRY_VERIFY(!view->busy());
    QVERIFY(!control->active());
    QVERIFY(!usable(session, QStringLiteral("reviews-tab")));
}

// Each proposal is its own review. One that fell behind a later publication
// is updated in one step; one that conflicts goes to the editor with Core's
// markers; only a clean one can be approved.
void TestCore::controlledDocsRunParallelReviews()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QByteArray current("# Current\n");
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")},
                                 {QStringLiteral("revision"), 3}, {QStringLiteral("controlled_docs_enabled"), true}},
                  {{markdownVersion(QStringLiteral("v1"), 1, false, "# First\n"), "# First\n"},
                   {markdownVersion(QStringLiteral("v2"), 2, true, current), current}});
    const auto reviewRow = [](const QString &id, const QString &status, const QString &merge) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("revision"), 4}, {QStringLiteral("status"), status},
                           {QStringLiteral("merge_state"), merge}, {QStringLiteral("reason"), id + QStringLiteral(" reason")},
                           {QStringLiteral("author_membership_id"), QStringLiteral("author")},
                           {QStringLiteral("base_version_id"), QStringLiteral("v1")},
                           {QStringLiteral("candidate_version_id"), id + QStringLiteral("-candidate")}};
    };
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), spaceAddOns(true));
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{
        reviewRow(QStringLiteral("done"), QStringLiteral("approved"), QStringLiteral("clean")),
        reviewRow(QStringLiteral("behind"), QStringLiteral("open"), QStringLiteral("behind")),
        reviewRow(QStringLiteral("dirty"), QStringLiteral("open"), QStringLiteral("dirty"))}}});
    const auto member = [&backend, &session, org](const QString &id) {
        backend.respond("GET", matome::orgPath(org, QStringLiteral("members")),
                        {{QStringLiteral("members"), QJsonArray{QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("email"), session.identifier()}, {QStringLiteral("user_id"), session.userId()}}}}});
    };
    member(QStringLiteral("author"));
    for (const QString &id : {QStringLiteral("behind"), QStringLiteral("dirty")}) {
        const QString path = matome::orgPath(org, QStringLiteral("reviews/") + id);
        backend.respond("GET", path + QStringLiteral("/diff"), {{QStringLiteral("data"), QJsonObject{{QStringLiteral("diff"), QString()}}}});
        backend.respond("GET", path + QStringLiteral("/candidate/download"),
                        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/") + id}}}});
        backend.file(QUrl(QStringLiteral("https://storage.invalid/") + id), QByteArray("# Proposal\n"));
    }
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("upload_id"), QStringLiteral("up")}, {QStringLiteral("generation"), 1},
            {QStringLiteral("request"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/up")}}}}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads/up/complete")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("version"), QJsonObject{{QStringLiteral("id"), QStringLiteral("next")}}},
            {QStringLiteral("review"), QJsonObject{{QStringLiteral("id"), QStringLiteral("behind")}, {QStringLiteral("status"), QStringLiteral("open")}}}}}});
    const auto lastUpload = [&backend]() {
        for (auto it = backend.calls.crbegin(); it != backend.calls.crend(); ++it)
            if (it->method == "POST" && it->path.endsWith(QLatin1String("/uploads"))) return it->body;
        return QJsonObject();
    };
    auto *view = session.documentView();
    auto *control = session.controlledDocs();
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QTRY_VERIFY(control->active());
    QTRY_VERIFY(!control->busy() && !view->busy());
    QCOMPARE(control->openReviews(), 2);
    QStringList order;
    for (const auto &row : control->reviews()) order.append(row.toMap().value(QStringLiteral("id")).toString());
    QCOMPARE(order, (QStringList{QStringLiteral("behind"), QStringLiteral("dirty"), QStringLiteral("done")}));
    // A new proposal names the published version it was edited from.
    QCOMPARE(control->proposal(), (QVariantMap{{QStringLiteral("base_version_id"), QStringLiteral("v2")}}));
    session.runCommand(QStringLiteral("edit-tab"));
    view->save(QStringLiteral("# Mine\n"), QStringLiteral("Third change"), true, control->proposal());
    QTRY_VERIFY(!view->busy());
    QCOMPARE(lastUpload().value(QStringLiteral("base_version_id")).toString(), QStringLiteral("v2"));
    QVERIFY(!lastUpload().contains(QStringLiteral("review_id")));
    QTRY_VERIFY(!control->busy());

    session.runCommand(QStringLiteral("reviews-tab"));
    control->selectReview(QStringLiteral("behind"));
    session.runCommand(QStringLiteral("open-review"));
    QTRY_VERIFY(!control->busy());
    QVERIFY(control->authored());
    QVERIFY(usable(session, QStringLiteral("update-review")));
    QVERIFY(usable(session, QStringLiteral("edit-proposal")));
    QVERIFY(!usable(session, QStringLiteral("resolve-conflicts")));
    const QString behindPath = matome::orgPath(org, QStringLiteral("reviews/behind"));
    backend.respond("GET", behindPath + QStringLiteral("/merge"), {{QStringLiteral("data"), QJsonObject{
        {QStringLiteral("merge_state"), QStringLiteral("behind")}, {QStringLiteral("target_version_id"), QStringLiteral("v2")},
        {QStringLiteral("conflicts"), 0}, {QStringLiteral("content"), QStringLiteral("# Merged\n")}}}});
    session.runCommand(QStringLiteral("update-review"));
    QTRY_COMPARE(control->notice(), QStringLiteral("review_updated"));
    const QJsonObject update = lastUpload();
    QCOMPARE(update.value(QStringLiteral("review_id")).toString(), QStringLiteral("behind"));
    QCOMPARE(update.value(QStringLiteral("base_version_id")).toString(), QStringLiteral("v2"));
    QCOMPARE(update.value(QStringLiteral("reason")).toString(), QStringLiteral("behind reason"));
    QCOMPARE(update.value(QStringLiteral("filename")).toString(), QStringLiteral("procedure.md"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->selectedReviewId(), QStringLiteral("behind"));

    // A reviewer may reject a review that is behind, never approve it.
    member(QStringLiteral("reviewer"));
    control->refresh();
    QTRY_VERIFY(!control->busy());
    QVERIFY(!control->authored());
    QVERIFY(control->canReject());
    QVERIFY(!control->canApprove());
    QVERIFY(!usable(session, QStringLiteral("approve-review")));
    QVERIFY(usable(session, QStringLiteral("reject-review")));
    QVERIFY(!usable(session, QStringLiteral("update-review")));
    const int calls = backend.calls.size();
    control->decide(QStringLiteral("approve"), {});
    QCOMPARE(backend.calls.size(), calls);

    member(QStringLiteral("author"));
    session.runCommand(QStringLiteral("close-review"));
    control->refresh();
    QTRY_VERIFY(!control->busy());
    control->selectReview(QStringLiteral("dirty"));
    session.runCommand(QStringLiteral("open-review"));
    QTRY_VERIFY(!control->busy());
    QVERIFY(usable(session, QStringLiteral("resolve-conflicts")));
    QVERIFY(!usable(session, QStringLiteral("update-review")));
    QVERIFY(!usable(session, QStringLiteral("edit-proposal")));
    const QString marked = QStringLiteral("<<<<<<< published\n# Current\n=======\n# Mine\n>>>>>>> review\n");
    backend.respond("GET", matome::orgPath(org, QStringLiteral("reviews/dirty/merge")), {{QStringLiteral("data"), QJsonObject{
        {QStringLiteral("merge_state"), QStringLiteral("dirty")}, {QStringLiteral("target_version_id"), QStringLiteral("v2")},
        {QStringLiteral("conflicts"), 1}, {QStringLiteral("content"), marked}}}});
    QSignalSpy ready(control, &matome::ControlledDocs::proposalReady);
    const int uploads = int(std::count_if(backend.calls.cbegin(), backend.calls.cend(),
                                          [](const auto &call) { return call.path.endsWith(QLatin1String("/uploads")); }));
    session.runCommand(QStringLiteral("resolve-conflicts"));
    QTRY_COMPARE(ready.size(), 1);
    QCOMPARE(ready.constFirst().at(0).toString(), marked);
    QCOMPARE(ready.constFirst().at(1).toInt(), 1);
    QCOMPARE(int(std::count_if(backend.calls.cbegin(), backend.calls.cend(),
                               [](const auto &call) { return call.path.endsWith(QLatin1String("/uploads")); })), uploads);
    QCOMPARE(control->proposalReviewId(), QStringLiteral("dirty"));
    QCOMPARE(control->proposal(), (QVariantMap{{QStringLiteral("review_id"), QStringLiteral("dirty")},
                                               {QStringLiteral("base_version_id"), QStringLiteral("v2")}}));
    session.runCommand(QStringLiteral("edit-tab"));
    view->save(QStringLiteral("# Resolved\n"), QStringLiteral("Kept both"), true, control->proposal());
    QTRY_VERIFY(!view->busy());
    QCOMPARE(lastUpload().value(QStringLiteral("review_id")).toString(), QStringLiteral("dirty"));
    QCOMPARE(view->notice(), QStringLiteral("review_updated"));
    // Once saved, or when the editor goes back to the published text, it no
    // longer holds the review's proposal.
    QVERIFY(control->proposalReviewId().isEmpty());
    view->close();
    QVERIFY(control->proposal().isEmpty());
}

// A review keeps the settings it was submitted with: how many distinct
// approvers publish it and whether its author may be one of them. An
// approval short of the count leaves it open, and its approver cannot
// approve it again.
void TestCore::controlledDocsCountApprovals()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QString path = matome::orgPath(org, QStringLiteral("reviews/pending"));
    const QByteArray current("# Current\n");
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")},
                                 {QStringLiteral("revision"), 3}, {QStringLiteral("controlled_docs_enabled"), true}},
                  {{markdownVersion(QStringLiteral("v1"), 1, true, current), current}});
    const auto review = [](bool authorMayApprove, const QJsonArray &approvals) {
        return QJsonObject{{QStringLiteral("id"), QStringLiteral("pending")}, {QStringLiteral("revision"), 4},
            {QStringLiteral("status"), QStringLiteral("open")}, {QStringLiteral("merge_state"), QStringLiteral("clean")},
            {QStringLiteral("author_membership_id"), QStringLiteral("author")},
            {QStringLiteral("base_version_id"), QStringLiteral("v1")}, {QStringLiteral("candidate_version_id"), QStringLiteral("candidate")},
            {QStringLiteral("settings"), QJsonObject{{QStringLiteral("required_approvals"), 2},
                {QStringLiteral("allow_author_approval"), authorMayApprove}, {QStringLiteral("require_version_references"), true}}},
            {QStringLiteral("approvals"), approvals}};
    };
    const QJsonArray approvedByAuthor{QJsonObject{{QStringLiteral("id"), QStringLiteral("approval")},
        {QStringLiteral("approving_membership_id"), QStringLiteral("author")}, {QStringLiteral("candidate_version_id"), QStringLiteral("candidate")}}};
    // The space's settings are for who may turn the add-on on: the open
    // review says links must pin.
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), {}, 403, QStringLiteral("forbidden"));
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{review(true, {})}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")),
                    {{QStringLiteral("members"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("author")},
                        {QStringLiteral("email"), session.identifier()}, {QStringLiteral("user_id"), session.userId()}}}}});
    backend.respond("GET", path + QStringLiteral("/diff"), {{QStringLiteral("data"), QJsonObject{{QStringLiteral("diff"), QString()}}}});
    backend.respond("GET", path + QStringLiteral("/candidate/download"),
                    {{QStringLiteral("data"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/pending")}}}});
    backend.file(QUrl(QStringLiteral("https://storage.invalid/pending")), QByteArray("# Proposal\n"));
    auto *control = session.controlledDocs();
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QTRY_VERIFY(control->active());
    QTRY_VERIFY(!control->busy());
    QVERIFY(control->pinsLinks());
    session.runCommand(QStringLiteral("reviews-tab"));
    session.runCommand(QStringLiteral("open-review"));
    QTRY_VERIFY(!control->busy());
    QVERIFY(control->authored());
    QVERIFY(control->authorMayApprove());
    QCOMPARE(control->requiredApprovals(), 2);
    QCOMPARE(control->approvals(), 0);
    QVERIFY(control->canApprove());
    QVERIFY(!control->canReject());
    QVERIFY(usable(session, QStringLiteral("approve-review")));
    QVERIFY(!usable(session, QStringLiteral("reject-review")));

    backend.respond("POST", path + QStringLiteral("/approve"), {{QStringLiteral("data"), review(true, approvedByAuthor)}});
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{review(true, approvedByAuthor)}}});
    control->decide(QStringLiteral("approve"), {});
    QTRY_COMPARE(control->notice(), QStringLiteral("review_approval_added"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->review().value(QStringLiteral("status")).toString(), QStringLiteral("open"));
    QCOMPARE(control->approvals(), 1);
    QVERIFY(control->approved());
    QVERIFY(!control->canApprove());
    const int calls = backend.calls.size();
    control->decide(QStringLiteral("approve"), {});
    QCOMPARE(backend.calls.size(), calls);

    // Without the setting, the author may neither approve nor reject.
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray{review(false, {})}}});
    control->refresh();
    QTRY_VERIFY(!control->busy());
    QVERIFY(!control->authorMayApprove());
    QVERIFY(!control->approved());
    QVERIFY(!control->canApprove());
    QVERIFY(!control->canReject());
}

void TestCore::accessDirectoryManagesGroupsRolesTagsAndSpaces()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId();
    seedDirectory(backend, org);
    auto *directory = session.accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    QCOMPARE(directory->errorCode(), QString());
    // The reserved action never reaches the editor; areas come from the key.
    QCOMPARE(directory->catalog().size(), 3);
    QCOMPARE(directory->catalog().constFirst().toMap().value(QStringLiteral("area")).toString(), QStringLiteral("content"));
    QCOMPARE(directory->catalog().at(1).toMap().value(QStringLiteral("area")).toString(), QStringLiteral("addon.controlled_docs"));
    // A role applies to the organization when built in for it or holding an
    // organization action; only built-in space roles are never assigned.
    const auto field = [directory](const QString &id, const QString &name) {
        for (const auto &role : directory->roles())
            if (role.toMap().value(QStringLiteral("id")) == id) return role.toMap().value(name);
        return QVariant();
    };
    QCOMPARE(field(QStringLiteral("owner-role"), QStringLiteral("appliesTo")).toString(), QStringLiteral("organization"));
    QCOMPARE(field(QStringLiteral("viewer-role"), QStringLiteral("appliesTo")).toString(), QStringLiteral("space"));
    QCOMPARE(field(QStringLiteral("custom-role"), QStringLiteral("appliesTo")).toString(), QStringLiteral("organization"));
    QVERIFY(field(QStringLiteral("owner-role"), QStringLiteral("assignable")).toBool());
    QVERIFY(!field(QStringLiteral("viewer-role"), QStringLiteral("assignable")).toBool());
    QVERIFY(field(QStringLiteral("custom-role"), QStringLiteral("assignable")).toBool());
    QCOMPARE(directory->members().constFirst().toMap().value(QStringLiteral("email")).toString(), QStringLiteral("ana@example.com"));
    QVERIFY(!directory->members().constFirst().toMap().value(QStringLiteral("managed")).toBool());
    // Built-in organization roles and custom ones are given across the organization.
    QCOMPARE(directory->assignableRoles().size(), 2);
    // Grants carry every role but those that apply only across the organization.
    QStringList grantable;
    for (const auto &role : directory->grantableRoles()) grantable.append(role.toMap().value(QStringLiteral("id")).toString());
    QCOMPARE(grantable, (QStringList{QStringLiteral("viewer-role"), QStringLiteral("custom-role")}));
    const auto legal = directory->groups().constFirst().toMap();
    QCOMPARE(legal.value(QStringLiteral("members")).toList().constFirst().toMap().value(QStringLiteral("label")).toString(),
             QStringLiteral("bo@example.com"));
    QCOMPARE(directory->principals(false).size(), 3);
    QCOMPARE(directory->principals(true).size(), 6);
    QCOMPARE(directory->principalName(QStringLiteral("group:g1")), QStringLiteral("Legal"));

    // A reload that reads the same rows does not say the lists changed.
    QSignalSpy listed(directory, &matome::AccessDirectory::listsChanged);
    directory->open();
    QVERIFY(directory->busy());
    QTRY_VERIFY(!directory->busy());
    QCOMPARE(listed.size(), 0);

    QSignalSpy saved(directory, &matome::AccessDirectory::saved);
    backend.respond("POST", matome::orgPath(org, QStringLiteral("groups")),
                    {{QStringLiteral("group"), QJsonObject{{QStringLiteral("id"), QStringLiteral("g2")}}}}, 201);
    directory->createGroup(QStringLiteral("  Ops "));
    QTRY_COMPARE(saved.size(), 1);
    QCOMPARE(saved.constLast().at(0).toString(), QStringLiteral("group_created"));
    QCOMPARE(saved.constLast().at(1).toString(), QStringLiteral("g2"));
    const auto created = lastCall(backend, "POST", matome::orgPath(org, QStringLiteral("groups")));
    QCOMPARE(created.body.value(QStringLiteral("name")).toString(), QStringLiteral("Ops"));
    QVERIFY(!created.headers.isEmpty() && created.headers.constFirst().first == QByteArrayLiteral("Idempotency-Key"));
    QTRY_VERIFY(!directory->busy());

    // A group's members are set by what changes: Ana joins Legal and Bo,
    // already in it, stays; then Bo leaves.
    const QString groupMembers = matome::orgPath(org, QStringLiteral("groups/g1/members"));
    backend.respond("POST", groupMembers, {}, 201);
    auto sent = backend.calls.size();
    directory->setGroupMembers(QStringLiteral("g1"), {QStringLiteral("m1"), QStringLiteral("m2"), QStringLiteral("gone")});
    QTRY_COMPARE(directory->notice(), QStringLiteral("group_members_saved"));
    QCOMPARE(lastCall(backend, "POST", groupMembers).body.value(QStringLiteral("organization_membership_id")).toString(), QStringLiteral("m1"));
    QCOMPARE(callAt(backend, "POST", groupMembers, callAt(backend, "POST", groupMembers, sent) + 1), -1);
    QCOMPARE(callAt(backend, "DELETE", groupMembers + QStringLiteral("/m2"), sent), -1);
    QTRY_VERIFY(!directory->busy());
    backend.respond("DELETE", groupMembers + QStringLiteral("/m2"), {});
    sent = backend.calls.size();
    directory->setGroupMembers(QStringLiteral("g1"), {});
    QTRY_COMPARE(directory->notice(), QStringLiteral("group_members_saved"));
    QVERIFY(callAt(backend, "DELETE", groupMembers + QStringLiteral("/m2"), sent) >= 0);
    QTRY_VERIFY(!directory->busy());
    // A member's groups are set by what changes: Bo leaves Legal, Ana joins it.
    sent = backend.calls.size();
    directory->setMemberGroups(QStringLiteral("m2"), {QStringLiteral("g1")});
    QCOMPARE(backend.calls.size(), sent);
    directory->setMemberGroups(QStringLiteral("m2"), {});
    QTRY_COMPARE(directory->notice(), QStringLiteral("groups_saved"));
    QVERIFY(callAt(backend, "DELETE", groupMembers + QStringLiteral("/m2"), sent) >= 0);
    QTRY_VERIFY(!directory->busy());
    // A refusal says why and names no notice; whatever landed reloads.
    backend.respond("POST", groupMembers, {}, 404, QStringLiteral("not_found"));
    sent = backend.calls.size();
    directory->setMemberGroups(QStringLiteral("m1"), {QStringLiteral("g1")});
    QTRY_COMPARE(directory->errorCode(), QStringLiteral("not_found"));
    QVERIFY(directory->notice().isEmpty());
    QTRY_VERIFY(callAt(backend, "GET", groupMembers, sent) >= 0);
    QTRY_VERIFY(!directory->busy());

    backend.respond("POST", matome::orgPath(org, QStringLiteral("roles")),
                    {{QStringLiteral("role"), QJsonObject{{QStringLiteral("id"), QStringLiteral("r2")}}}}, 201);
    directory->createRole(QStringLiteral("Auditors"), {QStringLiteral("content.download")});
    QTRY_COMPARE(directory->notice(), QStringLiteral("role_created"));
    const auto role = lastCall(backend, "POST", matome::orgPath(org, QStringLiteral("roles"))).body;
    QVERIFY(role.value(QStringLiteral("key")).toString().startsWith(QLatin1String("custom-")));
    QCOMPARE(role.value(QStringLiteral("actions")).toArray(), QJsonArray{QStringLiteral("content.download")});
    QTRY_VERIFY(!directory->busy());
    // Built-in roles do not change.
    const auto before = backend.calls.size();
    directory->updateRole(QStringLiteral("viewer-role"), QStringLiteral("Viewers"), {QStringLiteral("content.download")});
    directory->archiveRole(QStringLiteral("viewer-role"));
    QCOMPARE(backend.calls.size(), before);
    backend.respond("PATCH", matome::orgPath(org, QStringLiteral("roles/custom-role")), {});
    directory->updateRole(QStringLiteral("custom-role"), QStringLiteral("Reviewers"), {QStringLiteral("addon.controlled_docs.review_read")});
    QTRY_COMPARE(directory->notice(), QStringLiteral("role_saved"));
    QTRY_VERIFY(!directory->busy());

    backend.respond("POST", matome::orgPath(org, QStringLiteral("tags")),
                    {{QStringLiteral("tag"), QJsonObject{{QStringLiteral("id"), QStringLiteral("t2")}}}}, 201);
    directory->createTag(QStringLiteral("Draft"), false);
    QTRY_COMPARE(directory->notice(), QStringLiteral("tag_created"));
    QCOMPARE(lastCall(backend, "POST", matome::orgPath(org, QStringLiteral("tags"))).body.value(QStringLiteral("access_controlled")), QJsonValue(false));
    QTRY_VERIFY(!directory->busy());
    // Lifting a restriction sends the `false` rather than leaving it out.
    backend.respond("PATCH", matome::orgPath(org, QStringLiteral("tags/t1")), {});
    directory->updateTag(QStringLiteral("t1"), QStringLiteral("Secret"), false);
    QTRY_COMPARE(directory->notice(), QStringLiteral("tag_opened"));
    const auto lifted = lastCall(backend, "PATCH", matome::orgPath(org, QStringLiteral("tags/t1"))).body;
    QVERIFY(lifted.contains(QStringLiteral("access_controlled")));
    QVERIFY(!lifted.value(QStringLiteral("access_controlled")).toBool());
    QTRY_VERIFY(!directory->busy());
    for (const auto &[leaf, archive] : {std::pair{QStringLiteral("tags/t1/archive"), &matome::AccessDirectory::archiveTag},
                                        std::pair{QStringLiteral("groups/g1/archive"), &matome::AccessDirectory::archiveGroup},
                                        std::pair{QStringLiteral("roles/custom-role/archive"), &matome::AccessDirectory::archiveRole}}) {
        backend.respond("POST", matome::orgPath(org, leaf), {});
        (directory->*archive)(leaf.section(QLatin1Char('/'), 1, 1));
        QTRY_VERIFY(directory->notice().endsWith(QLatin1String("_archived")));
        QVERIFY(!lastCall(backend, "POST", matome::orgPath(org, leaf)).method.isEmpty());
        QTRY_VERIFY(!directory->busy());
    }

    // A space is renamed, trimmed, and archived on Core's space routes.
    backend.respond("PATCH", matome::orgPath(org, QStringLiteral("spaces/s1")), {});
    directory->renameSpace(QStringLiteral("s1"), QStringLiteral("  Agreements "));
    QTRY_COMPARE(directory->notice(), QStringLiteral("space_renamed"));
    QCOMPARE(lastCall(backend, "PATCH", matome::orgPath(org, QStringLiteral("spaces/s1"))).body,
             (QJsonObject{{QStringLiteral("name"), QStringLiteral("Agreements")}}));
    QTRY_VERIFY(!directory->busy());
    backend.respond("POST", matome::orgPath(org, QStringLiteral("spaces/s1/archive")), {});
    directory->archiveSpace(QStringLiteral("s1"));
    QTRY_COMPARE(directory->notice(), QStringLiteral("space_archived"));
    QVERIFY(!lastCall(backend, "POST", matome::orgPath(org, QStringLiteral("spaces/s1/archive"))).method.isEmpty());
    QTRY_VERIFY(!directory->busy());
    // No name, or no space, sends nothing.
    const auto unnamed = backend.calls.size();
    directory->renameSpace(QStringLiteral("s1"), QStringLiteral("  "));
    directory->archiveSpace(QString());
    QCOMPARE(backend.calls.size(), unnamed);

    saved.clear();
    backend.respond("POST", matome::orgPath(org, QStringLiteral("groups")), {}, 409, QStringLiteral("already_exists"));
    directory->createGroup(QStringLiteral("Legal"));
    QTRY_COMPARE(directory->errorCode(), QStringLiteral("already_exists"));
    QVERIFY(saved.isEmpty());

    // Another organization closes the directory.
    directory->close();
    QVERIFY(!directory->active());
    QVERIFY(directory->groups().isEmpty());
}

// The explorer offers what the current space's action catalog allows once
// it speaks for the space; access held only below the space leaves Core to
// decide.
void TestCore::explorerFollowsTheSpaceCatalog()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString catalog = matome::orgPath(org, QStringLiteral("action-catalog?space_id=") + space);
    QTRY_VERIFY(callAt(backend, "GET", catalog) >= 0);
    QVERIFY(usable(session, QStringLiteral("upload")));
    const auto allowing = [](const QStringList &keys) {
        QJsonArray actions;
        for (const QString &key : {QStringLiteral("content.list"), QStringLiteral("content.download"),
                                   QStringLiteral("upload.create"), QStringLiteral("folder.create")})
            actions.append(QJsonObject{{QStringLiteral("key"), key}, {QStringLiteral("allowed"), keys.contains(key)}});
        return QJsonObject{{QStringLiteral("actions"), actions}};
    };
    // Read in the space: no uploads and no new folders.
    backend.respond("GET", catalog, allowing({QStringLiteral("content.list"), QStringLiteral("content.download")}));
    session.runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(!usable(session, QStringLiteral("upload")));
    QVERIFY(!usable(session, QStringLiteral("new")));
    QVERIFY(usable(session, QStringLiteral("refresh")));
    // Edit there brings them back.
    backend.respond("GET", catalog, allowing({QStringLiteral("content.list"), QStringLiteral("upload.create"),
                                              QStringLiteral("folder.create")}));
    session.runCommand(QStringLiteral("refresh"));
    QTRY_VERIFY(usable(session, QStringLiteral("upload")));
    QVERIFY(usable(session, QStringLiteral("new")));
    // Without listing the space, the catalog does not speak for it.
    backend.respond("GET", catalog, allowing({}));
    session.runCommand(QStringLiteral("refresh"));
    const auto read = backend.calls.size();
    QTRY_VERIFY(callAt(backend, "GET", catalog, read - 1) >= 0);
    QTest::qWait(10);
    QVERIFY(usable(session, QStringLiteral("upload")));
    QVERIFY(usable(session, QStringLiteral("new")));
}

// A refusal says what is missing, from the space's catalog, the add-on's
// state, and the roles that hold the action, and names the command that
// fixes it, usable by whoever may carry it out from Settings. Roles made of
// grant-bound space actions are offered only on places.
void TestCore::permissionsExplainRefusals()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString manage = QStringLiteral("addon.controlled_docs.document_manage");
    const auto action = [](const QString &key, const QString &axis, bool allowed, bool bound = false, const QString &product = {}) {
        QJsonObject row{{QStringLiteral("key"), key}, {QStringLiteral("axis"), axis}, {QStringLiteral("allowed"), allowed},
                        {QStringLiteral("resource_grant"), bound}};
        if (!product.isEmpty()) row.insert(QStringLiteral("product_key"), product);
        return row;
    };
    serveControlledDocs(backend, org);
    // The organization: add-ons read and installed, grants read, no billing.
    backend.respond("GET", matome::orgPath(org, QStringLiteral("action-catalog")), {{QStringLiteral("actions"), QJsonArray{
        action(QStringLiteral("add_on.read"), QStringLiteral("organization"), true),
        action(QStringLiteral("add_on.install"), QStringLiteral("organization"), true),
        action(QStringLiteral("billing.manage"), QStringLiteral("organization"), false),
        action(QStringLiteral("role.read"), QStringLiteral("organization"), true),
        action(QStringLiteral("resource_grant.read"), QStringLiteral("space"), true),
        action(QStringLiteral("content.list"), QStringLiteral("space"), false, true),
        action(QStringLiteral("upload.create"), QStringLiteral("space"), false, true),
        action(manage, QStringLiteral("space"), false, true, QStringLiteral("controlled_docs"))}}});
    const auto role = [](const QString &id, const QString &key, const QString &origin, const QStringList &actions) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("key"), key}, {QStringLiteral("name"), key},
                           {QStringLiteral("origin"), origin}, {QStringLiteral("actions"), QJsonArray::fromStringList(actions)}};
    };
    backend.respond("GET", matome::orgPath(org, QStringLiteral("roles")), {{QStringLiteral("roles"), QJsonArray{
        role(QStringLiteral("r-member"), QStringLiteral("member"), QStringLiteral("system"), {QStringLiteral("content.list"), QStringLiteral("role.read")}),
        role(QStringLiteral("r-billing"), QStringLiteral("billing"), QStringLiteral("system"), {QStringLiteral("billing.manage")}),
        role(QStringLiteral("r-owner"), QStringLiteral("owner"), QStringLiteral("system"), {QStringLiteral("billing.manage"), QStringLiteral("role.read")}),
        role(QStringLiteral("r-manager"), QStringLiteral("content_manager"), QStringLiteral("system"),
             {QStringLiteral("content.list"), QStringLiteral("upload.create"), QStringLiteral("document.purge")}),
        role(QStringLiteral("r-contributor"), QStringLiteral("content_contributor"), QStringLiteral("system"),
             {QStringLiteral("content.list"), QStringLiteral("upload.create")}),
        role(QStringLiteral("r-docs"), QStringLiteral("addon.controlled_docs.manager"), QStringLiteral("add_on"), {manage}),
        role(QStringLiteral("r-mixed"), QStringLiteral("custom-mixed"), QStringLiteral("organization"), {manage, QStringLiteral("role.read")})}}});
    QVERIFY(followCatalog(session));
    auto *permissions = session.permissions();
    QVERIFY(permissions->known(org));
    QVERIFY(!permissions->known(QStringLiteral("elsewhere")));
    QCOMPARE(permissions->sections(org), (QStringList{QStringLiteral("spaces"), QStringLiteral("addons")}));
    auto *directory = session.accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    // Grant-bound space actions alone: given on places only.
    const auto row = [directory](const QString &id) {
        for (const auto &value : directory->roles())
            if (value.toMap().value(QStringLiteral("id")) == id) return value.toMap();
        return QVariantMap();
    };
    QVERIFY(row(QStringLiteral("r-docs")).value(QStringLiteral("placeOnly")).toBool());
    QVERIFY(!row(QStringLiteral("r-docs")).value(QStringLiteral("assignable")).toBool());
    QVERIFY(!row(QStringLiteral("r-mixed")).value(QStringLiteral("placeOnly")).toBool());
    QVERIFY(row(QStringLiteral("r-mixed")).value(QStringLiteral("assignable")).toBool());
    QVERIFY(!row(QStringLiteral("r-member")).value(QStringLiteral("placeOnly")).toBool());
    QVERIFY(directory->placeOnly(QStringLiteral("r-docs")));

    // The space lists content, nothing more.
    const QString catalog = matome::orgPath(org, QStringLiteral("action-catalog?space_id=") + space);
    const auto spaceCatalog = [&](const QStringList &allowed) {
        QJsonArray actions;
        for (const QString &key : {QStringLiteral("content.list"), QStringLiteral("upload.create"), manage,
                                   QStringLiteral("resource_grant.create"), QStringLiteral("add_on.space_activate")})
            actions.append(QJsonObject{{QStringLiteral("key"), key}, {QStringLiteral("allowed"), allowed.contains(key)}});
        backend.respond("GET", catalog, {{QStringLiteral("actions"), actions}});
    };
    spaceCatalog({QStringLiteral("content.list")});
    permissions->reload();
    QTRY_VERIFY(permissions->explain(QStringLiteral("upload.create"), space).value(QStringLiteral("known")).toBool());
    QVariantMap answer = permissions->explain(QStringLiteral("upload.create"), space);
    QCOMPARE(answer.value(QStringLiteral("reason")).toString(), QStringLiteral("grant"));
    QCOMPARE(answer.value(QStringLiteral("fix")).toString(), QStringLiteral("grant"));
    QVERIFY(!answer.value(QStringLiteral("canFix")).toBool());
    QVERIFY(answer.value(QStringLiteral("listed")).toBool());
    QCOMPARE(answer.value(QStringLiteral("spaceName")).toString(), QStringLiteral("Inbox"));
    const QVariantList roles = answer.value(QStringLiteral("roles")).toList();
    QCOMPARE(roles.size(), 2);
    QCOMPARE(roles.first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("r-contributor"));
    QCOMPARE(roles.last().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("r-manager"));
    // The command says the same.
    QVERIFY(!usable(session, QStringLiteral("upload")));
    QCOMPARE(command(session, QStringLiteral("upload")).value(QStringLiteral("refusal")).toMap().value(QStringLiteral("reason")).toString(),
             QStringLiteral("grant"));
    QVERIFY(!command(session, QStringLiteral("refresh")).contains(QStringLiteral("refusal")));
    // The add-on's activation there is not readable: it may be off too.
    answer = permissions->explain(manage, space);
    QCOMPARE(answer.value(QStringLiteral("reason")).toString(), QStringLiteral("grant"));
    QVERIFY(answer.value(QStringLiteral("unsure")).toBool());
    QCOMPARE(answer.value(QStringLiteral("product")).toString(), QStringLiteral("controlled_docs"));
    QCOMPARE(answer.value(QStringLiteral("roles")).toList().first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("r-docs"));
    QVERIFY(permissions->explain(QStringLiteral("content.list"), space).value(QStringLiteral("allowed")).toBool());

    // Where the person manages access and add-ons, the add-on off there says
    // so, and both fixes are theirs.
    spaceCatalog({QStringLiteral("content.list"), QStringLiteral("resource_grant.create"), QStringLiteral("add_on.space_activate")});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), spaceAddOns(false));
    permissions->reload();
    QTRY_COMPARE(permissions->explain(manage, space).value(QStringLiteral("reason")).toString(), QStringLiteral("inactive"));
    answer = permissions->explain(manage, space);
    QCOMPARE(answer.value(QStringLiteral("fix")).toString(), QStringLiteral("activate"));
    QVERIFY(answer.value(QStringLiteral("canFix")).toBool());
    QVERIFY(permissions->explain(QStringLiteral("upload.create"), space).value(QStringLiteral("canFix")).toBool());
    // Paused in the organization: resumed from its page.
    serveControlledDocs(backend, org, QStringLiteral("paused"));
    session.addOns()->refresh();
    QTRY_COMPARE(permissions->explain(manage, space).value(QStringLiteral("reason")).toString(), QStringLiteral("paused"));
    QCOMPARE(permissions->explain(manage, space).value(QStringLiteral("fix")).toString(), QStringLiteral("resume"));
    QVERIFY(permissions->explain(manage, space).value(QStringLiteral("canFix")).toBool());
    // Uninstalled: installed again from its page.
    serveControlledDocs(backend, org, QStringLiteral("uninstalled"));
    session.addOns()->refresh();
    QTRY_COMPARE(permissions->explain(manage, space).value(QStringLiteral("reason")).toString(), QStringLiteral("uninstalled"));
    QCOMPARE(permissions->explain(manage, space).value(QStringLiteral("fix")).toString(), QStringLiteral("install"));
    // Not in the plan: only a billing manager opens the plan.
    serveControlledDocs(backend, org);
    backend.respond("GET", matome::orgPath(org, QStringLiteral("entitlements")),
                    {{QStringLiteral("entitlements"), QJsonObject{{QStringLiteral("capabilities"), QJsonObject()}}}});
    session.addOns()->refresh();
    QTRY_COMPARE(permissions->explain(manage, space).value(QStringLiteral("reason")).toString(), QStringLiteral("plan"));
    QCOMPARE(permissions->explain(manage, space).value(QStringLiteral("fix")).toString(), QStringLiteral("plan"));
    QVERIFY(!permissions->explain(manage, space).value(QStringLiteral("canFix")).toBool());

    // Across the organization: the roles given there that hold it.
    answer = permissions->explain(QStringLiteral("billing.manage"), QString());
    QVERIFY(answer.value(QStringLiteral("known")).toBool());
    QCOMPARE(answer.value(QStringLiteral("reason")).toString(), QStringLiteral("grant"));
    QVERIFY(answer.value(QStringLiteral("fix")).toString().isEmpty());
    QCOMPARE(answer.value(QStringLiteral("roles")).toList().first().toMap().value(QStringLiteral("key")).toString(), QStringLiteral("billing"));
    QVERIFY(permissions->explain(QStringLiteral("add_on.read"), QString()).value(QStringLiteral("allowed")).toBool());
}

// Check access on a document counts its restricted tags: a member no grant
// on such a tag reaches can do nothing there, and the reason names it.
void TestCore::accessGrantsCountRestrictedTags()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    session.upload(QStringLiteral("secret.md"), "# Secret\n");
    QTRY_VERIFY(!core.landed(QStringLiteral("secret.md")).isEmpty());
    QTRY_VERIFY(!session.uploadBusy());
    QVERIFY(waitFor(&session));
    QString payload;
    for (int at = 0; at < session.entries()->rowCount(); ++at)
        if (entry(session, at, EntryModel::NameRole) == QLatin1String("secret.md")) payload = entry(session, at, EntryModel::PayloadRole);
    const QString document = payload.section(QLatin1Char(':'), 1, 1);
    const QString bo = core.seedMember(org, QStringLiteral("bo@example.com"), QStringLiteral("member"));
    const QString tag = core.seedTag(org, QStringLiteral("Confidential"), true);
    core.seedDocumentTag(org, space, QStringLiteral("secret.md"), tag);
    auto *directory = session.accessDirectory();
    directory->open();
    QTRY_VERIFY(!directory->busy());
    auto *grants = session.accessGrants();
    grants->open(QStringLiteral("space"), space, space, QStringLiteral("Inbox"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("user:") + bo, {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->open(QStringLiteral("document"), space, document, QStringLiteral("secret.md"));
    QTRY_VERIFY(!grants->busy());
    grants->check(bo);
    QTRY_VERIFY(!grants->busy());
    // Read from the space, but hidden by the tag.
    QVariantMap answer = grants->explain(bo);
    QVERIFY(answer.value(QStringLiteral("actions")).toStringList().isEmpty());
    const auto tagReason = [](const QVariantMap &found) {
        for (const auto &reason : found.value(QStringLiteral("reasons")).toList())
            if (reason.toMap().value(QStringLiteral("kind")) == QLatin1String("tag")) return reason.toMap();
        return QVariantMap();
    };
    QCOMPARE(tagReason(answer).value(QStringLiteral("sourceName")).toString(), QStringLiteral("Confidential"));
    QVERIFY(!tagReason(answer).value(QStringLiteral("held")).toBool());
    // Given the tag through a role Bo holds, the document reads again.
    grants->open(QStringLiteral("tag"), {}, tag, QStringLiteral("Confidential"));
    QTRY_VERIFY(!grants->busy());
    grants->setRoles(QStringLiteral("role:role-member"), {QStringLiteral("role-content_reader")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    grants->open(QStringLiteral("document"), space, document, QStringLiteral("secret.md"));
    QTRY_VERIFY(!grants->busy());
    grants->check(bo);
    QTRY_VERIFY(!grants->busy());
    answer = grants->explain(bo);
    QVERIFY(answer.value(QStringLiteral("actions")).toStringList().contains(QStringLiteral("content.download")));
    QVERIFY(tagReason(answer).value(QStringLiteral("held")).toBool());
    grants->close();
}

void TestCore::accessGrantsCoverFoldersDocumentsAndTags()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    seedDirectory(backend, org);
    const auto grant = [](const QString &id, const QString &kind, const QString &principal, const QString &role, const QString &key) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("principal_kind"), kind},
            {kind == QLatin1String("group") ? QStringLiteral("group_id") : kind == QLatin1String("role") ? QStringLiteral("role_principal_id")
                                                                         : QStringLiteral("organization_membership_id"), principal},
            {QStringLiteral("role_id"), role}, {QStringLiteral("role_key"), key}, {QStringLiteral("status"), QStringLiteral("active")}};
    };
    const auto from = [](QJsonObject row, const QString &kind, const QString &id, bool inherited) {
        row.insert(QStringLiteral("source"), QJsonObject{{QStringLiteral("kind"), kind}, {QStringLiteral("id"), id}});
        row.insert(QStringLiteral("inherited"), inherited);
        return row;
    };
    // A folder's access: what it inherits from its space and the folder
    // above it, then its own grants.
    const QString access = matome::contentPath(org, space, QStringLiteral("folders/f1/access"));
    const QString folder = matome::contentPath(org, space, QStringLiteral("folders/f1/grants"));
    backend.respond("GET", access, {{QStringLiteral("access"), QJsonArray{
        from(grant(QStringLiteral("i1"), QStringLiteral("user"), QStringLiteral("m1"), QStringLiteral("viewer-role"), QStringLiteral("content_reader")),
             QStringLiteral("space"), space, true),
        from(grant(QStringLiteral("i2"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("custom-role"), QStringLiteral("custom-1")),
             QStringLiteral("folder"), QStringLiteral("f0"), true),
        from(grant(QStringLiteral("x1"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("viewer-role"), QStringLiteral("content_reader")),
             QStringLiteral("folder"), QStringLiteral("f1"), false)}}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("folders/f0")),
                    {{QStringLiteral("folder"), QJsonObject{{QStringLiteral("id"), QStringLiteral("f0")}, {QStringLiteral("name"), QStringLiteral("Plans")}}}});
    auto *grants = session.accessGrants();
    grants->open(QStringLiteral("folder"), space, QStringLiteral("f1"), QStringLiteral("Drafts"));
    QVERIFY(grants->active());
    QCOMPARE(grants->spaceId(), space);
    QVERIFY(session.accessDirectory()->active());
    QTRY_VERIFY(!grants->busy());
    QCOMPARE(grants->holders().size(), 1);
    const auto holder = grants->holders().constFirst().toMap();
    QCOMPARE(holder.value(QStringLiteral("principal")).toString(), QStringLiteral("group:g1"));
    QCOMPARE(holder.value(QStringLiteral("principalName")).toString(), QStringLiteral("Legal"));
    QCOMPARE(holder.value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("viewer-role")});
    QCOMPARE(holder.value(QStringLiteral("roles")).toList().constFirst().toMap().value(QStringLiteral("key")).toString(),
             QStringLiteral("content_reader"));
    QCOMPARE(grants->inherited().size(), 2);
    const auto fromSpace = grants->inherited().constFirst().toMap();
    QCOMPARE(fromSpace.value(QStringLiteral("principalName")).toString(), QStringLiteral("ana@example.com"));
    QCOMPARE(fromSpace.value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("viewer-role")});
    QCOMPARE(fromSpace.value(QStringLiteral("sourceKind")).toString(), QStringLiteral("space"));
    QCOMPARE(fromSpace.value(QStringLiteral("sourceName")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(grants->inherited().at(1).toMap().value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("custom-role")});
    QTRY_COMPARE(grants->inherited().at(1).toMap().value(QStringLiteral("sourceName")).toString(), QStringLiteral("Plans"));
    QCOMPARE(callAt(backend, "GET", matome::contentPath(org, space, QStringLiteral("folders/f0")),
                    callAt(backend, "GET", matome::contentPath(org, space, QStringLiteral("folders/f0"))) + 1), -1);
    QCOMPARE(grants->principals().size(), 3);

    // A holder's checked roles replace theirs here in one request, whose
    // answer takes the place of the holder's rows.
    backend.respond("PUT", folder, {{QStringLiteral("grants"), QJsonArray{
        grant(QStringLiteral("x1"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("viewer-role"), QStringLiteral("content_reader")),
        grant(QStringLiteral("x3"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("custom-role"), QStringLiteral("custom-1"))}}});
    const auto before = backend.calls.size();
    grants->setRoles(QStringLiteral("group:g1"), {QStringLiteral("viewer-role"), QStringLiteral("custom-role")});
    QVERIFY(grants->busy());
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    QVERIFY(!grants->busy());
    const auto put = callAt(backend, "PUT", folder, before);
    QVERIFY(put >= 0);
    QCOMPARE(backend.calls.at(put).body, (QJsonObject{{QStringLiteral("group_id"), QStringLiteral("g1")},
                                                       {QStringLiteral("role_ids"), QJsonArray{QStringLiteral("viewer-role"),
                                                                                                QStringLiteral("custom-role")}}}));
    QVERIFY(!backend.calls.at(put).headers.isEmpty()
            && backend.calls.at(put).headers.constFirst().first == QByteArrayLiteral("Idempotency-Key"));
    QCOMPARE(backend.calls.size(), before + 1);
    QCOMPARE(grants->holders().size(), 1);
    QCOMPARE(grants->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList(),
             (QStringList{QStringLiteral("viewer-role"), QStringLiteral("custom-role")}));
    QCOMPARE(grants->inherited().size(), 2);
    // The roles held already in any order, an unknown role, or a role
    // principal off a tag send nothing.
    const auto settled = backend.calls.size();
    grants->setRoles(QStringLiteral("group:g1"), {QStringLiteral("custom-role"), QStringLiteral("viewer-role"), QStringLiteral("gone")});
    grants->setRoles(QStringLiteral("role:custom-role"), {QStringLiteral("viewer-role")});
    grants->setRoles(QStringLiteral("user:m2"), {});
    grants->add({QStringLiteral("group:g1")}, {QStringLiteral("viewer-role")});
    QCOMPARE(backend.calls.size(), settled);
    // Adding gives each person or group the checked roles beside theirs, one
    // request per principal that lacks one.
    const auto adding = backend.calls.size();
    backend.respond("PUT", folder, {{QStringLiteral("grants"), QJsonArray{
        grant(QStringLiteral("x4"), QStringLiteral("user"), QStringLiteral("m1"), QStringLiteral("viewer-role"), QStringLiteral("content_reader"))}}});
    grants->add({QStringLiteral("group:g1"), QStringLiteral("user:m1")}, {QStringLiteral("viewer-role")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_added"));
    QCOMPARE(backend.calls.size(), adding + 1);
    QCOMPARE(lastCall(backend, "PUT", folder).body, (QJsonObject{{QStringLiteral("organization_membership_id"), QStringLiteral("m1")},
                                                                {QStringLiteral("role_ids"), QJsonArray{QStringLiteral("viewer-role")}}}));
    QCOMPARE(grants->holders().size(), 2);
    backend.respond("PUT", folder, {{QStringLiteral("grants"), QJsonArray{
        grant(QStringLiteral("x5"), QStringLiteral("user"), QStringLiteral("m1"), QStringLiteral("viewer-role"), QStringLiteral("content_reader")),
        grant(QStringLiteral("x6"), QStringLiteral("user"), QStringLiteral("m1"), QStringLiteral("custom-role"), QStringLiteral("custom-1"))}}});
    grants->add({QStringLiteral("user:m1")}, {QStringLiteral("custom-role")});
    QTRY_VERIFY(!grants->busy());
    QCOMPARE(lastCall(backend, "PUT", folder).body.value(QStringLiteral("role_ids")).toArray(),
             (QJsonArray{QStringLiteral("viewer-role"), QStringLiteral("custom-role")}));
    // A refusal changes nothing and says why.
    backend.respond("PUT", folder, {}, 403, QStringLiteral("forbidden"));
    grants->setRoles(QStringLiteral("group:g1"), {QStringLiteral("viewer-role")});
    QTRY_COMPARE(grants->errorCode(), QStringLiteral("forbidden"));
    QVERIFY(!grants->busy());
    QVERIFY(grants->notice().isEmpty());
    QCOMPARE(grants->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList().size(), 2);
    // No roles at all removes the holder's access here.
    backend.respond("PUT", folder, {{QStringLiteral("grants"), QJsonArray()}});
    grants->setRoles(QStringLiteral("group:g1"), {});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_removed"));
    QCOMPARE(lastCall(backend, "PUT", folder).body.value(QStringLiteral("role_ids")).toArray(), QJsonArray());
    QCOMPARE(grants->holders().size(), 1);
    QVERIFY(grants->errorCode().isEmpty());

    const QString document = matome::contentPath(org, space, QStringLiteral("documents/42/access"));
    backend.respond("GET", document, {{QStringLiteral("access"), QJsonArray()}});
    grants->open(QStringLiteral("document"), space, QStringLiteral("42"), QStringLiteral("Contract"));
    QTRY_VERIFY(!grants->busy());
    QCOMPARE(grants->name(), QStringLiteral("Contract"));
    QVERIFY(grants->notice().isEmpty());
    QVERIFY(grants->inherited().isEmpty());
    QVERIFY(!lastCall(backend, "GET", document).method.isEmpty());

    // A tag lists its grants, those of archived roles too: they still grant
    // the tag and stay untouched.
    const QString tag = matome::orgPath(org, QStringLiteral("tags/t1/grants"));
    backend.respond("GET", tag, {{QStringLiteral("grants"), QJsonArray{
        grant(QStringLiteral("y1"), QStringLiteral("role"), QStringLiteral("custom-role"), QStringLiteral("viewer-role"), QStringLiteral("content_reader")),
        grant(QStringLiteral("y2"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("archived-role"),
              QStringLiteral("addon.controlled_docs.reviewer"))}}});
    grants->open(QStringLiteral("tag"), {}, QStringLiteral("t1"), QStringLiteral("Secret"));
    QTRY_VERIFY(!grants->busy());
    QVERIFY(grants->spaceId().isEmpty());
    QCOMPARE(grants->principals().size(), 6);
    const auto everyone = grants->holders().constFirst().toMap();
    QCOMPARE(everyone.value(QStringLiteral("principal")).toString(), QStringLiteral("role:custom-role"));
    QCOMPARE(everyone.value(QStringLiteral("principalName")).toString(), QStringLiteral("Reviewers"));
    QCOMPARE(everyone.value(QStringLiteral("principalKey")).toString(), QStringLiteral("custom-1"));
    const auto archived = grants->holders().at(1).toMap();
    QVERIFY(archived.value(QStringLiteral("roles")).toList().isEmpty());
    QCOMPARE(archived.value(QStringLiteral("archived")).toStringList(), QStringList{QStringLiteral("addon.controlled_docs.reviewer")});
    const auto untouched = backend.calls.size();
    grants->setRoles(QStringLiteral("group:g1"), {});
    QCOMPARE(backend.calls.size(), untouched);
    backend.respond("PUT", tag, {{QStringLiteral("grants"), QJsonArray{
        grant(QStringLiteral("y3"), QStringLiteral("role"), QStringLiteral("custom-role"), QStringLiteral("custom-role"), QStringLiteral("custom-1"))}}});
    grants->setRoles(QStringLiteral("role:custom-role"), {QStringLiteral("custom-role")});
    QTRY_COMPARE(grants->notice(), QStringLiteral("access_saved"));
    QCOMPARE(lastCall(backend, "PUT", tag).body, (QJsonObject{{QStringLiteral("role_principal_id"), QStringLiteral("custom-role")},
                                                             {QStringLiteral("role_ids"), QJsonArray{QStringLiteral("custom-role")}}}));
    QCOMPARE(grants->holders().constFirst().toMap().value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("custom-role")});

    grants->open(QStringLiteral("share"), space, QStringLiteral("x"), QStringLiteral("x"));
    QVERIFY(grants->active());
    grants->close();
    grants->open(QStringLiteral("folder"), {}, QStringLiteral("f1"), QStringLiteral("Plans"));
    QVERIFY(!grants->active());
}

// A person's or group's page reads the access that reaches them and their
// organization roles, and reads them again when the directory changes.
// A folder that stops inheriting says so in its summary, lists from above
// only the grants that manage access, and inherits again on request. Check
// access explains what a member may do there from the rows, their groups,
// their organization roles, and an open place.
void TestCore::accessGrantsStopInheritingAndExplain()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    seedDirectory(backend, org);
    const auto role = [](const QString &id, const QString &key, const QJsonArray &actions) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("key"), key}, {QStringLiteral("name"), key},
                           {QStringLiteral("origin"), QStringLiteral("system")}, {QStringLiteral("actions"), actions}};
    };
    const QJsonArray managing{QStringLiteral("resource_grant.read"), QStringLiteral("resource_grant.create"),
                              QStringLiteral("resource_grant.revoke"), QStringLiteral("access.configure")};
    backend.respond("GET", matome::orgPath(org, QStringLiteral("roles")), {{QStringLiteral("roles"), QJsonArray{
        role(QStringLiteral("operator-role"), QStringLiteral("space_operator"), QJsonArray(managing) << QStringLiteral("space.update_metadata")),
        role(QStringLiteral("owner-role"), QStringLiteral("owner"), {QStringLiteral("role.read")}),
        role(QStringLiteral("manager-role"), QStringLiteral("access_manager"), managing),
        role(QStringLiteral("viewer-role"), QStringLiteral("content_reader"), {QStringLiteral("content.download")})}}});
    const auto row = [](const QString &id, const QString &kind, const QString &principal, const QString &roleId,
                        const QJsonObject &source, bool inherited, const QString &scope) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("principal_kind"), kind},
            {kind == QLatin1String("group") ? QStringLiteral("group_id") : QStringLiteral("organization_membership_id"), principal},
            {QStringLiteral("role_id"), roleId}, {QStringLiteral("source"), source}, {QStringLiteral("inherited"), inherited},
            {QStringLiteral("scope"), scope}};
    };
    const QJsonObject fromSpace{{QStringLiteral("kind"), QStringLiteral("space")}, {QStringLiteral("id"), space}};
    const QJsonObject here{{QStringLiteral("kind"), QStringLiteral("folder")}, {QStringLiteral("id"), QStringLiteral("f1")}};
    const QJsonArray rows{row(QStringLiteral("i1"), QStringLiteral("user"), QStringLiteral("m1"), QStringLiteral("manager-role"), fromSpace, true,
                              QStringLiteral("manage")),
                          row(QStringLiteral("x1"), QStringLiteral("group"), QStringLiteral("g1"), QStringLiteral("viewer-role"), here, false,
                              QStringLiteral("full"))};
    const QString access = matome::contentPath(org, space, QStringLiteral("folders/f1/access"));
    const auto summary = [&](const QJsonValue &inheritance, const QJsonValue &open) {
        return QJsonObject{{QStringLiteral("access"), rows},
                           {QStringLiteral("summary"), QJsonObject{{QStringLiteral("visibility"), QStringLiteral("private")},
                                                                   {QStringLiteral("inheritance"), inheritance},
                                                                   {QStringLiteral("break"), inheritance.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue(here)},
                                                                   {QStringLiteral("open_to_members"), !open.isNull()},
                                                                   {QStringLiteral("open_source"), open}}}};
    };
    backend.respond("GET", access, summary(QStringLiteral("restricted"), QJsonValue::Null));
    auto *grants = session.accessGrants();
    grants->open(QStringLiteral("folder"), space, QStringLiteral("f1"), QStringLiteral("Drafts"));
    QTRY_VERIFY(!grants->busy());
    QTRY_VERIFY(!session.accessDirectory()->busy());
    // Grants offer the built-in space roles atomic first, then broad.
    QStringList offered;
    for (const auto &role : session.accessDirectory()->grantableRoles()) offered.append(role.toMap().value(QStringLiteral("key")).toString());
    QCOMPARE(offered, (QStringList{QStringLiteral("content_reader"), QStringLiteral("access_manager"), QStringLiteral("space_operator")}));
    const QVariantMap reach = grants->summary();
    QCOMPARE(reach.value(QStringLiteral("inheritance")).toString(), QStringLiteral("restricted"));
    QCOMPARE(reach.value(QStringLiteral("breakKind")).toString(), QStringLiteral("folder"));
    QCOMPARE(reach.value(QStringLiteral("breakName")).toString(), QStringLiteral("Drafts"));
    QVERIFY(!reach.value(QStringLiteral("openToMembers")).toBool());
    QCOMPARE(grants->inherited().constFirst().toMap().value(QStringLiteral("scope")).toString(), QStringLiteral("manage"));

    // Bo reads through Legal; Ana manages access from the space and as owner.
    const QVariantMap bo = grants->explain(QStringLiteral("m2"));
    QCOMPARE(bo.value(QStringLiteral("actions")).toStringList(), QStringList{QStringLiteral("content.download")});
    QCOMPARE(bo.value(QStringLiteral("reasons")).toList().size(), 1);
    const auto through = bo.value(QStringLiteral("reasons")).toList().constFirst().toMap();
    QCOMPARE(through.value(QStringLiteral("kind")).toString(), QStringLiteral("grant"));
    QCOMPARE(through.value(QStringLiteral("via")).toString(), QStringLiteral("Legal"));
    QCOMPARE(through.value(QStringLiteral("sourceName")).toString(), QStringLiteral("Drafts"));
    const QVariantMap ana = grants->explain(QStringLiteral("m1"));
    QStringList held = ana.value(QStringLiteral("actions")).toStringList();
    held.sort();
    QCOMPARE(held, (QStringList{QStringLiteral("access.configure"), QStringLiteral("resource_grant.create"),
                                QStringLiteral("resource_grant.read"), QStringLiteral("resource_grant.revoke")}));
    const auto anaWhy = ana.value(QStringLiteral("reasons")).toList();
    QCOMPARE(anaWhy.size(), 2);
    QCOMPARE(anaWhy.at(0).toMap().value(QStringLiteral("scope")).toString(), QStringLiteral("manage"));
    QCOMPARE(anaWhy.at(0).toMap().value(QStringLiteral("sourceName")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(anaWhy.at(1).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("organization"));
    QVERIFY(anaWhy.at(1).toMap().value(QStringLiteral("via")).toString().isEmpty());
    QVERIFY(grants->explain(QStringLiteral("nobody")).value(QStringLiteral("actions")).toStringList().isEmpty());

    // Legal holds Owner across the organization: once checked, Bo manages
    // access here through it.
    backend.respond("GET", matome::orgPath(org, QStringLiteral("principal-roles?group_id=g1")), {{QStringLiteral("principal_roles"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), QStringLiteral("pr1")}, {QStringLiteral("role_id"), QStringLiteral("owner-role")},
                    {QStringLiteral("group_id"), QStringLiteral("g1")}}}}});
    grants->check(QStringLiteral("m2"));
    QTRY_VERIFY(!grants->busy());
    const QVariantMap boChecked = grants->explain(QStringLiteral("m2"));
    QVERIFY(boChecked.value(QStringLiteral("actions")).toStringList().contains(QStringLiteral("access.configure")));
    const auto boWhy = boChecked.value(QStringLiteral("reasons")).toList();
    QCOMPARE(boWhy.constLast().toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("organization"));
    QCOMPARE(boWhy.constLast().toMap().value(QStringLiteral("roleKey")).toString(), QStringLiteral("owner"));
    QCOMPARE(boWhy.constLast().toMap().value(QStringLiteral("via")).toString(), QStringLiteral("Legal"));
    // A group read once is not read again.
    const int checked = backend.calls.size();
    grants->check(QStringLiteral("m2"));
    QCOMPARE(backend.calls.size(), checked);

    // Switched from restricted to open, every member except guests reads it too.
    backend.respond("PUT", access, {{QStringLiteral("folder"), QJsonObject{{QStringLiteral("id"), QStringLiteral("f1")}}}});
    backend.respond("GET", access, summary(QStringLiteral("open"), here));
    const int asked = backend.calls.size();
    grants->setInheritance(QStringLiteral("sideways"));
    QCOMPARE(backend.calls.size(), asked);
    grants->setInheritance(QStringLiteral("open"));
    QVERIFY(grants->busy());
    QTRY_COMPARE(grants->notice(), QStringLiteral("inheritance_opened"));
    QTRY_VERIFY(!grants->busy());
    const auto put = lastCall(backend, "PUT", access);
    QCOMPARE(put.body, (QJsonObject{{QStringLiteral("inheritance"), QStringLiteral("open")}}));
    QVERIFY(!put.headers.isEmpty());
    QVERIFY(grants->summary().value(QStringLiteral("openToMembers")).toBool());
    QCOMPARE(grants->summary().value(QStringLiteral("openName")).toString(), QStringLiteral("Drafts"));
    const auto opened = grants->explain(QStringLiteral("m2")).value(QStringLiteral("reasons")).toList();
    QCOMPARE(opened.size(), 2);
    QCOMPARE(opened.at(1).toMap().value(QStringLiteral("kind")).toString(), QStringLiteral("open"));

    // Restoring inheritance clears the break; a refusal says why.
    backend.respond("GET", access, summary(QJsonValue::Null, QJsonValue::Null));
    grants->setInheritance(QStringLiteral("inherit"));
    QTRY_COMPARE(grants->notice(), QStringLiteral("inheritance_restored"));
    QTRY_VERIFY(!grants->busy());
    QVERIFY(grants->summary().value(QStringLiteral("inheritance")).toString().isEmpty());
    backend.respond("PUT", access, {}, 403, QStringLiteral("forbidden"));
    grants->setInheritance(QStringLiteral("restricted"));
    QTRY_COMPARE(grants->errorCode(), QStringLiteral("forbidden"));
    QVERIFY(!grants->busy());

    // A space has no inheritance to stop.
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("access")), summary(QJsonValue::Null, QJsonValue::Null));
    grants->open(QStringLiteral("space"), space, space, QStringLiteral("Inbox"));
    QTRY_VERIFY(!grants->busy());
    const int spaceCalls = backend.calls.size();
    grants->setInheritance(QStringLiteral("restricted"));
    QCOMPARE(backend.calls.size(), spaceCalls);
    // On the space, an owner holds what a space operator does.
    QVERIFY(grants->explain(QStringLiteral("m1")).value(QStringLiteral("actions")).toStringList().contains(QStringLiteral("space.update_metadata")));
    grants->close();
    QVERIFY(grants->summary().isEmpty());
}

void TestCore::principalAccessListsPlacesAndRoles()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    seedDirectory(backend, org);
    session.accessDirectory()->open();
    QTRY_VERIFY(!session.accessDirectory()->busy());
    const auto reached = [&](const QString &id, const QString &kind, const QString &resourceId, const QJsonValue &spaceId,
                             const QString &via, const QString &viaId, const QString &role) {
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("principal_kind"), via},
                           {QStringLiteral("role_id"), role}, {QStringLiteral("status"), QStringLiteral("active")},
                           {QStringLiteral("resource"), QJsonObject{{QStringLiteral("kind"), kind}, {QStringLiteral("id"), resourceId},
                                                                    {QStringLiteral("space_id"), spaceId}}},
                           {QStringLiteral("via"), QJsonObject{{QStringLiteral("kind"), via}, {QStringLiteral("id"), viaId}}}};
    };
    const QString members = matome::orgPath(org, QStringLiteral("members/m2/access"));
    const QString roles = matome::orgPath(org, QStringLiteral("principal-roles?organization_membership_id=m2"));
    backend.respond("GET", members, {{QStringLiteral("access"), QJsonArray{
        reached(QStringLiteral("a1"), QStringLiteral("space"), space, space, QStringLiteral("user"), QStringLiteral("m2"), QStringLiteral("viewer-role")),
        reached(QStringLiteral("a2"), QStringLiteral("document"), QStringLiteral("42"), space, QStringLiteral("group"), QStringLiteral("g1"),
                QStringLiteral("custom-role")),
        reached(QStringLiteral("a3"), QStringLiteral("tag"), QStringLiteral("t1"), QJsonValue(), QStringLiteral("role"), QStringLiteral("custom-role"),
                QStringLiteral("viewer-role"))}},
        {QStringLiteral("open"), QJsonArray{QJsonObject{{QStringLiteral("kind"), QStringLiteral("space")}, {QStringLiteral("id"), space},
                                                         {QStringLiteral("space_id"), space}}}}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents/42")),
                    {{QStringLiteral("document"), QJsonObject{{QStringLiteral("id"), 42}, {QStringLiteral("title"), QStringLiteral("Contract")}}}});
    backend.respond("GET", roles, {{QStringLiteral("principal_roles"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), QStringLiteral("pr0")}, {QStringLiteral("role_id"), QStringLiteral("member-role")},
                    {QStringLiteral("role"), QJsonObject{{QStringLiteral("key"), QStringLiteral("member")}, {QStringLiteral("name"), QStringLiteral("Member")},
                                                         {QStringLiteral("origin"), QStringLiteral("system")}}}},
        QJsonObject{{QStringLiteral("id"), QStringLiteral("pr1")}, {QStringLiteral("role_id"), QStringLiteral("custom-role")},
                    {QStringLiteral("role"), QJsonObject{{QStringLiteral("key"), QStringLiteral("custom-1")}, {QStringLiteral("name"), QStringLiteral("Reviewers")},
                                                         {QStringLiteral("origin"), QStringLiteral("organization")},
                                                         {QStringLiteral("actions"), QJsonArray{QStringLiteral("role.read")}}}}}}}});
    auto *held = session.principalAccess();
    held->open(QStringLiteral("space:x"));
    QVERIFY(held->principal().isEmpty());
    held->open(QStringLiteral("user:m2"));
    QCOMPARE(held->principal(), QStringLiteral("user:m2"));
    QVERIFY(held->busy());
    QTRY_VERIFY(!held->busy());
    QVERIFY(held->errorCode().isEmpty());
    // One row per organization role, per grant, and per place read
    // through the organization roles.
    const auto rows = held->rows();
    QCOMPARE(rows.size(), 6);
    const auto member = rows.at(0).toMap();
    QCOMPARE(member.value(QStringLiteral("key")).toString(), QStringLiteral("assignment:pr0"));
    QCOMPARE(member.value(QStringLiteral("placeKind")).toString(), QStringLiteral("organization"));
    QCOMPARE(member.value(QStringLiteral("roleKey")).toString(), QStringLiteral("member"));
    QVERIFY(member.value(QStringLiteral("direct")).toBool());
    const auto own = rows.at(2).toMap();
    QCOMPARE(own.value(QStringLiteral("key")).toString(), QStringLiteral("grant:a1"));
    QCOMPARE(own.value(QStringLiteral("placeKind")).toString(), QStringLiteral("space"));
    QCOMPARE(own.value(QStringLiteral("name")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(own.value(QStringLiteral("roleKey")).toString(), QStringLiteral("content_reader"));
    QVERIFY(own.value(QStringLiteral("direct")).toBool());
    const auto viaGroup = rows.at(3).toMap();
    QCOMPARE(viaGroup.value(QStringLiteral("spaceName")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(viaGroup.value(QStringLiteral("viaName")).toString(), QStringLiteral("Legal"));
    QVERIFY(!viaGroup.value(QStringLiteral("direct")).toBool());
    QTRY_COMPARE(held->rows().at(3).toMap().value(QStringLiteral("name")).toString(), QStringLiteral("Contract"));
    const auto viaRole = rows.at(4).toMap();
    QCOMPARE(viaRole.value(QStringLiteral("name")).toString(), QStringLiteral("Secret"));
    QCOMPARE(viaRole.value(QStringLiteral("viaKind")).toString(), QStringLiteral("role"));
    QCOMPARE(viaRole.value(QStringLiteral("viaKey")).toString(), QStringLiteral("custom-1"));
    QVERIFY(viaRole.value(QStringLiteral("spaceId")).toString().isEmpty());
    const auto open = rows.at(5).toMap();
    QCOMPARE(open.value(QStringLiteral("kind")).toString(), QStringLiteral("open"));
    QCOMPARE(open.value(QStringLiteral("name")).toString(), QStringLiteral("Inbox"));
    QVERIFY(!open.value(QStringLiteral("direct")).toBool());
    QCOMPARE(held->roles().size(), 2);
    QCOMPARE(held->roles().constFirst().toMap().value(QStringLiteral("origin")).toString(), QStringLiteral("system"));
    const auto custom = held->roles().at(1).toMap();
    QCOMPARE(custom.value(QStringLiteral("id")).toString(), QStringLiteral("pr1"));
    QCOMPARE(custom.value(QStringLiteral("roleName")).toString(), QStringLiteral("Reviewers"));
    QCOMPARE(custom.value(QStringLiteral("actions")).toStringList(), QStringList{QStringLiteral("role.read")});
    // Built-in roles are set like the others.
    QCOMPARE(held->roleIds(), (QStringList{QStringLiteral("member-role"), QStringLiteral("custom-role")}));

    // Setting the roles gives the missing ones, then takes back the
    // unchecked ones by their assignment, then reads both lists again.
    const QString assign = matome::orgPath(org, QStringLiteral("principal-roles"));
    backend.respond("DELETE", assign + QStringLiteral("/pr1"), {});
    backend.respond("POST", assign, {{QStringLiteral("principal_role"), QJsonObject{{QStringLiteral("id"), QStringLiteral("pr2")}}}}, 201);
    auto reading = backend.calls.size();
    held->setRoles({QStringLiteral("member-role"), QStringLiteral("viewer-role")});
    QVERIFY(held->busy());
    QTRY_COMPARE(held->notice(), QStringLiteral("roles_saved"));
    QVERIFY(callAt(backend, "DELETE", assign + QStringLiteral("/pr1"), reading) > callAt(backend, "POST", assign, reading));
    QCOMPARE(lastCall(backend, "POST", assign).body, (QJsonObject{{QStringLiteral("organization_membership_id"), QStringLiteral("m2")},
                                                                 {QStringLiteral("role_id"), QStringLiteral("viewer-role")}}));
    QCOMPARE(callAt(backend, "DELETE", matome::orgPath(org, QStringLiteral("principal-roles/pr0")), reading), -1);
    QTRY_VERIFY(callAt(backend, "GET", roles, reading) >= 0);
    QTRY_VERIFY(callAt(backend, "GET", members, reading) >= 0);
    QTRY_VERIFY(!held->busy());
    // What is held already, or an unknown role, sends nothing.
    reading = backend.calls.size();
    held->setRoles({QStringLiteral("member-role"), QStringLiteral("custom-role"), QStringLiteral("gone")});
    QCOMPARE(backend.calls.size(), reading);
    // A refusal says why and names no notice.
    backend.respond("DELETE", assign + QStringLiteral("/pr1"), {}, 403, QStringLiteral("forbidden"));
    held->setRoles({QStringLiteral("member-role")});
    QTRY_COMPARE(held->errorCode(), QStringLiteral("forbidden"));
    QTRY_VERIFY(!held->busy());
    QVERIFY(held->notice().isEmpty());
    QCOMPARE(held->errorCode(), QStringLiteral("forbidden"));

    // Remove takes back what was given to them, each by its own route;
    // what comes through a group or the organization roles stays.
    backend.respond("DELETE", assign + QStringLiteral("/pr1"), {});
    const QString spaceGrant = matome::contentPath(org, space, QStringLiteral("grants/a1"));
    backend.respond("DELETE", spaceGrant, {});
    reading = backend.calls.size();
    held->remove({QStringLiteral("grant:a1"), QStringLiteral("assignment:pr1"), QStringLiteral("grant:a2"),
                  QStringLiteral("open:space:") + space});
    QTRY_COMPARE(held->notice(), QStringLiteral("access_removed"));
    QVERIFY(callAt(backend, "DELETE", spaceGrant, reading) >= 0);
    QVERIFY(callAt(backend, "DELETE", assign + QStringLiteral("/pr1"), reading) >= 0);
    QCOMPARE(callAt(backend, "DELETE", matome::contentPath(org, space, QStringLiteral("documents/42/grants/a2")), reading), -1);
    QTRY_VERIFY(!held->busy());
    // Grant access gives the roles not held there yet, one request each.
    const QString tagGrants = matome::orgPath(org, QStringLiteral("tags/t1/grants"));
    backend.respond("POST", tagGrants, {{QStringLiteral("grant"), QJsonObject{{QStringLiteral("id"), QStringLiteral("a4")}}}}, 201);
    reading = backend.calls.size();
    held->grant(QStringLiteral("tag"), {}, QStringLiteral("t1"), {QStringLiteral("viewer-role")});
    QTRY_COMPARE(held->notice(), QStringLiteral("access_added"));
    QCOMPARE(lastCall(backend, "POST", tagGrants).body, (QJsonObject{{QStringLiteral("organization_membership_id"), QStringLiteral("m2")},
                                                                    {QStringLiteral("role_id"), QStringLiteral("viewer-role")}}));
    QTRY_VERIFY(!held->busy());

    // A group reads its own access and roles; a principal gone says so.
    backend.respond("GET", matome::orgPath(org, QStringLiteral("groups/g1/access")), {}, 404, QStringLiteral("not_found"));
    backend.respond("GET", matome::orgPath(org, QStringLiteral("principal-roles?group_id=g1")), {{QStringLiteral("principal_roles"), QJsonArray()}});
    held->open(QStringLiteral("group:g1"));
    QVERIFY(held->rows().isEmpty());
    QTRY_VERIFY(!held->busy());
    QCOMPARE(held->errorCode(), QStringLiteral("not_found"));
    QVERIFY(held->roles().isEmpty());
    held->close();
    QVERIFY(held->principal().isEmpty());
}

// A role's page lists who holds it: its assignments and its grants on the
// places they reach; Add people gives it to those not holding it yet.
void TestCore::roleHoldersListAndAddPeople()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    seedDirectory(backend, org);
    session.accessDirectory()->open();
    QTRY_VERIFY(!session.accessDirectory()->busy());
    const QString holders = matome::orgPath(org, QStringLiteral("roles/custom-role/holders"));
    backend.respond("GET", holders, {{QStringLiteral("holders"), QJsonArray{
        QJsonObject{{QStringLiteral("kind"), QStringLiteral("assignment")}, {QStringLiteral("id"), QStringLiteral("pr1")},
                    {QStringLiteral("principal"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("group")}, {QStringLiteral("id"), QStringLiteral("g1")}}}},
        QJsonObject{{QStringLiteral("kind"), QStringLiteral("grant")}, {QStringLiteral("id"), QStringLiteral("a1")},
                    {QStringLiteral("principal"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("user")}, {QStringLiteral("id"), QStringLiteral("m2")}}},
                    {QStringLiteral("resource"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("space")}, {QStringLiteral("id"), space},
                                                             {QStringLiteral("space_id"), space}}}},
        QJsonObject{{QStringLiteral("kind"), QStringLiteral("grant")}, {QStringLiteral("id"), QStringLiteral("a2")},
                    {QStringLiteral("principal"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("role")}, {QStringLiteral("id"), QStringLiteral("viewer-role")}}},
                    {QStringLiteral("resource"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("tag")}, {QStringLiteral("id"), QStringLiteral("t1")},
                                                             {QStringLiteral("space_id"), QJsonValue()}}}}}}});
    auto *role = session.roleHolders();
    role->open(QString());
    QVERIFY(role->roleId().isEmpty());
    role->open(QStringLiteral("custom-role"));
    QVERIFY(role->busy());
    QTRY_VERIFY(!role->busy());
    QVERIFY(role->errorCode().isEmpty());
    const auto rows = role->holders();
    QCOMPARE(rows.size(), 3);
    const auto group = rows.at(0).toMap();
    QCOMPARE(group.value(QStringLiteral("kind")).toString(), QStringLiteral("assignment"));
    QCOMPARE(group.value(QStringLiteral("principal")).toString(), QStringLiteral("group:g1"));
    QCOMPARE(group.value(QStringLiteral("principalName")).toString(), QStringLiteral("Legal"));
    const auto onSpace = rows.at(1).toMap();
    QCOMPARE(onSpace.value(QStringLiteral("principalName")).toString(), QStringLiteral("bo@example.com"));
    QCOMPARE(onSpace.value(QStringLiteral("resourceKind")).toString(), QStringLiteral("space"));
    QCOMPARE(onSpace.value(QStringLiteral("name")).toString(), QStringLiteral("Inbox"));
    const auto onTag = rows.at(2).toMap();
    QCOMPARE(onTag.value(QStringLiteral("principalKind")).toString(), QStringLiteral("role"));
    QCOMPARE(onTag.value(QStringLiteral("principalKey")).toString(), QStringLiteral("content_reader"));
    QCOMPARE(onTag.value(QStringLiteral("name")).toString(), QStringLiteral("Secret"));
    QVERIFY(onTag.value(QStringLiteral("spaceId")).toString().isEmpty());
    QCOMPARE(role->assigned(), QStringList{QStringLiteral("group:g1")});

    // Only those not holding it are given it, each in its own assignment.
    const QString assign = matome::orgPath(org, QStringLiteral("principal-roles"));
    backend.respond("POST", assign, {{QStringLiteral("principal_role"), QJsonObject{{QStringLiteral("id"), QStringLiteral("pr2")}}}}, 201);
    QSignalSpy given(role, &matome::RoleHolders::rolesChanged);
    auto sent = backend.calls.size();
    role->add({QStringLiteral("group:g1"), QStringLiteral("user:m1"), QStringLiteral("user:gone"), QStringLiteral("role:viewer-role")});
    QVERIFY(role->busy());
    QTRY_COMPARE(role->notice(), QStringLiteral("holders_added"));
    QCOMPARE(lastCall(backend, "POST", assign).body, (QJsonObject{{QStringLiteral("organization_membership_id"), QStringLiteral("m1")},
                                                                 {QStringLiteral("role_id"), QStringLiteral("custom-role")}}));
    QCOMPARE(callAt(backend, "POST", assign, callAt(backend, "POST", assign, sent) + 1), -1);
    QTRY_VERIFY(callAt(backend, "GET", holders, sent) >= 0);
    QCOMPARE(given.size(), 1);
    QTRY_VERIFY(!role->busy());
    // Nothing new sends nothing; a refusal says why and names no notice.
    sent = backend.calls.size();
    role->add({QStringLiteral("group:g1")});
    QCOMPARE(backend.calls.size(), sent);
    backend.respond("POST", assign, {}, 409, QStringLiteral("last_owner"));
    role->add({QStringLiteral("user:m2")});
    QTRY_COMPARE(role->errorCode(), QStringLiteral("last_owner"));
    QTRY_VERIFY(!role->busy());
    QVERIFY(role->notice().isEmpty());
    QCOMPARE(role->errorCode(), QStringLiteral("last_owner"));
    QCOMPARE(given.size(), 1);
    QCOMPARE(group.value(QStringLiteral("key")).toString(), QStringLiteral("assignment:pr1"));
    QCOMPARE(onSpace.value(QStringLiteral("key")).toString(), QStringLiteral("grant:a1"));
    // In a space, it is granted to those not holding it there yet.
    const QString spaceGrants = matome::contentPath(org, space, QStringLiteral("grants"));
    backend.respond("POST", spaceGrants, {{QStringLiteral("grant"), QJsonObject{{QStringLiteral("id"), QStringLiteral("a3")}}}}, 201);
    sent = backend.calls.size();
    role->grant({QStringLiteral("user:m2"), QStringLiteral("group:g1")}, space);
    QTRY_COMPARE(role->notice(), QStringLiteral("holders_added"));
    QCOMPARE(lastCall(backend, "POST", spaceGrants).body, (QJsonObject{{QStringLiteral("group_id"), QStringLiteral("g1")},
                                                                      {QStringLiteral("role_id"), QStringLiteral("custom-role")}}));
    QCOMPARE(callAt(backend, "POST", spaceGrants, callAt(backend, "POST", spaceGrants, sent) + 1), -1);
    QTRY_VERIFY(!role->busy());
    QCOMPARE(given.size(), 2);
    // Remove takes back an assignment and the grants on their places.
    backend.respond("DELETE", assign + QStringLiteral("/pr1"), {});
    const QString tagGrant = matome::orgPath(org, QStringLiteral("tags/t1/grants/a2"));
    backend.respond("DELETE", tagGrant, {});
    sent = backend.calls.size();
    role->remove({QStringLiteral("assignment:pr1"), QStringLiteral("grant:a2")});
    QTRY_COMPARE(role->notice(), QStringLiteral("holders_removed"));
    QVERIFY(callAt(backend, "DELETE", assign + QStringLiteral("/pr1"), sent) >= 0);
    QVERIFY(callAt(backend, "DELETE", tagGrant, sent) >= 0);
    QCOMPARE(callAt(backend, "DELETE", matome::contentPath(org, space, QStringLiteral("grants/a1")), sent), -1);
    QTRY_VERIFY(!role->busy());
    QCOMPARE(given.size(), 3);
    // A role gone says so; closing forgets it.
    backend.respond("GET", matome::orgPath(org, QStringLiteral("roles/gone/holders")), {}, 404, QStringLiteral("not_found"));
    role->open(QStringLiteral("gone"));
    QTRY_VERIFY(!role->busy());
    QCOMPARE(role->errorCode(), QStringLiteral("not_found"));
    QVERIFY(role->holders().isEmpty());
    role->close();
    QVERIFY(role->roleId().isEmpty());
}

// Manage with reviews stays usable on a Markdown document of an
// organization where the add-on is installed: it asks Core, which decides,
// and its refusal is said as Core gave it.
void TestCore::controlledDocsSayCoreRefusals()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/41"));
    const QString manage = doc + QStringLiteral("/controlled-docs");
    const QByteArray current("# Current\n");
    serveControlledDocs(backend, org);
    QVERIFY(followCatalog(session));
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    serveDocument(backend, doc, {{QStringLiteral("id"), 41}, {QStringLiteral("title"), QStringLiteral("procedure.md")},
                                 {QStringLiteral("revision"), 3}},
                  {{markdownVersion(QStringLiteral("base"), 1, true, current), current}});
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray()}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), {}, 403, QStringLiteral("forbidden"));
    auto *control = session.controlledDocs();
    QSignalSpy requested(control, &matome::ControlledDocs::requested);

    // Not active in the space: Core refuses, and nothing else is asked.
    backend.queue("PUT", manage, refusal(409, QStringLiteral("controlled_docs_unavailable")));
    session.openEntry(QStringLiteral("document"), QStringLiteral("41"));
    QTRY_VERIFY(control->active());
    QTRY_VERIFY(!control->busy());
    QVERIFY(usable(session, QStringLiteral("manage-document")));
    session.runCommand(QStringLiteral("manage-document"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->errorCode(), QStringLiteral("controlled_docs_unavailable"));
    QCOMPARE(requested.size(), 0);
    QVERIFY(lastCall(backend, "PUT", manage).headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("3"))));

    // Without the managing action there, Core's refusal is said as well.
    backend.queue("PUT", manage, refusal(403, QStringLiteral("forbidden")));
    session.runCommand(QStringLiteral("manage-document"));
    QTRY_VERIFY(!control->busy());
    QCOMPARE(control->errorCode(), QStringLiteral("forbidden"));

    // Active there and held, the document is managed with no prompt.
    backend.respond("PUT", manage, {});
    session.runCommand(QStringLiteral("manage-document"));
    QTRY_VERIFY(!control->busy());
    QVERIFY(control->errorCode().isEmpty());
    QCOMPARE(control->notice(), QStringLiteral("control_enabled"));
    QCOMPARE(requested.size(), 0);
}

// The explorer's menu manages the focused Markdown document: it opens, and
// the verb runs once the document has loaded.
void TestCore::controlledDocsManageFromTheExplorer()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    session.upload(QStringLiteral("plan.md"), "# Plan\n");
    QTRY_VERIFY(!core.landed(QStringLiteral("plan.md")).isEmpty());
    QTRY_VERIFY(!session.uploadBusy());
    QVERIFY(waitFor(&session));
    QString payload;
    for (int row = 0; row < session.entries()->rowCount(); ++row)
        if (entry(session, row, EntryModel::NameRole) == QLatin1String("plan.md"))
            payload = entry(session, row, EntryModel::PayloadRole);
    QVERIFY(!payload.isEmpty());
    const QString id = payload.section(QLatin1Char(':'), 1, 1);
    const QString doc = matome::contentPath(org, space, QStringLiteral("documents/") + id);
    session.setFocusPayload(payload);
    // Without the add-on, the menu offers nothing of it.
    QVERIFY(!usable(session, QStringLiteral("manage-document")));
    serveControlledDocs(backend, org);
    QVERIFY(followCatalog(session));
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    QVERIFY(usable(session, QStringLiteral("manage-document")));
    QVERIFY(!usable(session, QStringLiteral("unmanage-document")));
    serveDocument(backend, doc, {{QStringLiteral("id"), id}, {QStringLiteral("title"), QStringLiteral("plan.md")},
                                 {QStringLiteral("revision"), 1}},
                  {{markdownVersion(QStringLiteral("v1"), 1, true, "# Plan\n"), "# Plan\n"}});
    backend.respond("GET", doc + QStringLiteral("/reviews"), {{QStringLiteral("reviews"), QJsonArray()}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("add-ons")), spaceAddOns(true));
    backend.respond("PUT", doc + QStringLiteral("/controlled-docs"), {});
    session.runCommand(QStringLiteral("manage-document"));
    QVERIFY(session.documentView()->active());
    QTRY_VERIFY(callAt(backend, "PUT", doc + QStringLiteral("/controlled-docs")) >= 0);
    QTRY_VERIFY(!session.controlledDocs()->busy());
    QCOMPARE(session.controlledDocs()->notice(), QStringLiteral("control_enabled"));
}

// A Markdown file uploaded where reviews are required, which the space's
// catalog says by granting the managing action, waits on whether to manage
// it with reviews, asked every time; kept, each one is managed once it lands,
// with the revision Core reads back. Other files, and spaces whose catalog
// does not grant that action, upload as before.
void TestCore::uploadsManagedWithReviews()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const auto document = [&](int id) { return matome::contentPath(org, space, QStringLiteral("documents/%1").arg(id)); };
    const auto controls = [&](qsizetype from) {
        for (auto at = from; at < backend.calls.size(); ++at)
            if (backend.calls.at(at).path.endsWith(QLatin1String("/controlled-docs"))) return true;
        return false;
    };
    const auto catalog = [&](bool manages) {
        backend.respond("GET", matome::orgPath(org, QStringLiteral("action-catalog?space_id=") + space),
                        {{QStringLiteral("actions"), QJsonArray{
                            QJsonObject{{QStringLiteral("key"), QStringLiteral("content.list")}, {QStringLiteral("allowed"), true}},
                            QJsonObject{{QStringLiteral("key"), QStringLiteral("upload.create")}, {QStringLiteral("allowed"), true}},
                            QJsonObject{{QStringLiteral("key"), QStringLiteral("folder.create")}, {QStringLiteral("allowed"), manages}},
                            QJsonObject{{QStringLiteral("key"), QStringLiteral("addon.controlled_docs.document_manage")},
                                        {QStringLiteral("allowed"), manages}}}}});
        session.runCommand(QStringLiteral("refresh"));
        // Folders follow the same catalog, which shows it was read.
        return QTest::qWaitFor([&] { return waitFor(&session) && usable(session, QStringLiteral("new")) == manages; });
    };
    QSignalSpy asked(&session, &Session::promptUploadReviews);
    serveControlledDocs(backend, org);
    QVERIFY(followCatalog(session));
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());

    // Not active in the space: the file goes up without asking.
    QVERIFY(catalog(false));
    session.upload(QStringLiteral("free.md"), "# Free\n");
    QTRY_VERIFY(!core.landed(QStringLiteral("free.md")).isEmpty());
    QTRY_VERIFY(!session.uploadBusy());
    QCOMPARE(asked.size(), 0);
    QVERIFY(!controls(0));

    QVERIFY(catalog(true));
    session.upload(QStringLiteral("plan.md"), "# Plan\n");
    session.upload(QStringLiteral("notes.txt"), "notes");
    session.upload(QStringLiteral("guide.MD"), "# Guide\n");
    QCOMPARE(session.reviewUploads(), 2);
    QCOMPARE(asked.size(), 1);
    QTRY_VERIFY(!core.landed(QStringLiteral("notes.txt")).isEmpty());
    QVERIFY(core.landed(QStringLiteral("plan.md")).isEmpty());

    // Documents 3 and 4: Core reads back each revision, then one refuses control.
    backend.respond("GET", document(3), {{QStringLiteral("document"), QJsonObject{{QStringLiteral("id"), 3}, {QStringLiteral("revision"), 2}}}});
    backend.respond("PUT", document(3) + QStringLiteral("/controlled-docs"), {});
    backend.respond("GET", document(4), {{QStringLiteral("document"), QJsonObject{{QStringLiteral("id"), 4}, {QStringLiteral("revision"), 5}}}});
    backend.queue("PUT", document(4) + QStringLiteral("/controlled-docs"),
                  refusal(409, QStringLiteral("incompatible_publication_subscriptions")));
    const qsizetype kept = backend.calls.size();
    session.uploadStaged(true);
    QCOMPARE(session.reviewUploads(), 0);
    QTRY_VERIFY(!core.landed(QStringLiteral("guide.MD")).isEmpty());
    QTRY_VERIFY(!session.uploadBusy());
    QCOMPARE(core.documentTitled(QStringLiteral("plan.md")).value(QStringLiteral("id")).toString(), QStringLiteral("3"));
    QCOMPARE(core.documentTitled(QStringLiteral("guide.MD")).value(QStringLiteral("id")).toString(), QStringLiteral("4"));
    const qsizetype read = callAt(backend, "GET", document(3), kept);
    const qsizetype managed = callAt(backend, "PUT", document(3) + QStringLiteral("/controlled-docs"), kept);
    QVERIFY(read >= 0 && managed > read);
    QVERIFY(backend.calls.at(managed).headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("2"))));
    const qsizetype refused = callAt(backend, "PUT", document(4) + QStringLiteral("/controlled-docs"), kept);
    QVERIFY(refused >= 0);
    QVERIFY(backend.calls.at(refused).headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("5"))));
    QCOMPARE(session.uploadError(), QStringLiteral("incompatible_publication_subscriptions"));
    QCOMPARE(session.uploadErrorName(), QStringLiteral("guide.MD"));
    QVERIFY(session.uploadLanded());

    // Unchecked, the file lands unmanaged; cancelled, it never goes up.
    const qsizetype unchecked = backend.calls.size();
    session.upload(QStringLiteral("loose.md"), "# Loose\n");
    QCOMPARE(session.uploadError(), QString());
    QVERIFY(!session.uploadLanded());
    QCOMPARE(session.reviewUploads(), 1);
    QCOMPARE(asked.size(), 2);
    session.uploadStaged(false);
    QTRY_VERIFY(!core.landed(QStringLiteral("loose.md")).isEmpty());
    QTRY_VERIFY(!session.uploadBusy());
    QVERIFY(!controls(unchecked));
    session.upload(QStringLiteral("dropped.md"), "# Dropped\n");
    QCOMPARE(session.reviewUploads(), 1);
    QCOMPARE(asked.size(), 3);
    session.cancelStaged();
    QCOMPARE(session.reviewUploads(), 0);
    QVERIFY(!session.uploadBusy());
    QVERIFY(core.documentTitled(QStringLiteral("dropped.md")).isEmpty());
}

void TestCore::spaceSettingsManageAccessAndRule()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QString addOns = matome::contentPath(org, space, QStringLiteral("add-ons"));
    const QString activation = addOns + QStringLiteral("/controlled_docs");
    const QJsonObject owner{{QStringLiteral("id"), QStringLiteral("owner-role")}, {QStringLiteral("key"), QStringLiteral("owner")},
                            {QStringLiteral("name"), QStringLiteral("Owner")}, {QStringLiteral("origin"), QStringLiteral("system")}};
    const QJsonObject editor{{QStringLiteral("id"), QStringLiteral("editor-role")}, {QStringLiteral("key"), QStringLiteral("content_contributor")},
                             {QStringLiteral("name"), QStringLiteral("Content contributor")}, {QStringLiteral("origin"), QStringLiteral("system")}};
    const QJsonObject manager{{QStringLiteral("id"), QStringLiteral("manager-role")}, {QStringLiteral("key"), QStringLiteral("addon.controlled_docs.manager")},
                              {QStringLiteral("name"), QStringLiteral("Controlled documents manager")}, {QStringLiteral("origin"), QStringLiteral("add_on")},
                              {QStringLiteral("actions"), QJsonArray{QStringLiteral("addon.controlled_docs.review_read"),
                                  QStringLiteral("addon.controlled_docs.document_manage")}}};
    backend.respond("GET", matome::orgPath(org, QStringLiteral("roles")), {{QStringLiteral("roles"), QJsonArray{owner, editor, manager}}});
    backend.respond("GET", matome::orgPath(org, QStringLiteral("members")),
                    {{QStringLiteral("members"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("me")},
                        {QStringLiteral("email"), session.identifier()}, {QStringLiteral("user_id"), session.userId()}}}}});
    const QJsonObject editing{{QStringLiteral("id"), QStringLiteral("grant-one")}, {QStringLiteral("role_id"), QStringLiteral("editor-role")},
                              {QStringLiteral("principal_kind"), QStringLiteral("user")}, {QStringLiteral("organization_membership_id"), QStringLiteral("me")}};
    QJsonObject own = editing;
    own.insert(QStringLiteral("source"), QJsonObject{{QStringLiteral("kind"), QStringLiteral("space")}, {QStringLiteral("id"), space}});
    own.insert(QStringLiteral("inherited"), false);
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("access")), {{QStringLiteral("access"), QJsonArray{own}}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("grants")), {{QStringLiteral("grants"), QJsonArray{editing}}});
    auto *access = session.accessGrants();
    access->open(QStringLiteral("space"), space, space, QStringLiteral("Inbox"));
    QTRY_VERIFY(!access->busy());
    // The built-in organization roles and the add-on's may be given across
    // the organization; a space role may not.
    QCOMPARE(session.accessDirectory()->assignableRoles().size(), 2);
    QCOMPARE(session.accessDirectory()->assignableRoles().constFirst().toMap().value(QStringLiteral("key")).toString(),
             QStringLiteral("owner"));
    QCOMPARE(session.accessDirectory()->assignableRoles().constLast().toMap().value(QStringLiteral("key")).toString(),
             QStringLiteral("addon.controlled_docs.manager"));
    const auto held = access->holders().constFirst().toMap();
    QCOMPARE(held.value(QStringLiteral("principal")).toString(), QStringLiteral("user:me"));
    QCOMPARE(held.value(QStringLiteral("principalName")).toString(), session.identifier());
    QCOMPARE(held.value(QStringLiteral("roleIds")).toStringList(), QStringList{QStringLiteral("editor-role")});
    QVERIFY(access->inherited().isEmpty());
    backend.respond("PUT", matome::contentPath(org, space, QStringLiteral("grants")), {{QStringLiteral("grants"), QJsonArray()}});
    access->setRoles(QStringLiteral("user:me"), {});
    QTRY_COMPARE(access->notice(), QStringLiteral("access_removed"));
    QCOMPARE(lastCall(backend, "PUT", matome::contentPath(org, space, QStringLiteral("grants"))).body,
             (QJsonObject{{QStringLiteral("organization_membership_id"), QStringLiteral("me")}, {QStringLiteral("role_ids"), QJsonArray()}}));
    QTRY_VERIFY(!access->busy());
    access->close();

    // Reading the space's add-ons needs add_on.space_activate there: a
    // refused space lists nothing and says why.
    serveControlledDocs(backend, org);
    QVERIFY(followCatalog(session));
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")), {{QStringLiteral("spaces"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), space}, {QStringLiteral("name"), QStringLiteral("Inbox")}}}}});
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    backend.respond("GET", addOns, {}, 403, QStringLiteral("forbidden"));
    auto *activations = session.addOnActivations();
    activations->open();
    QTRY_VERIFY(!activations->busy());
    QVERIFY(activations->rows().isEmpty());
    QCOMPARE(activations->readError(), QStringLiteral("forbidden"));
    const int refused = backend.calls.size();
    activations->activate(space, QStringLiteral("controlled_docs"));
    QCOMPARE(backend.calls.size(), refused);

    // Never turned on: the first activation sends no revision, and Core's
    // answer takes the row's place.
    backend.respond("GET", addOns, spaceAddOns(false, {}, QJsonValue::Null));
    activations->refresh();
    QTRY_VERIFY(!activations->busy());
    QCOMPARE(activations->rows().size(), 1);
    const auto row = activations->rows().constFirst().toMap();
    QCOMPARE(row.value(QStringLiteral("space_id")).toString(), space);
    QCOMPARE(row.value(QStringLiteral("space_name")).toString(), QStringLiteral("Inbox"));
    QCOMPARE(row.value(QStringLiteral("status")).toString(), QStringLiteral("inactive"));
    const int deactivating = backend.calls.size();
    activations->deactivate(space, QStringLiteral("controlled_docs"));
    QCOMPARE(backend.calls.size(), deactivating);
    backend.respond("PUT", activation, {{QStringLiteral("add_on"), spaceAddOns(true, {}, 1).value(QStringLiteral("add_ons")).toArray().first()}});
    activations->activate(space, QStringLiteral("controlled_docs"));
    QTRY_COMPARE(activations->notice(), QStringLiteral("activated"));
    const auto first = lastCall(backend, "PUT", activation);
    QVERIFY(first.body.isEmpty());
    QVERIFY(std::none_of(first.headers.begin(), first.headers.end(), [](const auto &header) { return header.first == "If-Match"; }));
    QCOMPARE(activations->rows().constFirst().toMap().value(QStringLiteral("status")).toString(), QStringLiteral("active"));
    QTRY_VERIFY(!activations->busy());

    // On, a space overrides one setting and follows the organization again
    // on another, at the activation's revision.
    backend.respond("GET", addOns, spaceAddOns(true, {{QStringLiteral("allow_author_approval"), true}}, 4));
    activations->refresh();
    QTRY_VERIFY(!activations->busy());
    activations->activate(space, QStringLiteral("controlled_docs"),
                          {{QStringLiteral("required_approvals"), 2},
                           {QStringLiteral("allow_author_approval"), QVariant::fromValue(nullptr)}});
    QTRY_COMPARE(activations->notice(), QStringLiteral("activation_saved"));
    const auto saved = lastCall(backend, "PUT", activation);
    const auto settings = saved.body.value(QStringLiteral("settings")).toObject();
    QCOMPARE(settings.value(QStringLiteral("required_approvals")).toInt(), 2);
    QVERIFY(settings.contains(QStringLiteral("allow_author_approval")));
    QVERIFY(settings.value(QStringLiteral("allow_author_approval")).isNull());
    QVERIFY(saved.headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("4"))));
    QTRY_VERIFY(!activations->busy());

    // Open reviews keep it as it is, which Core says.
    backend.respond("GET", addOns, spaceAddOns(true, {}, 4));
    activations->refresh();
    QTRY_VERIFY(!activations->busy());
    backend.queue("DELETE", activation, refusal(409, QStringLiteral("review_open")));
    activations->deactivate(space, QStringLiteral("controlled_docs"));
    QTRY_VERIFY(!activations->busy());
    QCOMPARE(activations->errorCode(), QStringLiteral("review_open"));
    backend.respond("DELETE", activation, {{QStringLiteral("add_on"), spaceAddOns(false, {}, 5).value(QStringLiteral("add_ons")).toArray().first()}});
    activations->deactivate(space, QStringLiteral("controlled_docs"));
    const auto off = lastCall(backend, "DELETE", activation);
    QVERIFY(off.body.isEmpty());
    QVERIFY(off.headers.contains(qMakePair(QByteArrayLiteral("If-Match"), QByteArrayLiteral("4"))));
    QTRY_COMPARE(activations->notice(), QStringLiteral("deactivated"));
    QTRY_VERIFY(!activations->busy());
    // A pause in the organization reads every space again.
    const int reads = std::count_if(backend.calls.cbegin(), backend.calls.cend(),
                                    [&addOns](const auto &call) { return call.method == "GET" && call.path == addOns; });
    serveControlledDocs(backend, org, QStringLiteral("paused"));
    QVERIFY(followCatalog(session));
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")), {{QStringLiteral("spaces"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), space}, {QStringLiteral("name"), QStringLiteral("Inbox")}}}}});
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    QTRY_VERIFY(std::count_if(backend.calls.cbegin(), backend.calls.cend(),
                              [&addOns](const auto &call) { return call.method == "GET" && call.path == addOns; }) > reads);
    activations->close();
    access->close();
    QVERIFY(!activations->active() && !access->active());
}

// Before a pause or an uninstall, the holders of the roles the add-on adds
// are counted over the organization's spaces, where it is available, from
// their grants.
void TestCore::addOnAccessCountsRoleHolders()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId();
    serveControlledDocs(backend, org);
    QVERIFY(followCatalog(session));
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")), {{QStringLiteral("spaces"), QJsonArray{
        QJsonObject{{QStringLiteral("id"), QStringLiteral("a")}}, QJsonObject{{QStringLiteral("id"), QStringLiteral("b")}}}}});
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    const auto grant = [](const QString &field, const QString &id, const QString &key) {
        return QJsonObject{{QStringLiteral("principal_kind"), field == QLatin1String("group_id") ? QStringLiteral("group") : QStringLiteral("user")},
                           {field, id}, {QStringLiteral("role_key"), key}};
    };
    const QString user = QStringLiteral("organization_membership_id");
    backend.respond("GET", matome::contentPath(org, QStringLiteral("a"), QStringLiteral("grants")), {{QStringLiteral("grants"), QJsonArray{
        grant(user, QStringLiteral("me"), QStringLiteral("content_reader")),
        grant(user, QStringLiteral("me"), QStringLiteral("addon.controlled_docs.reviewer")),
        grant(QStringLiteral("group_id"), QStringLiteral("g"), QStringLiteral("addon.controlled_docs.approver"))}}});
    backend.respond("GET", matome::contentPath(org, QStringLiteral("b"), QStringLiteral("grants")), {{QStringLiteral("grants"), QJsonArray{
        grant(user, QStringLiteral("bo"), QStringLiteral("space_admin")),
        grant(user, QStringLiteral("bo"), QStringLiteral("addon.controlled_docs.manager")),
        grant(user, QStringLiteral("me"), QStringLiteral("addon.controlled_docs.reviewer"))}}});
    auto *access = session.addOnAccess();
    access->measure(QStringLiteral("controlled_docs"));
    QVERIFY(!access->impact().value(QStringLiteral("known")).toBool());
    QTRY_VERIFY(!access->busy());
    const QVariantMap impact = access->impact();
    QVERIFY(impact.value(QStringLiteral("known")).toBool());
    QCOMPARE(impact.value(QStringLiteral("holders")).toInt(), 3);
    QCOMPARE(impact.value(QStringLiteral("spaces")).toInt(), 2);
    // `me` holds the reviewer role in both spaces and counts once.
    QCOMPARE(impact.value(QStringLiteral("roles")).toMap(),
             (QVariantMap{{QStringLiteral("addon.controlled_docs.reviewer"), 1}, {QStringLiteral("addon.controlled_docs.approver"), 1},
                          {QStringLiteral("addon.controlled_docs.manager"), 1}}));
    // Nobody holds the classifier's roles.
    access->measure(QStringLiteral("classifier"));
    QTRY_VERIFY(!access->busy());
    QVERIFY(access->impact().value(QStringLiteral("known")).toBool());
    QCOMPARE(access->impact().value(QStringLiteral("holders")).toInt(), 0);
    // A space that cannot be read leaves the count unknown.
    backend.respond("GET", matome::contentPath(org, QStringLiteral("b"), QStringLiteral("grants")), {}, 403, QStringLiteral("forbidden"));
    access->measure(QStringLiteral("controlled_docs"));
    QTRY_VERIFY(!access->busy());
    QVERIFY(!access->impact().value(QStringLiteral("known")).toBool());
    // An organization without spaces: nobody holds anything.
    backend.respond("GET", matome::orgPath(org, QStringLiteral("spaces")), {{QStringLiteral("spaces"), QJsonArray()}});
    session.addOns()->refresh();
    QTRY_VERIFY(!session.addOns()->busy());
    access->measure(QStringLiteral("classifier"));
    QTRY_VERIFY(!access->busy());
    QVERIFY(access->impact().value(QStringLiteral("known")).toBool());
    QCOMPARE(access->impact().value(QStringLiteral("holders")).toInt(), 0);
    // Another organization drops what was counted.
    core.seedOrganization(QStringLiteral("Other"), QStringLiteral("owner"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    session.navigate(QStringLiteral("org"), session.organizations()->index(1).data(OrgModel::OrgIdRole).toString());
    QTRY_VERIFY(access->impact().isEmpty());
}

void TestCore::orgBillingPermissionsAndStaleReplies()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString ownerId = session.currentOrgId();
    core.seedOrganization(QStringLiteral("Finance"), QStringLiteral("billing"));
    core.seedOrganization(QStringLiteral("Admin"), QStringLiteral("admin"));
    session.refreshOrganizations();
    QVERIFY(waitFor(&session));
    const QString financeId = session.organizations()->index(1).data(OrgModel::OrgIdRole).toString();
    const QString adminId = session.organizations()->index(2).data(OrgModel::OrgIdRole).toString();
    QVERIFY(core.failNext(QStringLiteral("GET"), matome::orgPath(ownerId, QStringLiteral("billing/subscription")),
                          1, FakeCore::FaultMode::Hold));
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_COMPARE(core.held(), 1);
    session.navigate(QStringLiteral("org"), financeId);
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->active());
    QVERIFY(billing->canManage());
    QVERIFY(!session.addOns()->canInstall());
    QVERIFY(!session.orgAdmin()->active());
    QVERIFY(billing->billingError().isEmpty());
    QVERIFY(billing->usageError().isEmpty());
    core.release();
    QTest::qWait(20);
    QCOMPARE(billing->name(), QStringLiteral("Finance"));
    billing->createPortal();
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->paymentUrl().startsWith(QStringLiteral("https://billing.stripe.com/")));
    session.navigate(QStringLiteral("org"), adminId);
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->paymentUrl().isEmpty());
    QVERIFY(!billing->canManage());
    QVERIFY(session.addOns()->canInstall());
    const int hits = core.hits();
    billing->createPortal();
    billing->setQuantity(QStringLiteral("classifier-1000"), 2);
    QTest::qWait(20);
    QCOMPARE(core.hits(), hits);
    session.signOut();
    QVERIFY(!billing->active());
    QVERIFY(billing->products().isEmpty());
}

void TestCore::orgBillingPreservesPurchasesAndGrants()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    core.seedSubscription(session.currentOrgId(), {{QStringLiteral("status"), QStringLiteral("active")},
            {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("team")}, {QStringLiteral("version"), 1}}},
            {QStringLiteral("add_ons"), QJsonArray{
                QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier-1000")}, {QStringLiteral("quantity"), 1}},
                QJsonObject{{QStringLiteral("key"), QStringLiteral("storage-10gb")}, {QStringLiteral("quantity"), 3}}}}});
    core.seedAddOns(session.currentOrgId(), {QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier")},
            {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier-1000")},
                {QStringLiteral("version"), 1}, {QStringLiteral("quantity"), 5}}}}}});
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_VERIFY(!billing->busy());
    QVERIFY(session.addOns()->errorCode().isEmpty());
    const QVariantMap sku = billing->products().first().toMap().value(QStringLiteral("skus")).toList().first().toMap();
    QCOMPARE(sku.value(QStringLiteral("assigned")).toInt(), 5);
    QCOMPARE(sku.value(QStringLiteral("purchased")).toInt(), 1);
    billing->setQuantity(QStringLiteral("classifier-1000"), 2);
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->errorCode().isEmpty());
    QCOMPARE(core.billingRequest().value(QStringLiteral("plan")).toString(), QStringLiteral("team"));
    const QJsonArray desired = core.billingRequest().value(QStringLiteral("add_ons")).toArray();
    QCOMPARE(desired.size(), 2);
    QCOMPARE(desired.first().toObject().value(QStringLiteral("quantity")).toInt(), 3);
    QCOMPARE(desired.last().toObject().value(QStringLiteral("quantity")).toInt(), 2);
    QCOMPARE(billing->subscription().value(QStringLiteral("add_ons")).toList().first().toMap().value(QStringLiteral("quantity")).toInt(), 1);
    QCOMPARE(billing->notice(), QStringLiteral("billing_requested"));
    billing->setQuantity(QStringLiteral("classifier-1000"), 0);
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(core.billingRequest().value(QStringLiteral("add_ons")).toArray().size(), 1);
    QVERIFY(core.failNext(QStringLiteral("POST"), matome::orgPath(session.currentOrgId(), QStringLiteral("billing/portal-sessions")),
                          1, FakeCore::FaultMode::Status, 503, QStringLiteral("billing_disabled")));
    billing->createPortal();
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(billing->errorCode(), QStringLiteral("billing_disabled"));
    QVERIFY(billing->paymentUrl().isEmpty());
}

void TestCore::orgBillingConfiguresInstallation()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString spaceId = session.currentSpaceId();
    core.seedAddOns(session.currentOrgId(), {QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier")},
            {QStringLiteral("assignments"), QJsonArray{QJsonObject{{QStringLiteral("key"), QStringLiteral("classifier-1000")},
                {QStringLiteral("version"), 1}, {QStringLiteral("quantity"), 1}}}},
            {QStringLiteral("installation"), QJsonObject{{QStringLiteral("status"), QStringLiteral("paused")},
                {QStringLiteral("settings"), QJsonObject{{QStringLiteral("rerun"), true}}}}}}});
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_VERIFY(!billing->busy());
    session.addOns()->install(QStringLiteral("classifier"));
    QTRY_VERIFY(!billing->busy());
    const QVariantMap installation = billing->products().first().toMap().value(QStringLiteral("installation")).toMap();
    QCOMPARE(installation.value(QStringLiteral("status")).toString(), QStringLiteral("active"));
    QVERIFY(!installation.contains(QStringLiteral("space_ids")));
    QVERIFY(installation.value(QStringLiteral("settings")).toMap().value(QStringLiteral("rerun")).toBool());
    // Installed, it is available in the space and active there only once
    // the space turns it on.
    bool listed = false;
    session.addOns()->backend().request("GET", matome::contentPath(session.currentOrgId(), spaceId, QStringLiteral("add-ons")), {}, {},
                                        [&listed](const Client::Reply &reply) {
        const QJsonObject row = reply.json.value(QStringLiteral("add_ons")).toArray().first().toObject();
        listed = row.value(QStringLiteral("product_key")).toString() == QLatin1String("classifier")
                && row.value(QStringLiteral("status")).toString() == QLatin1String("inactive") && row.value(QStringLiteral("revision")).isNull();
    });
    QTRY_VERIFY(listed);
    session.addOns()->pause(QStringLiteral("classifier"));
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(billing->products().first().toMap().value(QStringLiteral("installation")).toMap()
                .value(QStringLiteral("status")).toString(), QStringLiteral("paused"));
}

void TestCore::orgBillingSelectsVersionedPackages()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString orgId = session.currentOrgId();
    core.seedPackages({QJsonObject{{QStringLiteral("key"), QStringLiteral("professional")},
            {QStringLiteral("name"), QStringLiteral("Professional")}, {QStringLiteral("version"), 1},
            {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("pro")}, {QStringLiteral("version"), 1}}},
            {QStringLiteral("add_ons"), QJsonArray()}},
            QJsonObject{{QStringLiteral("key"), QStringLiteral("professional")},
            {QStringLiteral("name"), QStringLiteral("Professional")}, {QStringLiteral("version"), 2},
            {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("pro")}, {QStringLiteral("version"), 1}}},
            {QStringLiteral("add_ons"), QJsonArray()}}});
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->packagesError().isEmpty());
    QCOMPARE(billing->packages().size(), 2);
    const int hits = core.hits();
    billing->selectPackage(QStringLiteral("professional"), 3);
    QTest::qWait(20);
    QCOMPARE(core.hits(), hits);
    QVERIFY(core.failNext(QStringLiteral("POST"), matome::orgPath(orgId, QStringLiteral("billing/checkout-sessions")),
                          1, FakeCore::FaultMode::Expire));
    billing->selectPackage(QStringLiteral("professional"), 2);
    QTRY_VERIFY(!billing->busy());
    QVERIFY(billing->errorCode().isEmpty());
    QVERIFY(!core.lastIdempotency().isEmpty());
    QCOMPARE(billing->notice(), QStringLiteral("checkout"));
    QVERIFY(billing->paymentUrl().startsWith(QStringLiteral("https://checkout.stripe.com/")));
    QCOMPARE(core.billingRequest().value(QStringLiteral("package")).toObject().value(QStringLiteral("version")).toInt(), 2);
    QCOMPARE(core.billingRequest().value(QStringLiteral("success_url")), core.billingRequest().value(QStringLiteral("cancel_url")));
    QVERIFY(core.billingRequest().contains(QStringLiteral("success_url")));
    QVERIFY(!core.billingRequest().contains(QStringLiteral("add_ons")));
    QVERIFY(!core.billingRequest().contains(QStringLiteral("plan")));
    QVERIFY(billing->subscription().isEmpty());
    core.seedSubscription(orgId, {{QStringLiteral("status"), QStringLiteral("active")},
            {QStringLiteral("plan"), QJsonObject{{QStringLiteral("key"), QStringLiteral("team")}}}});
    billing->refresh();
    QTRY_VERIFY(!billing->busy());
    billing->selectPackage(QStringLiteral("professional"), 2);
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(billing->notice(), QStringLiteral("billing_requested"));
    QVERIFY(!core.billingRequest().contains(QStringLiteral("success_url")));
    QVERIFY(!core.billingRequest().contains(QStringLiteral("add_ons")));
    QCOMPARE(billing->subscription().value(QStringLiteral("plan")).toMap().value(QStringLiteral("key")).toString(), QStringLiteral("team"));
    QVERIFY(billing->paymentUrl().isEmpty());
    core.seedSubscription(orgId, {{QStringLiteral("status"), QStringLiteral("active")}, {QStringLiteral("pending_update"), true}});
    billing->refresh();
    QTRY_VERIFY(!billing->busy());
    const int pendingHits = core.hits();
    billing->selectPackage(QStringLiteral("professional"), 2);
    QTest::qWait(20);
    QCOMPARE(core.hits(), pendingHits);
}

void TestCore::orgBillingExpiresCheckoutLinks()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    core.seedPackages({QJsonObject{{QStringLiteral("key"), QStringLiteral("pro")}, {QStringLiteral("version"), 1}}});
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_VERIFY(!billing->busy());
    core.checkoutExpiresAt = QDateTime::currentDateTimeUtc().addSecs(-1);
    billing->selectPackage(QStringLiteral("pro"), 1);
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(billing->errorCode(), QStringLiteral("checkout_expired"));
    QVERIFY(billing->paymentUrl().isEmpty());
    core.checkoutExpiresAt = QDateTime::currentDateTimeUtc().addMSecs(1000);
    billing->selectPackage(QStringLiteral("pro"), 1);
    QTRY_VERIFY(!billing->busy());
    QVERIFY(!billing->paymentUrl().isEmpty());
    QTRY_COMPARE(billing->errorCode(), QStringLiteral("checkout_expired"));
    QVERIFY(billing->paymentUrl().isEmpty());
    core.checkoutExpiresAt = QDateTime::currentDateTimeUtc().addMSecs(1000);
    billing->selectPackage(QStringLiteral("pro"), 1);
    QTRY_VERIFY(!billing->busy());
    billing->createPortal();
    QTRY_VERIFY(!billing->busy());
    QTest::qWait(1100);
    QVERIFY(billing->errorCode().isEmpty());
    QCOMPARE(billing->notice(), QStringLiteral("portal"));
    QVERIFY(billing->paymentUrl().startsWith(QStringLiteral("https://billing.stripe.com/")));
    core.checkoutExpiresAt = QDateTime::currentDateTimeUtc().addMSecs(1000);
    billing->selectPackage(QStringLiteral("pro"), 1);
    QTRY_VERIFY(!billing->busy());
    session.closeSettings();
    QTest::qWait(1100);
    QVERIFY(billing->errorCode().isEmpty());
    QVERIFY(billing->paymentUrl().isEmpty());
}

void TestCore::orgBillingReportsPackageFailures()
{
    FakeCore core;
    QVERIFY(core.listen());
    Session session;
    QVERIFY(openInbox(core, session));
    const QString orgId = session.currentOrgId();
    core.seedPackages({QJsonObject{{QStringLiteral("key"), QStringLiteral("pro")}, {QStringLiteral("version"), 1}}});
    session.openSettings();
    auto *billing = session.orgBilling();
    QTRY_VERIFY(!billing->busy());
    for (const auto &error : {QStringLiteral("unknown_package"), QStringLiteral("package_unavailable"),
                             QStringLiteral("billing_provider_error")}) {
        QVERIFY(core.failNext(QStringLiteral("POST"), matome::orgPath(orgId, QStringLiteral("billing/checkout-sessions")),
                              1, FakeCore::FaultMode::Status, error == QLatin1String("billing_provider_error") ? 502 : 422, error));
        billing->selectPackage(QStringLiteral("pro"), 1);
        QTRY_VERIFY(!billing->busy());
        QCOMPARE(billing->errorCode(), error);
        QVERIFY(billing->paymentUrl().isEmpty());
        QVERIFY(billing->subscription().isEmpty());
    }
    QVERIFY(core.failNext(QStringLiteral("GET"), matome::orgPath(orgId, QStringLiteral("billing/packages")),
                          1, FakeCore::FaultMode::Status, 403, QStringLiteral("forbidden")));
    billing->refresh();
    QTRY_VERIFY(!billing->busy());
    QCOMPARE(billing->packagesError(), QStringLiteral("forbidden"));
    QVERIFY(billing->packages().isEmpty());
    const int hits = core.hits();
    billing->selectPackage(QStringLiteral("pro"), 1);
    QTest::qWait(20);
    QCOMPARE(core.hits(), hits);
}

void TestCore::markdownReferencesFollowAssetLinks()
{
    const QString a = QStringLiteral("11111111-2222-3333-4444-555555555555");
    const QString b = QStringLiteral("66666666-7777-8888-9999-000000000000");
    const QString markdown = QStringLiteral("![a](matome:asset/3?version=%1) text ![b](matome:asset/4?version=%2)\n"
                                            "![again](matome:asset/3?version=%1) ![web](https://example.com/x.png)")
                                     .arg(a, b);
    const QJsonArray references = matome::Assets::references(markdown);
    QCOMPARE(references.size(), 2);
    QCOMPARE(references.at(0).toObject().value(QStringLiteral("document_id")).toInteger(), 3);
    QCOMPARE(references.at(1).toObject().value(QStringLiteral("version_id")).toString(), b);
    Session session;
    auto *assets = session.assets();
    const QString shown = assets->render(markdown, QStringLiteral("org"), QStringLiteral("space"), QStringLiteral("via"), 480, false);
    QVERIFY(shown.contains(QStringLiteral("(image://asset/org/space/via/3/%1?w=480)").arg(a)));
    QVERIFY(!shown.contains(QStringLiteral("![web]")));
    QVERIFY(shown.contains(QStringLiteral("https://example.com/x.png")));
    QVERIFY(assets->linksExternal(markdown));
    QVERIFY(assets->render(markdown, QStringLiteral("org"), QStringLiteral("space"), {}, 480, true)
                    .contains(QStringLiteral("![web](https://example.com/x.png)")));
    QVERIFY(assets->render(markdown, QStringLiteral("org"), QStringLiteral("space"), {}, 480, true)
                    .contains(QStringLiteral("image://asset/org/space/-/4/")));
    const QString doc = QStringLiteral("See [plan](matome:doc/9) and [pinned](matome:doc/9?version=%1), [plan](matome:doc/9).").arg(b);
    const QJsonArray docs = matome::Assets::references(doc);
    QCOMPARE(docs.size(), 2);
    QVERIFY(!docs.at(0).toObject().contains(QStringLiteral("version_id")));
    QCOMPARE(docs.at(0).toObject().value(QStringLiteral("document_id")).toInteger(), 9);
    QCOMPARE(docs.at(1).toObject().value(QStringLiteral("version_id")).toString(), b);
    QCOMPARE(assets->referenceAt(doc, 1).value(QStringLiteral("start")).toInt(), doc.indexOf(QStringLiteral("](matome:doc/9?version")));
    QCOMPARE(matome::Assets::markdownLink(QStringLiteral("a [b].png"), QStringLiteral("3"), a, true),
             QStringLiteral("![a b.png](matome:asset/3?version=%1)").arg(a));
    QCOMPARE(matome::Assets::markdownLink(QStringLiteral("plan.md"), QStringLiteral("9"), {}, false),
             QStringLiteral("[plan.md](matome:doc/9)"));
    QCOMPARE(matome::Assets::markdownLink(QStringLiteral("plan.md"), QStringLiteral("9"), b, false),
             QStringLiteral("[plan.md](matome:doc/9?version=%1)").arg(b));
    QCOMPARE(matome::Assets::pathLink(QStringLiteral("plan [v2].md"), QStringLiteral("/Specs (old)/plan [v2].md")),
             QStringLiteral("[plan v2.md](/Specs%20%28old%29/plan%20%5Bv2%5D.md)"));
    // `/` links are path references, decoded, in text order among the others
    // and once each by Core's name key; other sites and folders are not.
    const QString paths = QStringLiteral("[plan](/Specs%20%28old%29/plan%20%5Bv2%5D.md) [pin](matome:doc/9?version=%1)\n"
                                         "[again](/specs%20(OLD)/Plan%20[v2].md#top) [titled](/notes.md \"Notes\")\n"
                                         "[web](//example.com/x) [site](https://example.com/y) [folder](/Specs/) [root](/)")
                                  .arg(b);
    const QJsonArray declared = matome::Assets::references(paths);
    QCOMPARE(declared.size(), 3);
    QCOMPARE(declared.at(0).toObject(), (QJsonObject{{QStringLiteral("path"), QStringLiteral("/Specs (old)/plan [v2].md")}}));
    QCOMPARE(declared.at(1).toObject().value(QStringLiteral("document_id")).toInteger(), 9);
    QCOMPARE(declared.at(2).toObject(), (QJsonObject{{QStringLiteral("path"), QStringLiteral("/notes.md")}}));
    QCOMPARE(assets->referenceAt(paths, 2).value(QStringLiteral("start")).toInt(), paths.indexOf(QStringLiteral("](/notes.md")));
    const QJsonArray pinned = matome::Assets::references(paths, false);
    QCOMPARE(pinned.size(), 1);
    QCOMPARE(pinned.at(0).toObject().value(QStringLiteral("document_id")).toInteger(), 9);
    QCOMPARE(assets->referenceAt(paths, 0, false).value(QStringLiteral("start")).toInt(), paths.indexOf(QStringLiteral("](matome:doc/9")));
    const QVariantMap at = assets->referenceAt(markdown, 1);
    QCOMPARE(markdown.mid(at.value(QStringLiteral("start")).toInt(), at.value(QStringLiteral("length")).toInt()),
             QStringLiteral("](matome:asset/4?version=%1)").arg(b));
    QVERIFY(assets->referenceAt(markdown, 2).isEmpty());
}

void TestCore::assetsSearchFindsFilesByName()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const auto document = [](int id, const QString &title, const QString &folder, const QString &detected) {
        QJsonObject version{{QStringLiteral("id"), QStringLiteral("v%1").arg(id)}};
        if (!detected.isEmpty())
            version.insert(QStringLiteral("detected_content_type"), detected);
        return QJsonObject{{QStringLiteral("id"), id}, {QStringLiteral("title"), title},
                           {QStringLiteral("folder_id"), folder.isEmpty() ? QJsonValue() : QJsonValue(folder)},
                           {QStringLiteral("current_version"), version}};
    };
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents?limit=25&q=plan")),
                    {{QStringLiteral("documents"), QJsonArray{document(1, QStringLiteral("Old plan.md"), {}, {}),
                        document(2, QStringLiteral("plan.png"), {}, QStringLiteral("image/png")),
                        document(3, QStringLiteral("Travel plan.md"), QStringLiteral("near"), {}),
                        document(4, QStringLiteral("plan.md"), {}, {})}}});
    auto *assets = session.assets();
    QSignalSpy found(assets, &matome::Assets::found);
    assets->search(QStringLiteral("plan"), QStringLiteral("near"), QStringLiteral("4"));
    QTRY_COMPARE(found.size(), 1);
    QCOMPARE(found.constFirst().at(0).toString(), QStringLiteral("plan"));
    const QVariantList files = found.constFirst().at(1).toList();
    QStringList titles;
    for (const QVariant &file : files) titles.append(file.toMap().value(QStringLiteral("title")).toString());
    QCOMPARE(titles, (QStringList{QStringLiteral("Travel plan.md"), QStringLiteral("plan.png"), QStringLiteral("Old plan.md")}));
    QVERIFY(files.at(1).toMap().value(QStringLiteral("image")).toBool());
    QCOMPARE(files.at(1).toMap().value(QStringLiteral("versionId")).toString(), QStringLiteral("v2"));
    QCOMPARE(files.at(2).toMap().value(QStringLiteral("place")).toString(), session.spaces()->nameOf(space));
    QCOMPARE(files.at(2).toMap().value(QStringLiteral("path")).toString(), QStringLiteral("/Old plan.md"));
}

void TestCore::assetsResolvePathLinks()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    session.folders()->create(QStringLiteral("Specs (old)"));
    QTRY_COMPARE(session.folders()->rowCount(), 1);
    const QString folder = session.folders()->data(session.folders()->index(0), FolderModel::FolderIdRole).toString();
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents?limit=100&folder_id=%1&q=plan%20v2.md").arg(folder)),
                    {{QStringLiteral("documents"), QJsonArray{
                        QJsonObject{{QStringLiteral("id"), 7}, {QStringLiteral("title"), QStringLiteral("old plan v2.md")}},
                        QJsonObject{{QStringLiteral("id"), 8}, {QStringLiteral("title"), QStringLiteral("plan v2.md")}}}}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents?limit=100&folder_id=root&q=gone.md")),
                    {{QStringLiteral("documents"), QJsonArray()}});
    auto *assets = session.assets();
    QSignalSpy resolved(assets, &matome::Assets::resolved);
    const QString link = matome::Assets::pathLink(QStringLiteral("plan v2.md"), QStringLiteral("/Specs (old)/plan v2.md"))
            .section(QLatin1Char('('), 1).chopped(1);
    QCOMPARE(link, QStringLiteral("/Specs%20%28old%29/plan%20v2.md"));
    assets->resolve(link);
    QTRY_COMPARE(resolved.size(), 1);
    QCOMPARE(resolved.at(0), (QVariantList{link, QStringLiteral("8")}));
    assets->resolve(QStringLiteral("/gone.md"));
    QTRY_COMPARE(resolved.size(), 2);
    QCOMPARE(resolved.at(1), (QVariantList{QStringLiteral("/gone.md"), QString()}));
    // A folder the space does not have answers at once, asking nothing.
    assets->resolve(QStringLiteral("/Nowhere/plan.md"));
    QCOMPARE(resolved.size(), 3);
    QCOMPARE(resolved.at(2), (QVariantList{QStringLiteral("/Nowhere/plan.md"), QString()}));
}

void TestCore::assetsUploadIntoAssetsFolder()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    const QByteArray png("\x89PNG\r\n\x1a\n-image-bytes", 20);
    const QString checksum = QString::fromLatin1(QCryptographicHash::hash(png, QCryptographicHash::Sha256).toHex());
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents?checksum_sha256=") + checksum),
                    {{QStringLiteral("documents"), QJsonArray()}});
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("folders")),
                    {{QStringLiteral("folders"), QJsonArray{QJsonObject{{QStringLiteral("id"), QStringLiteral("5")},
                        {QStringLiteral("name"), QStringLiteral("assets")}, {QStringLiteral("parent_id"), QStringLiteral("1")}}}}});
    backend.respond("POST", matome::contentPath(org, space, QStringLiteral("folders")),
                    {{QStringLiteral("folder"), QJsonObject{{QStringLiteral("id"), QStringLiteral("9")}}}}, 201);
    backend.queue("POST", matome::contentPath(org, space, QStringLiteral("documents")),
                  [] { Client::Reply taken; taken.status = 409; taken.code = QStringLiteral("name_conflict"); return taken; }());
    backend.respond("POST", matome::contentPath(org, space, QStringLiteral("documents")),
                    {{QStringLiteral("document"), QJsonObject{{QStringLiteral("id"), 77}}}}, 201);
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("upload_id"), QStringLiteral("image-upload")},
            {QStringLiteral("generation"), 1}, {QStringLiteral("request"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/image")}}}}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads/image-upload/complete")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("version"), QJsonObject{{QStringLiteral("id"), QStringLiteral("image-version")}}}}}});
    auto *assets = session.assets();
    QSignalSpy queued(assets, &matome::Assets::queued);
    QSignalSpy uploaded(assets, &matome::Assets::uploaded);
    QSignalSpy failed(assets, &matome::Assets::failed);
    assets->uploadImage(QStringLiteral("logo.png"), png);
    QCOMPARE(queued.size(), 1);
    QCOMPARE(queued.constFirst().at(1).toString(), QStringLiteral("logo.png"));
    QTRY_COMPARE(uploaded.size(), 1);
    QCOMPARE(failed.size(), 0);
    QStringList titles;
    for (const auto &call : backend.calls) {
        if (call.method == "POST" && call.path.endsWith(QLatin1String("/folders")))
            QCOMPARE(call.body.value(QStringLiteral("name")).toString(), QStringLiteral("assets"));
        if (call.method == "POST" && call.path.endsWith(QLatin1String("/documents"))) {
            QCOMPARE(call.body.value(QStringLiteral("folder_id")).toString(), QStringLiteral("9"));
            titles.append(call.body.value(QStringLiteral("title")).toString());
        }
        if (call.method == "POST" && call.path.endsWith(QLatin1String("/uploads")))
            QCOMPARE(call.body.value(QStringLiteral("content_type")).toString(), QStringLiteral("image/png"));
    }
    QCOMPARE(titles.size(), 2);
    QCOMPARE(titles.constFirst(), QStringLiteral("logo.png"));
    QVERIFY(titles.constLast().startsWith(QLatin1String("logo-")) && titles.constLast().endsWith(QLatin1String(".png")));
    QCOMPARE(uploaded.constFirst().at(1).toString(), QStringLiteral("![%1](matome:asset/77?version=image-version)").arg(titles.constLast()));
    backend.respond("GET", matome::contentPath(org, space, QStringLiteral("documents?checksum_sha256=") + checksum),
                    {{QStringLiteral("documents"), QJsonArray{QJsonObject{{QStringLiteral("id"), 77},
                        {QStringLiteral("current_version"), QJsonObject{{QStringLiteral("id"), QStringLiteral("image-version")}}}}}}});
    const int calls = backend.calls.size();
    assets->uploadImage({}, png);
    QTRY_COMPARE(uploaded.size(), 2);
    QVERIFY(uploaded.constLast().at(1).toString().startsWith(QLatin1String("![image-")));
    QVERIFY(uploaded.constLast().at(1).toString().endsWith(QLatin1String("](matome:asset/77?version=image-version)")));
    QCOMPARE(backend.calls.size(), calls + 1);
    assets->uploadImage(QStringLiteral("notes.txt"), QByteArray("plain text"));
    QCOMPARE(failed.size(), 1);
    QCOMPARE(failed.constFirst().at(1).toString(), QStringLiteral("unsupported_image"));
}

// A stored transfer counts as all its bytes before the upload completes,
// even when the transfer itself said nothing of its progress.
void TestCore::uploadsFillBeforeCompleting()
{
    matome::test::MockAddOnBackend backend;
    backend.reportsProgress = false;
    const QString org = QStringLiteral("org");
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads")),
        {{QStringLiteral("data"), QJsonObject{{QStringLiteral("upload_id"), QStringLiteral("up")},
            {QStringLiteral("generation"), 1}, {QStringLiteral("request"), QJsonObject{{QStringLiteral("url"), QStringLiteral("https://storage.invalid/up")}}}}}});
    backend.respond("POST", matome::orgPath(org, QStringLiteral("uploads/up/complete")), {});
    QList<QPair<qint64, qint64>> reported;
    int callsAtProgress = -1;
    bool finished = false;
    backend.upload(org, {}, QByteArray("five!"), [] { return true; },
                   [&finished](const Client::Reply &reply) { finished = reply.ok; },
                   [&](qint64 sent, qint64 total) { reported.append({sent, total}); callsAtProgress = backend.calls.size(); });
    QTRY_VERIFY(finished);
    QCOMPARE(reported, (QList<QPair<qint64, qint64>>{{5, 5}}));
    QCOMPARE(backend.calls.at(callsAtProgress - 1).method, QByteArray("PUTFILE"));
    QCOMPARE(backend.calls.constLast().path, matome::orgPath(org, QStringLiteral("uploads/up/complete")));
}

void TestCore::assetsSignThroughViaVersion()
{
    FakeCore core;
    QVERIFY(core.listen());
    matome::test::MockAddOnBackend backend;
    Session session(nullptr, &backend);
    QVERIFY(openInbox(core, session));
    const QString org = session.currentOrgId(), space = session.currentSpaceId();
    backend.respond("POST", matome::contentPath(org, space, QStringLiteral("documents/download-urls")),
        {{QStringLiteral("data"), QJsonArray{
            QJsonObject{{QStringLiteral("index"), 0}, {QStringLiteral("url"), QStringLiteral("https://storage.invalid/pinned")}},
            QJsonObject{{QStringLiteral("index"), 1}, {QStringLiteral("error"), QStringLiteral("purged")}}}}});
    const QByteArray png("\x89PNG\r\n\x1a\npinned", 14);
    backend.file(QUrl(QStringLiteral("https://storage.invalid/pinned")), png);
    auto *assets = session.assets();
    QByteArray shown;
    QString error;
    int answers = 0;
    assets->fetch({org, space, QStringLiteral("markdown-version"), QStringLiteral("7"), QStringLiteral("v-one")},
                  [&](const QByteArray &bytes, const QString &) { shown = bytes; ++answers; });
    assets->fetch({org, space, QStringLiteral("markdown-version"), QStringLiteral("8"), QStringLiteral("v-two")},
                  [&](const QByteArray &, const QString &code) { error = code; ++answers; });
    QTRY_COMPARE(answers, 2);
    QCOMPARE(shown, png);
    QCOMPARE(error, QStringLiteral("purged"));
    int signs = 0;
    for (const auto &call : backend.calls) {
        if (!call.path.endsWith(QLatin1String("/download-urls")))
            continue;
        ++signs;
        QCOMPARE(call.body.value(QStringLiteral("via_version_id")).toString(), QStringLiteral("markdown-version"));
        const QJsonArray items = call.body.value(QStringLiteral("items")).toArray();
        QCOMPARE(items.size(), 2);
        QVERIFY(items.at(0).toObject().value(QStringLiteral("document_id")).isDouble());
    }
    QCOMPARE(signs, 1);
    QVERIFY(matome::isRasterImage(png));
    QVERIFY(!matome::isRasterImage(QByteArray("<svg/>")));
    const int calls = backend.calls.size();
    assets->fetch({org, space, QStringLiteral("markdown-version"), QStringLiteral("7"), QStringLiteral("v-one")},
                  [&](const QByteArray &bytes, const QString &) { shown = bytes; ++answers; });
    QCOMPARE(answers, 3);
    QCOMPARE(backend.calls.size(), calls);
}

QTEST_GUILESS_MAIN(TestCore)
#include "tst_core.moc"
