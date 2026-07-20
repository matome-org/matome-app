import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _contractPath = '../../.docs/internal/design-system-route-contract.md';
const _routerPath = 'lib/app/router.dart';
const _widgetbookPath = '../flutter_widgetbook/lib/widgetbook.dart';
const _pagesDir = 'lib/app/pages';

/// Routes still allowed to miss canonical Page + Widgetbook `[Pages]` coverage.
///
/// W1 installs the guard before W2 creates the first Pages. Later migration waves
/// remove entries from this map as each route becomes covered.
const _pendingRoutePageMigrations = <String, String>{};

const _routerPathLiterals = <String>{
  '/',
  '/login',
  '/unlock',
  '/signup',
  '/forgot-password',
  '/reset-password',
  '/recording',
  '/matome/:id',
  '/files',
  '/items/audio/:id',
  '/items/image/:id',
  '/items/document/:id',
  '/items/video/:id',
  '/items/text/:id',
  '/meeting',
  '/inbox',
  'settings',
  ':id',
  '/calendar',
  '/spaces',
  'recording/:id',
  ':spaceId',
  '/satori',
  '/contacts',
};

const _routerEvidence = <String, List<String>>{
  '/': ["path: '/'", 'WelcomePage()'],
  '/login': ["path: '/login'", 'LoginPage()'],
  '/unlock': ["path: '/unlock'", 'UnlockPage()'],
  '/signup': ["path: '/signup'", 'SignupPage()'],
  '/forgot-password': ["path: '/forgot-password'", 'ForgotPasswordPage()'],
  '/reset-password': ["path: '/reset-password'", 'ResetPasswordPage('],
  '/recording': ["path: '/recording'", 'RecordingPage()'],
  '/meeting': ["path: '/meeting'", 'MeetingRecordingPage()'],
  '/matome/:id': ["path: '/matome/:id'", 'MatomeDetailPage('],
  '/files': ["path: '/files'", 'FilesPage()'],
  '/items/audio/:id': ["path: '/items/audio/:id'", 'FileDetailPage.audio'],
  '/items/image/:id': ["path: '/items/image/:id'", 'FileDetailPage.image'],
  '/items/document/:id': [
    "path: '/items/document/:id'",
    'FileDetailPage.document',
  ],
  '/items/video/:id': ["path: '/items/video/:id'", 'FileDetailPage.video'],
  '/items/text/:id': ["path: '/items/text/:id'", 'TextItemPage('],
  '/inbox': ["path: '/inbox'", 'InboxPage()'],
  '/inbox/settings': ["path: '/inbox'", "path: 'settings'", 'SettingsPage()'],
  '/inbox/:id': ["path: '/inbox'", "path: ':id'", 'RecordingDetailScreen('],
  '/calendar': ["path: '/calendar'", 'CalendarPage()'],
  '/calendar/:id': [
    "path: '/calendar'",
    "path: ':id'",
    'RecordingDetailScreen(',
  ],
  '/spaces': ["path: '/spaces'", 'SpacesPage()'],
  '/spaces/recording/:id': [
    "path: '/spaces'",
    "path: 'recording/:id'",
    'SpaceRecordingScreen(',
  ],
  '/spaces/:spaceId': [
    "path: '/spaces'",
    "path: ':spaceId'",
    'SpaceDetailPage(',
  ],
  '/satori': ["path: '/satori'", 'SatoriScreen()'],
  '/contacts': ["path: '/contacts'", 'ContactsPage()'],
  '/contacts/:id': ["path: '/contacts'", "path: ':id'", 'ContactDetailPage('],
};

void main() {
  group('route/Page contract guard', () {
    test(
      'negative self-test: non-pending required route needs a Page class',
      () {
        final failures = routePageParityFailures(
          rows: const [
            RouteContractRow(
              route: '/demo',
              status: 'Required',
              target: 'DemoPage',
            ),
          ],
          routerSource:
              "GoRoute(path: '/demo', builder: (_, _) => const DemoScreen())",
          appPageClasses: const {},
          coverage: const WidgetbookPageCoverage(source: ''),
          pendingRoutes: const {},
        );

        expect(failures, hasLength(1));
        expect(failures.single, contains('/demo'));
        expect(failures.single, contains('DemoPage'));
      },
    );

    test(
      'negative self-test: covered Page needs Widgetbook [Pages] coverage',
      () {
        final failures = routePageParityFailures(
          rows: const [
            RouteContractRow(
              route: '/demo',
              status: 'Required',
              target: 'DemoPage',
            ),
          ],
          routerSource:
              "GoRoute(path: '/demo', builder: (_, _) => const DemoPage())",
          appPageClasses: const {'DemoPage'},
          coverage: const WidgetbookPageCoverage(
            source:
                "_component(name: 'DemoPage', path: 'Screens/Demo', docs: 'Docs', stories: [])",
          ),
          pendingRoutes: const {},
        );

        expect(failures, hasLength(1));
        expect(failures.single, contains('Widgetbook [Pages]'));
      },
    );

    test('route inventory stays aligned with router.dart', () {
      final rows = readRouteContractRows();
      final routerSource = File(_routerPath).readAsStringSync();

      final rowRoutes = rows.map((row) => row.route).toSet();
      expect(rowRoutes, _routerEvidence.keys.toSet());

      final invalidStatuses = rows
          .where(
            (row) => !{'Required', 'Deferred', 'Exempt'}.contains(row.status),
          )
          .toList();
      expect(
        invalidStatuses,
        isEmpty,
        reason: 'Route contract rows must use Required, Deferred, or Exempt.',
      );

      final missingEvidence = <String>[];
      for (final entry in _routerEvidence.entries) {
        for (final snippet in entry.value) {
          if (!routerSource.contains(snippet)) {
            missingEvidence.add('${entry.key}: `$snippet`');
          }
        }
      }
      expect(
        missingEvidence,
        isEmpty,
        reason: 'Route inventory evidence missing from router.dart.',
      );

      final literals = RegExp(
        r"path:\s*'([^']+)'",
      ).allMatches(routerSource).map((match) => match.group(1)!).toSet();
      expect(
        literals,
        _routerPathLiterals,
        reason:
            'router.dart path literals changed. Update '
            '.docs/internal/design-system-route-contract.md and this guard.',
      );

      final pendingProblems = pendingRouteMigrationProblems(rows);
      expect(pendingProblems, isEmpty, reason: pendingProblems.join('\n'));
    });

    test(
      'canonical route Pages have Widgetbook [Pages] coverage or pending debt',
      () {
        final rows = readRouteContractRows();
        final failures = routePageParityFailures(
          rows: rows,
          routerSource: File(_routerPath).readAsStringSync(),
          appPageClasses: discoverAppPageClasses(),
          coverage: readWidgetbookPageCoverage(),
          pendingRoutes: _pendingRoutePageMigrations,
        );

        expect(
          failures,
          isEmpty,
          reason: [
            'Route/Page drift guard failed.',
            'For each Required route, either keep a reviewed pending entry in '
                '_pendingRoutePageMigrations or migrate the route to the target '
                'app Page and add Widgetbook `[Pages]` coverage.',
            ...failures,
          ].join('\n'),
        );
      },
    );

    test(
      'Pages depend only on Frames and Screens (no lower-layer imports)',
      () {
        final dir = Directory(_pagesDir);
        expect(
          dir.existsSync(),
          isTrue,
          reason: 'expected $_pagesDir to exist',
        );
        final sources = <String, String>{};
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          sources[entity.path] = entity.readAsStringSync();
        }

        final violations = pageLatticeViolations(sources);
        expect(
          violations,
          isEmpty,
          reason: [
            'Page lattice guard failed. Pages may depend only on Frames and '
                'Screens; reach components (lib/ui) and foundations '
                '(lib/core/theme) through a Screen or Frame, never directly.',
            ...violations,
          ].join('\n'),
        );
      },
    );

    test('negative self-test: a Page importing lower layers is flagged', () {
      final violations = pageLatticeViolations({
        'lib/app/pages/demo_page.dart':
            "import 'package:matome_flutter/ui/app_button.dart';\n"
            "import '../../ui/avatar.dart';\n"
            "import 'package:matome_flutter/core/theme/app_theme.dart';",
      });
      expect(violations, hasLength(3));
    });
  });
}

List<RouteContractRow> readRouteContractRows() {
  final source = File(_contractPath).readAsStringSync();
  final rows = <RouteContractRow>[];

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('| `')) continue;
    final cells = trimmed
        .split('|')
        .skip(1)
        .take(5)
        .map((cell) => cell.trim())
        .toList();
    if (cells.length != 5) continue;
    rows.add(
      RouteContractRow(
        route: _stripBackticks(cells[0]),
        status: cells[2],
        target: cells[3],
      ),
    );
  }

  return rows;
}

Set<String> discoverAppPageClasses() {
  final classes = <String>{};
  final libDir = Directory('lib');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in RegExp(
      r'class\s+([A-Z][A-Za-z0-9_]*Page)(?:<[^>]+>)?\s+extends\s+'
      r'(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget)\b',
    ).allMatches(source)) {
      classes.add(match.group(1)!);
    }
  }
  return classes;
}

/// Layers a Page module must not import directly. Pages compose Screens inside
/// Frames; they reach components (`lib/ui`) and foundations (`lib/core/theme`)
/// only through those, matching the dependency lattice in the route contract.
/// Matches both `package:matome_flutter/<layer>/` and relative `../ui/` forms.
final _forbiddenPageImportLayers = <String, RegExp>{
  'components (lib/ui)': RegExp(
    r'''import\s+['"](?:package:matome_flutter/|(?:\.\./)+)ui/''',
  ),
  'foundations (lib/core/theme)': RegExp(
    r'''import\s+['"](?:package:matome_flutter/|(?:\.\./)+)core/theme/''',
  ),
};

/// Pure scanner: returns one violation per Page source line that imports a
/// forbidden lower layer directly.
List<String> pageLatticeViolations(Map<String, String> sourcesByPath) {
  final violations = <String>[];
  final paths = sourcesByPath.keys.toList()..sort();
  for (final path in paths) {
    if (path.endsWith('.g.dart')) continue;
    for (final line in sourcesByPath[path]!.split('\n')) {
      for (final entry in _forbiddenPageImportLayers.entries) {
        if (entry.value.hasMatch(line)) {
          violations.add(
            '$path: Page imports ${entry.key} directly: `${line.trim()}`. '
            'Pages may depend only on Frames and Screens; reach lower layers '
            'through a Screen or Frame.',
          );
        }
      }
    }
  }
  return violations;
}

WidgetbookPageCoverage readWidgetbookPageCoverage() {
  final widgetbookSource = File(_widgetbookPath);
  if (!widgetbookSource.existsSync()) {
    fail('Widgetbook sources are missing; Page coverage cannot run.');
  }

  return WidgetbookPageCoverage(source: widgetbookSource.readAsStringSync());
}

List<String> routePageParityFailures({
  required List<RouteContractRow> rows,
  required String routerSource,
  required Set<String> appPageClasses,
  required WidgetbookPageCoverage coverage,
  required Map<String, String> pendingRoutes,
}) {
  final failures = <String>[];
  final targetPageClasses = <String>{
    for (final row in rows) ...row.targetPageAlternatives,
  };

  final untrackedPages = appPageClasses.difference(targetPageClasses);
  if (untrackedPages.isNotEmpty) {
    failures.add(
      'App Page classes are not listed in the route contract: '
      '${untrackedPages.toList()..sort()}. Add rows or document an exemption.',
    );
  }

  for (final row in rows.where((row) => row.status == 'Required')) {
    if (pendingRoutes.containsKey(row.route)) continue;
    final alternatives = row.targetPageAlternatives;
    if (alternatives.isEmpty) {
      failures.add(
        '${row.route}: Required route has no target *Page in contract.',
      );
      continue;
    }

    final implemented = alternatives.where(appPageClasses.contains).toList();
    if (implemented.isEmpty) {
      failures.add(
        '${row.route}: target Page missing. Expected one of '
        '${alternatives.join(', ')} or add a reviewed pending migration.',
      );
      continue;
    }

    final routed = implemented.where(routerSource.contains).toList();
    if (routed.isEmpty) {
      failures.add(
        '${row.route}: router.dart does not reference implemented Page '
        '${implemented.join(', ')}.',
      );
    }

    final covered = implemented.where(coverage.hasPagesCoverage).toList();
    if (covered.isEmpty) {
      failures.add(
        '${row.route}: implemented Page ${implemented.join(', ')} lacks '
        'Widgetbook [Pages] coverage.',
      );
    }
  }

  return failures;
}

List<String> pendingRouteMigrationProblems(List<RouteContractRow> rows) {
  final byRoute = {for (final row in rows) row.route: row};
  final problems = <String>[];

  for (final entry in _pendingRoutePageMigrations.entries) {
    final row = byRoute[entry.key];
    if (row == null) {
      problems.add(
        '${entry.key}: pending migration is not in route inventory.',
      );
      continue;
    }
    if (row.status != 'Required') {
      problems.add(
        '${entry.key}: only Required rows may carry pending migration debt.',
      );
    }
    if (entry.value.trim().length < 16 || !entry.value.contains('#')) {
      problems.add(
        '${entry.key}: pending migration needs a task-linked reason.',
      );
    }
  }

  final requiredRoutes = rows
      .where((row) => row.status == 'Required')
      .map((row) => row.route)
      .toSet();
  final invalidPending = _pendingRoutePageMigrations.keys.toSet().difference(
    requiredRoutes,
  );
  for (final route in invalidPending) {
    problems.add('$route: pending migration points at a non-Required route.');
  }

  return problems;
}

String _stripBackticks(String value) {
  return value.replaceAll('`', '').trim();
}

class RouteContractRow {
  const RouteContractRow({
    required this.route,
    required this.status,
    required this.target,
  });

  final String route;
  final String status;
  final String target;

  List<String> get targetPageAlternatives {
    return target
        .split(RegExp(r'\s+or\s+'))
        .map(
          (part) => RegExp(
            r'\b([A-Z][A-Za-z0-9_]*Page)\b',
          ).firstMatch(part)?.group(1),
        )
        .whereType<String>()
        .toList();
  }

  @override
  String toString() => '$route -> $status -> $target';
}

class WidgetbookPageCoverage {
  const WidgetbookPageCoverage({required this.source});

  final String source;

  bool hasPagesCoverage(String className) {
    final escapedClassName = RegExp.escape(className);
    return _componentBlocks(source).any((block) {
      return RegExp("name:\\s*'$escapedClassName'").hasMatch(block) &&
          RegExp(r"path:\s*'Pages/").hasMatch(block);
    });
  }

  static List<String> _componentBlocks(String source) {
    final lines = source.split('\n');
    final blocks = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('  _component(')) continue;
      final buffer = StringBuffer(lines[i]);
      i++;
      while (i < lines.length && !lines[i].startsWith('  ),')) {
        buffer.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) buffer.writeln(lines[i]);
      blocks.add(buffer.toString());
    }
    return blocks;
  }
}
