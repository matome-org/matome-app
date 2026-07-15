import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';

/// The Matome sync pill ([MatomeItem.syncRollup]) must agree with the per-tile
/// "Cloud"/"On device" badges of its children — the field bug where a Matome
/// read "On device" while a child read "Cloud". The rollup is derived from the
/// SAME [RecordingItem.isOnCloud] rule the tiles use.
RecordingItem _rec({int? coreId, String status = 'done'}) => RecordingItem(
  id: 'r',
  title: 't',
  timestamp: '',
  duration: '',
  badge: 'Inbox',
  isProcessing: false,
  mediaType: 'audio',
  processingStatus: status,
  coreId: coreId,
);

MatomeItem _matome({int? coreId, List<RecordingItem> recordings = const []}) =>
    MatomeItem(
      id: 'm',
      spaceId: null,
      title: 'M',
      happenedAt: 0,
      createdAt: 0,
      summaryStale: false,
      recordingCount: recordings.length,
      recordings: recordings,
      coreId: coreId,
    );

void main() {
  group('RecordingItem.isOnCloud', () {
    test('reconciled + done → on cloud', () {
      expect(_rec(coreId: 5).isOnCloud, isTrue);
    });

    test('no coreId → not on cloud', () {
      expect(_rec().isOnCloud, isFalse);
    });

    test('coreId set but still uploading/failed → NOT on cloud', () {
      expect(_rec(coreId: 5, status: 'pending_upload').isOnCloud, isFalse);
      expect(_rec(coreId: 5, status: 'failed').isOnCloud, isFalse);
      expect(
        _rec(coreId: 5, status: kProcessingStatusBlockedOffline).isOnCloud,
        isFalse,
      );
    });
  });

  group('MatomeItem.syncRollup', () {
    test('no children → falls back to the Matome coreId', () {
      expect(_matome().syncRollup, MatomeSyncRollup.onDevice);
      expect(_matome(coreId: 9).syncRollup, MatomeSyncRollup.cloud);
    });

    test('every child on cloud → cloud (matches all-Cloud tiles)', () {
      final m = _matome(recordings: [_rec(coreId: 1), _rec(coreId: 2)]);
      expect(m.syncRollup, MatomeSyncRollup.cloud);
    });

    test('no child on cloud → on device', () {
      final m = _matome(recordings: [_rec(), _rec()]);
      expect(m.syncRollup, MatomeSyncRollup.onDevice);
    });

    test('a mix still uploading → partial (never claims fully synced)', () {
      final m = _matome(recordings: [_rec(coreId: 1), _rec()]);
      expect(m.syncRollup, MatomeSyncRollup.partial);
    });

    test('child reconciled but pending counts as not-yet-cloud', () {
      final m = _matome(
        recordings: [
          _rec(coreId: 1),
          _rec(coreId: 2, status: 'pending_upload'),
        ],
      );
      expect(m.syncRollup, MatomeSyncRollup.partial);
    });
  });
}
