import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/vault/media_inputs.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Inbox and Matome placement share Vault ingest and persist blob_id',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = _Store();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('owner'),
          mediaBlobStoreProvider.overrideWithValue(store),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      addTearDown(container.dispose);
      final uploader = container.read(inboxUploaderProvider);

      final looseId = await uploader.persist(
        PickedUpload(
          input: _BytesInput('voice.m4a', [1, 2, 3]),
          title: 'Voice',
          mediaType: 'audio',
        ),
      );
      final matomeId = await uploader.persist(
        PickedUpload(
          input: _BytesInput('photo.png', [4, 5, 6]),
          title: 'Photo',
          mediaType: 'image',
        ),
        matomeId: 'matome-local',
      );

      final loose = await db.itemsDao.getById(looseId, 'owner');
      final placed = await db.itemsDao.getById(matomeId, 'owner');
      expect(loose?.blobId, isNotNull);
      expect(loose?.matomeId, isNot('matome-local'));
      expect(placed?.blobId, isNotNull);
      expect(placed?.matomeId, 'matome-local');
      expect(store.ingests, 2);
    },
  );

  test('picker input reads bytes when Web path is null', () async {
    final input = mediaInputFromPlatformFile(
      PlatformFile(
        name: 'web.pdf',
        size: 4,
        bytes: Uint8List.fromList([7, 8, 9, 10]),
      ),
    );

    expect(await input.openRead().expand((chunk) => chunk).toList(), [
      7,
      8,
      9,
      10,
    ]);
  });
}

final class _BytesInput implements MediaInput {
  _BytesInput(this.filename, List<int> bytes)
    : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  @override
  final String filename;
  @override
  String? get contentType => null;
  @override
  int? get knownLength => _bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.value(_bytes);
}

final class _Store implements MediaBlobStore {
  int ingests = 0;
  final Map<VaultBlobId, VaultBlobStat> _blobs = {};

  @override
  VaultAccountId get accountId => VaultAccountId('owner');

  @override
  Future<VaultBlobStat> ingest(MediaInput input) async {
    ingests++;
    final bytes = await input.openRead().expand((chunk) => chunk).toList();
    final stat = VaultBlobStat(
      id: VaultBlobId('blob-$ingests'),
      state: VaultBlobState.ready,
      plaintextLength: bytes.length,
      physicalLength: bytes.length + 64,
      plaintextSha256: sha256.convert(bytes).toString(),
    );
    _blobs[stat.id] = stat;
    return stat;
  }

  @override
  Future<void> delete(VaultBlobId id) async => _blobs.remove(id);
  @override
  Future<void> prepareDelete(VaultBlobId id) async {}
  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) =>
      throw UnimplementedError();
  @override
  Future<void> close() async {}
  @override
  Future<VaultReconciliationReport> reconcile() async =>
      VaultReconciliationReport(const []);
  @override
  Future<List<VaultJournalEntry>> journal() async => const [];
  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => _blobs.keys.toSet();
  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async => _blobs[id]!;
  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  }) => throw UnimplementedError();
  @override
  Future<VaultPlaintextLease> createLease(
    VaultBlobId id, {
    required VaultLeasePurpose purpose,
    required Duration ttl,
  }) => throw UnimplementedError();
}
