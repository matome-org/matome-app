import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:matome_flutter/app/shell_scaffold.dart';
import 'package:matome_flutter/app/shell_tabs.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/documents/document_open_policy.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recording/meeting_recorder.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'package:matome_flutter/features/shell/widgets/matome_nav.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Drives `ShellScaffold(newNavShell: true)` (DR-002 / #1467). The const
/// `FeatureFlags.newNavShell` cannot be flipped at runtime, so this test injects
/// the flag-ON state via the [ShellScaffold.newNavShell] + [branchesOverride]
/// seams AND builds a router whose branches match the ON order
/// (inbox · calendar · files · contacts · spaces — SATORI EXCLUDED).
///
/// These assert what the flag turns ON; the legacy-shell characterization lives
/// in `test/shell_test.dart` (flag OFF) and stays green unchanged.

// The flag-ON branch order: satori is NOT a branch (its route is compiled out in
// router.dart under the const flag).
const _onBranches = [
  ShellTab.inbox,
  ShellTab.calendar,
  ShellTab.files,
  ShellTab.contacts,
  ShellTab.spaces,
];

/// A bare labelled screen per branch — the new-shell test cares about NAV
/// wiring, not screen content, so it avoids the real screens' provider graphs.
class _StubScreen extends StatelessWidget {
  const _StubScreen(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('SCREEN:$label')));
}

GoRouter _buildOnRouter({GlobalKey<NavigatorState>? rootKey}) {
  final key = rootKey ?? GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: key,
    initialLocation: '/inbox',
    routes: [
      GoRoute(
        path: '/recording',
        parentNavigatorKey: key,
        pageBuilder: (c, s) => const MaterialPage(
          fullscreenDialog: true,
          child: _StubScreen('recording'),
        ),
      ),
      GoRoute(
        path: '/meeting',
        parentNavigatorKey: key,
        pageBuilder: (c, s) => const MaterialPage(
          fullscreenDialog: true,
          child: _StubScreen('meeting'),
        ),
      ),
      // /satori is intentionally ABSENT — the new shell gates the ROUTE.
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => ShellScaffold(
          navigationShell: shell,
          newNavShell: true,
          branchesOverride: _onBranches,
        ),
        branches: [
          for (final tab in _onBranches)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.location,
                  builder: (c, s) => _StubScreen(tab.location),
                  routes: [
                    if (tab == ShellTab.inbox)
                      GoRoute(
                        path: 'settings',
                        builder: (c, s) => const _StubScreen('settings'),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

Widget _app(
  GoRouter router, {
  List<Override> overrides = const [],
  MeetingCaptureCapability meetingCapability =
      const MeetingCaptureCapability.supported(backendId: 'test'),
}) {
  return ProviderScope(
    overrides: [
      meetingCaptureCapabilityProvider.overrideWith(
        (ref) async => meetingCapability,
      ),
      ...overrides,
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'payload.sh', path: '/tmp/payload.sh', size: 1),
  ]);
}

class _UnsafeInboxUploader extends InboxUploader {
  _UnsafeInboxUploader(super.ref);

  @override
  Future<String> upload(
    PickedUpload picked, {
    int durationSeconds = 0,
    bool importFromExternalSource = false,
  }) async {
    throw const UnsafeDocumentTypeException('payload.sh');
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('flag ON — mobile dock', () {
    testWidgets('renders the MatomeBottomDock + MatomeAddFab, not the legacy '
        'BottomAppBar/mic FAB', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      expect(find.byType(MatomeBottomDock), findsOneWidget);
      expect(find.byType(MatomeAddFab), findsOneWidget);
      // Legacy chrome is gone.
      expect(find.byType(BottomAppBar), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('destinations appear in the DR-002 order; satori absent', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      final dock = find.byType(MatomeBottomDock);
      // Inbox is active → its icon is the SELECTED glyph; the rest inactive.
      for (final tab in _onBranches) {
        final glyph = tab == ShellTab.inbox ? tab.selectedIcon : tab.icon;
        expect(
          find.descendant(of: dock, matching: find.byIcon(glyph)),
          findsOneWidget,
          reason: '${tab.name} glyph present in the dock',
        );
      }
      // Satori is neither a destination nor reachable.
      expect(
        find.descendant(of: dock, matching: find.byIcon(ShellTab.satori.icon)),
        findsNothing,
      );
    });

    testWidgets(
      'tapping a dock destination switches the StatefulShell branch',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app(_buildOnRouter()));
        await tester.pumpAndSettle();

        expect(find.text('SCREEN:/inbox'), findsOneWidget);

        // Tap the Calendar destination (inactive → outline glyph).
        await tester.tap(find.byIcon(ShellTab.calendar.icon));
        await tester.pumpAndSettle();
        expect(find.text('SCREEN:/calendar'), findsOneWidget);

        // Tap Files (the route promoted from a root deep-link to a branch).
        await tester.tap(find.byIcon(ShellTab.files.icon));
        await tester.pumpAndSettle();
        expect(find.text('SCREEN:/files'), findsOneWidget);
      },
    );

    testWidgets('Add FAB opens the available flows (Add file gated off)', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      // Closed: options not mounted.
      expect(find.text(t.nav.recordAudio), findsNothing);

      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();

      // The non-gated options are present; "Add file" (document import) is
      // hidden because ff.documents defaults off (#1449) — consistent with the
      // matome detail picker.
      expect(find.text(t.nav.recordAudio), findsOneWidget);
      expect(find.text(t.nav.addPhoto), findsOneWidget);
      expect(find.text(t.nav.addFile), findsNothing);
      expect(find.text(t.nav.recordMeeting), findsOneWidget);
    });

    testWidgets('Add → Record audio pushes the /recording modal', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.nav.recordAudio));
      await tester.pumpAndSettle();

      expect(find.text('SCREEN:recording'), findsOneWidget);
    });

    testWidgets('Add → Record meeting pushes the /meeting modal', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.nav.recordMeeting));
      await tester.pumpAndSettle();

      expect(find.text('SCREEN:meeting'), findsOneWidget);
    });

    testWidgets('unsupported meeting capture never pushes the route', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          _buildOnRouter(),
          meetingCapability: const MeetingCaptureCapability.unsupported(
            backendId: 'test',
            reason: 'ffmpeg-required',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.nav.recordMeeting));
      await tester.pumpAndSettle();

      expect(find.text('SCREEN:meeting'), findsNothing);
      expect(find.text(t.meetingRecording.ffmpegRequired), findsOneWidget);
    });

    testWidgets('unsafe picker upload is awaited and surfaces an error', (
      tester,
    ) async {
      _phone(tester);
      FilePicker.platform = _FakeFilePicker();
      addTearDown(() => FilePicker.platform = _FakeFilePicker());
      const exception = UnsafeDocumentTypeException('payload.sh');
      await tester.pumpWidget(
        _app(
          _buildOnRouter(),
          overrides: [
            inboxUploaderProvider.overrideWith(_UnsafeInboxUploader.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.nav.addPhoto));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(t.matome.addFileFailed(error: '$exception')),
        findsOneWidget,
      );
    });

    testWidgets('dock Settings affordance routes to /inbox/settings', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      // The persistent account/profile affordance keeps Settings reachable from
      // every mobile screen (the desktop sidebar already has its own Settings
      // tile). Tap it and assert it lands on the inbox-stack settings route.
      final settings = find.byKey(const ValueKey('nav-dock-settings'));
      expect(settings, findsOneWidget);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:settings'), findsOneWidget);
    });
  });

  group('flag ON — desktop sidebar', () {
    testWidgets('renders MatomeSidebar, not the NavigationRail', (
      tester,
    ) async {
      _desktop(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      expect(find.byType(MatomeSidebar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BottomAppBar), findsNothing);
    });

    testWidgets('tapping a sidebar destination switches the branch', (
      tester,
    ) async {
      _desktop(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      expect(find.text('SCREEN:/inbox'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(MatomeSidebar),
          matching: find.text(t.contacts.title),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:/contacts'), findsOneWidget);
    });

    testWidgets('sidebar Settings routes to /inbox/settings', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(MatomeSidebar),
          matching: find.text(t.settings.title),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:settings'), findsOneWidget);
    });

    testWidgets('sidebar Add opens the available flows (Add file gated off)', (
      tester,
    ) async {
      _desktop(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      // The expanded "Add" button label is in the sidebar; tap it to open.
      await tester.tap(
        find.descendant(
          of: find.byType(MatomeSidebar),
          matching: find.byIcon(Icons.add),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(t.nav.recordAudio), findsOneWidget);
      expect(find.text(t.nav.addPhoto), findsOneWidget);
      // "Add file" hidden — ff.documents defaults off (#1449).
      expect(find.text(t.nav.addFile), findsNothing);
      expect(find.text(t.nav.recordMeeting), findsOneWidget);
    });
  });

  group('flag ON — satori route is gated off (unreachable)', () {
    testWidgets('navigating to /satori throws (no such route)', (tester) async {
      _phone(tester);
      final router = _buildOnRouter();
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      // The new shell drops the satori BRANCH; /satori is not registered, so a
      // go() finds no match. go_router surfaces this as an error screen rather
      // than navigating to a satori screen — assert no satori screen mounts.
      router.go('/satori');
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:/satori'), findsNothing);
    });
  });

  group('flag ON — a11y acceptance (explicit, not goldens)', () {
    testWidgets('every dock destination exposes a button Semantics with its '
        'localized label and a ≥48dp tap target', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();

      for (final tab in _onBranches) {
        // A button-semantics node labelled with the destination's title exists.
        expect(
          find.bySemanticsLabel(tab.label),
          findsWidgets,
          reason: '${tab.name} has a screen-reader label',
        );
      }

      // Tap targets: each dock destination's tappable region is ≥48dp on both
      // axes (WCAG 2.5.5). The dock items wrap an InkWell in a min-size box.
      final inkwells = find.descendant(
        of: find.byType(MatomeBottomDock),
        matching: find.byType(InkWell),
      );
      for (final element in inkwells.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      handle.dispose();
    });

    testWidgets('the Add FAB exposes a button Semantics with the add label', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(t.nav.add), findsWidgets);
      handle.dispose();
    });

    testWidgets('keyboard traversal reaches a destination and activates it', (
      tester,
    ) async {
      _desktop(tester);
      await tester.pumpWidget(_app(_buildOnRouter()));
      await tester.pumpAndSettle();

      // The sidebar destinations are real focusable controls (InkWell on a
      // Focus node), so they are keyboard-operable, not pointer-only. Drive the
      // Calendar destination by FOCUS + Enter (the ActivateIntent the framework
      // binds to Enter/Space) and assert the branch switched — proving keyboard
      // traversal can both REACH and ACTIVATE a destination.
      // Walk the focus traversal with nextFocus() until the primary focus lands
      // inside the sidebar (proving the destinations ARE in the keyboard
      // traversal order), then activate it with Enter and assert a branch
      // switched (proving keyboard ACTIVATION, not just reachability).
      bool focusInSidebar() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        var inside = false;
        ctx.visitAncestorElements((e) {
          if (e.widget is MatomeSidebar) {
            inside = true;
            return false;
          }
          return true;
        });
        return inside;
      }

      // Seed traversal: focus the root scope so nextFocus() has a starting node.
      final rootScope = FocusScope.of(
        tester.element(find.byType(MatomeSidebar)),
      );
      rootScope.requestFocus();
      await tester.pumpAndSettle();

      var reached = false;
      for (var i = 0; i < 30 && !reached; i++) {
        final moved = rootScope.nextFocus();
        await tester.pumpAndSettle();
        reached = focusInSidebar();
        if (!moved && !reached) break;
      }
      expect(
        reached,
        isTrue,
        reason: 'keyboard traversal reaches a sidebar control',
      );

      // Keep activating focused sidebar controls with Enter until a branch (or
      // settings) switches — any focused destination/Settings activating proves
      // keyboard operability.
      var activated = false;
      for (var i = 0; i < 30 && !activated; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        activated =
            find.text('SCREEN:/calendar').evaluate().isNotEmpty ||
            find.text('SCREEN:/files').evaluate().isNotEmpty ||
            find.text('SCREEN:/contacts').evaluate().isNotEmpty ||
            find.text('SCREEN:/spaces').evaluate().isNotEmpty ||
            find.text('SCREEN:settings').evaluate().isNotEmpty;
        if (!activated && focusInSidebar()) {
          FocusManager.instance.primaryFocus?.nextFocus();
          await tester.pumpAndSettle();
        }
      }
      expect(
        activated,
        isTrue,
        reason: 'Enter on a focused sidebar control activates it',
      );
    });
  });
}
