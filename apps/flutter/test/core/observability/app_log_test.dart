import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/observability/app_log.dart';

/// Unit coverage for the observability sink. The path_provider channel hangs
/// under `flutter test`, so behaviour (level routing, [AppLog.verbose] gating,
/// line shape) is asserted through the synchronous [AppLog.testSink] seam, and
/// the file/rotation path is exercised against a real temp dir via
/// [AppLog.writeLineTo].
void main() {
  group('AppLog routing + formatting', () {
    late List<String> captured;

    setUp(() {
      captured = <String>[];
      AppLog.verbose = true;
      AppLog.testSink = captured.add;
    });

    tearDown(() {
      AppLog.testSink = null;
      AppLog.verbose = true;
    });

    test('error() is always written and tagged [ERR]', () {
      AppLog.error(LogCat.sync, 'boom');
      expect(captured, hasLength(1));
      expect(captured.single, contains('[ERR] sync: boom'));
    });

    test('event() is written and tagged [INF] when verbose', () {
      AppLog.event(LogCat.action, 'tapped');
      expect(captured.single, contains('[INF] action: tapped'));
    });

    test('event() is suppressed when verbose is false', () {
      AppLog.verbose = false;
      AppLog.event(LogCat.action, 'tapped');
      expect(captured, isEmpty);
    });

    test('error() ignores verbose=false (always captured)', () {
      AppLog.verbose = false;
      AppLog.error(LogCat.upload, 'still logged');
      expect(captured.single, contains('[ERR] upload: still logged'));
    });

    test('error() appends the exception detail after an em dash', () {
      AppLog.error(LogCat.db, 'migrate failed', StateError('locked'));
      expect(
        captured.single,
        contains('[ERR] db: migrate failed — Bad state: locked'),
      );
    });

    test('error() appends the stack trace on its own line', () {
      AppLog.error(
        LogCat.error,
        'oops',
        Exception('x'),
        StackTrace.fromString('frame0\nframe1'),
      );
      expect(captured.single, contains('frame0\nframe1'));
    });

    test('every category name renders lowercase in the line', () {
      for (final cat in LogCat.values) {
        captured.clear();
        AppLog.error(cat, 'm');
        expect(captured.single, contains('${cat.name}: m'));
      }
    });

    test('formatLine carries an ISO-8601 timestamp prefix', () {
      final line = AppLog.formatLine('INF', LogCat.lifecycle, 'app start');
      // Leading token parses as a DateTime (ISO-8601).
      final stamp = line.split(' ').first;
      expect(DateTime.tryParse(stamp), isNotNull);
      expect(line, endsWith('[INF] lifecycle: app start'));
    });
  });

  group('AppLog.writeLineTo file + rotation', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('applog_test');
    });

    tearDown(() async {
      AppLog.maxBytes = 1024 * 1024;
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    File logFile() => File('${tmp.path}/Matome/app.log');

    test('creates the Matome/app.log file and appends a newline', () async {
      await AppLog.writeLineTo(tmp, 'first line');
      final f = logFile();
      expect(await f.exists(), isTrue);
      expect(await f.readAsString(), 'first line\n');
    });

    test('appends successive lines without truncating', () async {
      await AppLog.writeLineTo(tmp, 'a');
      await AppLog.writeLineTo(tmp, 'b');
      expect(await logFile().readAsString(), 'a\nb\n');
    });

    test('rotates to app.log.1 once the file exceeds maxBytes', () async {
      AppLog.maxBytes = 8; // tiny threshold so the next write trips rotation
      await AppLog.writeLineTo(tmp, 'aaaaaaaaaa'); // 11 bytes > 8
      // File now over threshold; the next write should rotate it aside first.
      await AppLog.writeLineTo(tmp, 'fresh');

      final rotated = File('${tmp.path}/Matome/app.log.1');
      expect(await rotated.exists(), isTrue);
      expect(await rotated.readAsString(), 'aaaaaaaaaa\n');
      expect(await logFile().readAsString(), 'fresh\n');
    });

    test('does not rotate while under maxBytes', () async {
      AppLog.maxBytes = 1024;
      await AppLog.writeLineTo(tmp, 'small');
      await AppLog.writeLineTo(tmp, 'also small');
      expect(await File('${tmp.path}/Matome/app.log.1').exists(), isFalse);
      expect(await logFile().readAsString(), 'small\nalso small\n');
    });
  });
}
