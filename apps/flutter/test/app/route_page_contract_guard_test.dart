import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _contractPath = '../../.docs/internal/design-system-route-contract.md';
const _routerPath = 'lib/app/router.dart';
const _widgetbookPath = '../flutter_widgetbook/lib/widgetbook.dart';
const _widgetbookGeneratedPath =
    '../flutter_widgetbook/lib/widgetbook.directories.g.dart';

/// Routes still allowed to miss canonical Page + Widgetbook `[Pages]` coverage.
///
/// W1 installs the guard before W2 creates the first Pages. Later migration waves
/// remove entries from this map as each route becomes covered.
const _pendingRoutePageMigrations = <String, String>{};

const _routerPathLiterals = <String>{
  '/',
  '/login',
  '/signup',
  '/recording',
  '/matome/:id',
  '/files',
  '/recording/detail/:id',
  '/recording/image/:id',
  '/recording/document/:id',
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
  '/signup': ["path: '/signup'", 'SignupPage()'],
  '/recording': ["path: '/recording'", 'RecordingPage()'],
  '/meeting': ["path: '/meeting'", 'MeetingRecordingPage()'],
  '/matome/:id': ["path: '/matome/:id'", 'MatomeDetailPage('],
  '/files': ["path: '/files'", 'FilesPage()'],
  '/recording/detail/:id': [
    "path: '/recording/detail/:id'",
    'FileDetailPage.audio',
  ],
  '/recording/image/:id': [
    "path: '/recording/image/:id'",
    'FileDetailPage.image',
  ],
  '/recording/document/:id': [
    "path: '/recording/document/:id'",
    'FileDetailPage.document',
  ],
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
          coverage: const WidgetbookPageCoverage(
            annotationSource: '',
            generatedSource: '',
          ),
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
            annotationSource:
                '@widgetbook.UseCase(type: DemoPage, path: \'[Screens]/Demo\')',
            generatedSource:
                "_widgetbook.WidgetbookComponent(name: 'DemoPage')",
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

WidgetbookPageCoverage readWidgetbookPageCoverage() {
  final widgetbookSource = File(_widgetbookPath);
  final generatedSource = File(_widgetbookGeneratedPath);
  if (!widgetbookSource.existsSync() || !generatedSource.existsSync()) {
    fail('Widgetbook sources are missing; Page coverage cannot run.');
  }

  return WidgetbookPageCoverage(
    annotationSource: widgetbookSource.readAsStringSync(),
    generatedSource: generatedSource.readAsStringSync(),
  );
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
  const WidgetbookPageCoverage({
    required this.annotationSource,
    required this.generatedSource,
  });

  final String annotationSource;
  final String generatedSource;

  bool hasPagesCoverage(String className) {
    final escapedClassName = RegExp.escape(className);
    final useCasePattern = RegExp(
      r'@widgetbook\.UseCase\(([\s\S]*?)\)\s*Widget',
      multiLine: true,
    );
    final typePattern = RegExp('type:\\s*$escapedClassName\\b');
    final pagesPathPattern = RegExp(r'''path:\s*['"]\[Pages\]''');
    final annotation = useCasePattern.allMatches(annotationSource).any((match) {
      final args = match.group(1)!;
      return typePattern.hasMatch(args) && pagesPathPattern.hasMatch(args);
    });
    final generated = RegExp(
      "name:\\s*'$escapedClassName'",
      multiLine: true,
    ).hasMatch(generatedSource);

    return annotation && generated;
  }
}
