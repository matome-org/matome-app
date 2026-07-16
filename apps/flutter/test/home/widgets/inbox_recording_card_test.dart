import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/recordings/processing_error.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_card.dart';

/// W5 (plan #43): the Inbox card must render each of the four local-first
/// lifecycle states clearly, and the `failed` card must expose a MANUAL retry
/// affordance that re-enqueues through the upload queue (alongside auto-retry).
void main() {
  RecordingItem card({
    required String id,
    required String processingStatus,
    bool isProcessing = false,
    String? summary,
    int? coreId,
    String? processingErrorCode,
  }) {
    return RecordingItem(
      id: id,
      title: 'Stand-up',
      summary: summary,
      timestamp: '1:00 PM',
      duration: '34s',
      badge: 'Inbox',
      isProcessing: isProcessing,
      mediaType: 'audio',
      processingStatus: processingStatus,
      coreId: coreId,
      processingErrorCode: processingErrorCode,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    RecordingItem c, {
    VoidCallback? onRetry,
  }) async {
    // Pin the locale so the English copy assertions are deterministic.
    LocaleSettings.setLocaleSync(AppLocale.en);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: AppCard.recording(
            card: c,
            relativeTime: '3h',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }

  testWidgets('pending_upload renders SAFE-but-not-uploaded (no spinner)', (
    tester,
  ) async {
    await pump(
      tester,
      card(
        id: mintLocalRecordingId(),
        processingStatus: kProcessingStatusPendingUpload,
        isProcessing:
            true, // legacy flag is set but status wins → not a spinner
      ),
    );

    expect(find.byKey(const ValueKey('card-pending-upload')), findsOneWidget);
    expect(find.text('Saved on device · waiting to upload'), findsOneWidget);
    // SAFE-but-not-uploaded must NOT read as "in progress": no spinner anywhere.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // No failure affordance on a healthy, just-saved row.
    expect(find.byKey(const ValueKey('card-retry')), findsNothing);
  });

  testWidgets('durable queue block reasons still render as waiting on-device', (
    tester,
  ) async {
    for (final status in const [
      kProcessingStatusBlockedSignedOut,
      kProcessingStatusBlockedOffline,
      kProcessingStatusBlockedLocalSpace,
      kProcessingStatusBlockedParent,
      kProcessingStatusBlockedCore,
    ]) {
      await pump(
        tester,
        card(id: mintLocalRecordingId(), processingStatus: status),
      );
      expect(
        find.byKey(const ValueKey('card-pending-upload')),
        findsOneWidget,
        reason: status,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
  });

  testWidgets('processing renders a transcribing spinner', (tester) async {
    await pump(
      tester,
      card(id: '42', processingStatus: 'processing', isProcessing: true),
    );

    expect(find.byKey(const ValueKey('card-processing')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byKey(const ValueKey('card-pending-upload')), findsNothing);
  });

  testWidgets('done renders the summary, no status line', (tester) async {
    await pump(
      tester,
      card(id: '42', processingStatus: 'done', summary: 'Key decisions'),
    );

    expect(find.text('Key decisions'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-pending-upload')), findsNothing);
    expect(find.byKey(const ValueKey('card-processing')), findsNothing);
    expect(find.byKey(const ValueKey('card-failed')), findsNothing);
  });

  testWidgets('failed renders a failure line + a MANUAL retry button', (
    tester,
  ) async {
    var retried = false;
    await pump(
      tester,
      card(id: '42', processingStatus: 'failed'),
      onRetry: () => retried = true,
    );

    expect(find.byKey(const ValueKey('card-failed')), findsOneWidget);
    expect(find.text('Upload failed'), findsOneWidget);

    final retry = find.byKey(const ValueKey('card-retry'));
    expect(retry, findsOneWidget, reason: 'failed card offers manual retry');
    await tester.tap(retry);
    expect(retried, isTrue, reason: 'tapping retry fires the re-enqueue hook');
  });

  testWidgets('failed renders the bounded error message outside user notes', (
    tester,
  ) async {
    await pump(
      tester,
      card(
        id: '42',
        processingStatus: 'failed',
        processingErrorCode: kProcessingErrorTimeout,
      ),
    );

    expect(find.text('Processing timed out'), findsOneWidget);
    expect(find.text('Upload failed'), findsNothing);
  });

  testWidgets('failed without an onRetry hook hides the retry button', (
    tester,
  ) async {
    await pump(tester, card(id: '42', processingStatus: 'failed'));
    expect(find.byKey(const ValueKey('card-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-retry')), findsNothing);
  });

  // ── W2 (plan #45): sync-state badge — on-device vs cloud ──────────────────

  testWidgets('coreId null → on-device sync badge alongside the folder badge', (
    tester,
  ) async {
    await pump(
      tester,
      card(
        id: mintLocalRecordingId(),
        processingStatus: kProcessingStatusPendingUpload,
      ),
    );

    // Sync badge: on-device variant, with text (never colour alone).
    expect(find.byKey(const ValueKey('sync-badge-onDevice')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-badge-cloud')), findsNothing);
    expect(find.text('On device'), findsOneWidget);
    // The folder badge ("Inbox") still renders as a distinct PEER badge.
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets(
    'coreId set + done → cloud sync badge alongside the folder badge',
    (tester) async {
      await pump(tester, card(id: '42', processingStatus: 'done', coreId: 42));

      expect(find.byKey(const ValueKey('sync-badge-cloud')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-badge-onDevice')), findsNothing);
      // Normalized vocab (#1407): "Cloud" → "Synced".
      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
    },
  );

  testWidgets('AI failure keeps cloud sync truth independent', (
    tester,
  ) async {
    await pump(tester, card(id: '42', processingStatus: 'failed', coreId: 42));

    expect(find.byKey(const ValueKey('card-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-badge-cloud')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-badge-onDevice')), findsNothing);
  });

  testWidgets('sync badge is accessible — icon + text, not colour alone', (
    tester,
  ) async {
    await pump(tester, card(id: '42', processingStatus: 'done', coreId: 42));

    final badge = find.byKey(const ValueKey('sync-badge-cloud'));
    expect(badge, findsOneWidget);
    // Both a glyph and a text label live inside the pill.
    expect(
      find.descendant(of: badge, matching: find.byType(Icon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.text('Synced')),
      findsOneWidget,
    );
  });

  testWidgets('sync badge exposes a single screen-reader label (plan #45 W3)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, card(id: '42', processingStatus: 'done', coreId: 42));

    // The pill contributes a single "Sync state: Synced" announcement (the
    // inner icon+text are excluded so it isn't read twice). The card row merges
    // it into the row's button label, so match the combined node by substring.
    expect(find.bySemanticsLabel(RegExp('Sync state: Synced')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('calendar variant preserves the compact row key and tap action', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: AppCard.calendar(
            id: 'rec-calendar',
            title: 'Design review',
            badge: 'Work',
            statusLabel: 'Design Lab',
            durationLabel: '1:08',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    final row = find.byKey(const ValueKey('calendar-recording-rec-calendar'));
    expect(row, findsOneWidget);
    expect(find.text('Design Lab'), findsOneWidget);
    expect(find.text('1:08'), findsOneWidget);

    await tester.tap(row);
    expect(tapped, isTrue);
  });
}
