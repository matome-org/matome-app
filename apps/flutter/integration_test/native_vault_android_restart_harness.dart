import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:matome_flutter/core/vault/media_ingest_service.dart';
import 'package:matome_flutter/core/vault/vault_boot_coordinator.dart';
import 'package:matome_flutter/core/vault/vault_retention_service.dart';
import 'package:matome_vault/matome_vault.dart';
import 'package:path_provider/path_provider.dart';

const _enabled = bool.fromEnvironment('MATOME_NATIVE_VAULT_RESTART_GATE');
const _account = 'android-w5-account';
const _timeout = Duration(seconds: 90);

final _fixtures = <_Fixture>[
  _Fixture(
    kind: 'audio',
    filename: 'w5-audio-fixture.wav',
    contentType: 'audio/wav',
    bytes: utf8.encode('RIFF-WAVE-MATOME-W5-AUDIO-PLAINTEXT-2148-0123456789'),
  ),
  _Fixture(
    kind: 'image',
    filename: 'w5-image-fixture.png',
    contentType: 'image/png',
    bytes: <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      ...utf8.encode('MATOME-W5-IMAGE-PLAINTEXT-2148-abcdefghij'),
    ],
  ),
  _Fixture(
    kind: 'document',
    filename: 'w5-document-fixture.txt',
    contentType: 'text/plain',
    bytes: utf8.encode(
      'MATOME-W5-DOCUMENT-PLAINTEXT-2148-ABCDEFGHIJ-9876543210',
    ),
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_enabled) {
    runApp(const SizedBox.shrink());
    return;
  }

  final support = await getApplicationSupportDirectory();
  final evidenceDirectory = Directory('${support.path}/w5_android_restart');
  await evidenceDirectory.create(recursive: true);
  final evidence = File('${evidenceDirectory.path}/result.json');
  final stage = _Stage('read-evidence');

  try {
    await _run(support, evidence, stage).timeout(_timeout);
  } catch (error, stack) {
    await evidence.writeAsString(
      jsonEncode({
        'phase': 'failed',
        'status': 'error',
        'pid': pid,
        'stage': stage.value,
        'kind': error.runtimeType.toString(),
        'detail': error.toString(),
        'stack': stack.toString().split('\n').take(8).join('\n'),
      }),
      flush: true,
    );
  }
  runApp(const SizedBox.shrink());
}

Future<void> _run(Directory support, File evidence, _Stage stage) async {
  final previous = await _readEvidence(evidence);
  if (previous?['phase'] == 'write') {
    await _readPhase(support, evidence, previous!, stage);
  } else {
    await _writePhase(support, evidence, stage);
  }
}

Future<void> _writePhase(Directory support, File evidence, _Stage stage) async {
  final token = _randomToken();
  final coordinator = VaultBootCoordinator();
  final keys = _AndroidKeys(VaultAccountId(_account));
  try {
    stage.value = 'open-account-boot';
    await coordinator.open(keys);
    final stores = _readyStores(coordinator);
    final ingest = MediaIngestService(stores.blobs);
    final blobIds = <String>[];

    for (final fixture in _fixtures) {
      stage.value = 'ingest-${fixture.kind}';
      final stat = await ingest.ingestAndCommit(
        fixture,
        commit: (stat) => stores.database.transaction(() async {
          final now = DateTime.now().millisecondsSinceEpoch;
          final fileId = 'w5-file-${fixture.kind}';
          await stores.database.customStatement(
            'INSERT INTO file_blobs '
            '(id, filename, content_type, byte_size, checksum_sha256, '
            'media_type, blob_id, blob_state, cipher_format, cipher_version, '
            'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              fileId,
              fixture.filename,
              fixture.contentType,
              fixture.bytes.length,
              sha256.convert(fixture.bytes).toString(),
              fixture.kind,
              stat.id.value,
              stat.state.name,
              stat.cipherFormat.name,
              stat.cipherVersion,
              now,
              now,
            ],
          );
          await stores.database.customStatement(
            'INSERT INTO items '
            '(id, owner_id, client_id, item_type, title, file_blob_id, '
            'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'w5-item-${fixture.kind}',
              _account,
              'w5-client-${fixture.kind}',
              'file',
              fixture.kind,
              fileId,
              now,
              now,
            ],
          );
        }),
      );
      blobIds.add(stat.id.value);
    }

    stage.value = 'verify-write-state';
    await _verifyRowsAndVault(stores, blobIds);
    stage.value = 'exercise-plaintext-leases';
    for (var index = 0; index < _fixtures.length; index++) {
      final purpose = switch (_fixtures[index].kind) {
        'audio' => VaultLeasePurpose.playback,
        'image' => VaultLeasePurpose.preview,
        _ => VaultLeasePurpose.externalOpen,
      };
      final lease = await stores.blobs.createLease(
        VaultBlobId(blobIds[index]),
        purpose: purpose,
        ttl: const Duration(minutes: 5),
      );
      final plaintext = File.fromUri(lease.location);
      if (!_bytesEqual(await plaintext.readAsBytes(), _fixtures[index].bytes)) {
        throw StateError('${_fixtures[index].kind} lease plaintext mismatch');
      }
      if (_fixtures[index].kind != 'document') {
        await lease.dispose();
        if (await plaintext.exists()) {
          throw StateError('${_fixtures[index].kind} lease cleanup failed');
        }
      }
      // The document lease is deliberately abandoned. Force-stop simulates a
      // crash and the next account boot must sweep it before publishing ready.
    }
    final abandonedLeaseCount = await _plaintextLeaseCount(support);
    if (abandonedLeaseCount != 1) {
      throw StateError('expected one abandoned external-open lease');
    }
    final ciphertext = await _scanCiphertext(support, blobIds);
    await evidence.writeAsString(
      jsonEncode({
        'phase': 'write',
        'status': 'ok',
        'pid': pid,
        'account': _account,
        'sandboxToken': token,
        'supportRoot': support.path,
        'privateRoot': support.path.contains('/com.matome.matome_flutter/'),
        'blobIds': blobIds,
        'itemCount': 3,
        'ciphertextFiles': ciphertext,
        'abandonedLeaseCount': abandonedLeaseCount,
      }),
      flush: true,
    );
    // Deliberately do not close. The host force-stops this process to prove the
    // same on-disk account state reopens without graceful shutdown.
  } catch (_) {
    await coordinator.close();
    await keys.dispose();
    rethrow;
  }
}

Future<void> _readPhase(
  Directory support,
  File evidence,
  Map<String, Object?> previous,
  _Stage stage,
) async {
  final writerPid = previous['pid']! as int;
  if (writerPid == pid) throw StateError('process was not restarted');
  if (previous['account'] != _account || previous['sandboxToken'] == null) {
    throw StateError(
      'sandbox evidence was recreated or belongs to another account',
    );
  }
  if (previous['supportRoot'] != support.path) {
    throw StateError('application sandbox root changed across restart');
  }
  final blobIds = (previous['blobIds']! as List<Object?>).cast<String>();

  final coordinator = VaultBootCoordinator();
  final keys = _AndroidKeys(VaultAccountId(_account));
  try {
    stage.value = 'reopen-same-account';
    await coordinator.open(keys);
    final stores = _readyStores(coordinator);
    if (await _plaintextLeaseCount(support) != 0) {
      throw StateError('startup did not sweep abandoned plaintext leases');
    }
    stage.value = 'explicit-reconcile';
    final report = await stores.blobs.reconcile();
    if (report.changed || (await stores.blobs.journal()).isNotEmpty) {
      throw StateError('restart reconciliation did not converge idempotently');
    }
    await _verifyRowsAndVault(stores, blobIds);
    stage.value = 'retention-delete-reconcile';
    final retentionEvidence = await _proveRetentionAndDelete(stores);

    stage.value = 'authenticated-reads';
    for (var index = 0; index < _fixtures.length; index++) {
      final read = await stores.blobs.openAuthenticatedRead(
        VaultBlobId(blobIds[index]),
      );
      final bytes = await read.bytes.expand((chunk) => chunk).toList();
      if (!_bytesEqual(bytes, _fixtures[index].bytes)) {
        throw StateError(
          '${_fixtures[index].kind} authenticated read mismatch',
        );
      }
    }
    final ciphertext = await _scanCiphertext(support, blobIds);
    await evidence.writeAsString(
      jsonEncode({
        'phase': 'read',
        'status': 'ok',
        'pid': pid,
        'writerPid': writerPid,
        'account': _account,
        'sandboxToken': previous['sandboxToken'],
        'supportRoot': support.path,
        'privateRoot': previous['privateRoot'],
        'blobIds': blobIds,
        'itemCount': 3,
        'orphanCount': 0,
        'partialItemCount': 0,
        'ciphertextFiles': ciphertext,
        'authenticatedKinds': _fixtures.map((fixture) => fixture.kind).toList(),
        'reconciled': true,
        'plaintextLeaseCount': 0,
        ...retentionEvidence,
      }),
      flush: true,
    );
  } finally {
    await coordinator.close();
    await keys.dispose();
  }
}

Future<Map<String, Object?>> _proveRetentionAndDelete(
  VaultOpenedStores stores,
) async {
  final fixture = _Fixture(
    kind: 'retention',
    filename: 'w6-retention-fixture.bin',
    contentType: 'application/octet-stream',
    bytes: utf8.encode('MATOME-W6-KEEP-FOREVER-DELETE-RECONCILE'),
  );
  final stat = await stores.blobs.ingest(fixture);
  final now = DateTime.now();
  await stores.database.customStatement(
    'INSERT INTO file_blobs '
    '(id, core_id, filename, content_type, byte_size, checksum_sha256, '
    'media_type, upload_state, uploaded_at, blob_id, blob_state, '
    'cipher_format, cipher_version, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      'w6-retention-file',
      9001,
      fixture.filename,
      fixture.contentType,
      fixture.bytes.length,
      sha256.convert(fixture.bytes).toString(),
      fixture.kind,
      'uploaded',
      now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
      stat.id.value,
      'ready',
      stat.cipherFormat.name,
      stat.cipherVersion,
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ],
  );
  final retention = VaultRetentionService(stores.database, stores.blobs);
  final policy = await retention.readPolicy();
  if (policy.mode != VaultRetentionMode.keepForever) {
    throw StateError('default retention is not keep_forever');
  }
  await retention.reconcileAndCollect();
  if ((await stores.blobs.stat(stat.id)).state != VaultBlobState.ready) {
    throw StateError('keep_forever collected an unreferenced verified blob');
  }

  await stores.blobs.prepareDelete(stat.id);
  await stores.blobs.delete(stat.id);
  await stores.blobs.delete(stat.id);
  await retention.reconcileAndCollect();
  final row = await stores.database
      .customSelect(
        "SELECT blob_state FROM file_blobs WHERE id = 'w6-retention-file'",
      )
      .getSingle();
  if (row.read<String>('blob_state') != 'missing' ||
      (await stores.blobs.stat(stat.id)).state != VaultBlobState.missing) {
    throw StateError('delete/reconcile did not converge to missing');
  }
  return {
    'keepForeverPreserved': true,
    'deleteReconciled': true,
    'deleteIdempotent': true,
  };
}

Future<int> _plaintextLeaseCount(Directory support) async => support
    .list(recursive: true, followLinks: false)
    .where((entity) => entity is File && entity.path.endsWith('.lease'))
    .length;

VaultOpenedStores _readyStores(VaultBootCoordinator coordinator) {
  final snapshot = coordinator.state;
  if (snapshot.phase != VaultBootPhase.ready ||
      snapshot.accountId != VaultAccountId(_account) ||
      snapshot.stores == null) {
    throw StateError('account-scoped Vault boot did not become ready');
  }
  return snapshot.stores!;
}

Future<void> _verifyRowsAndVault(
  VaultOpenedStores stores,
  List<String> expectedBlobIds,
) async {
  final columns = await stores.database
      .customSelect("PRAGMA table_info('file_blobs')")
      .get();
  final columnNames = columns.map((row) => row.read<String>('name')).toSet();
  if (columnNames.intersection({
    'local_path',
    'wrapped_fek',
    'file_nonce_prefix',
  }).isNotEmpty) {
    throw StateError('path or app-owned key material remains in file_blobs');
  }
  final counts = await stores.database
      .customSelect(
        'SELECT (SELECT count(*) FROM items) AS item_count, '
        '(SELECT count(*) FROM file_blobs) AS file_count, '
        '(SELECT count(*) FROM items i JOIN file_blobs f '
        'ON f.id = i.file_blob_id) AS joined_count',
      )
      .getSingle();
  if (counts.read<int>('item_count') != 3 ||
      counts.read<int>('file_count') != 3 ||
      counts.read<int>('joined_count') != 3) {
    throw StateError('partial Item or unreferenced file row detected');
  }
  final rows = await stores.database
      .customSelect(
        'SELECT i.id AS item_id, f.id AS file_id, f.filename, f.content_type, '
        'f.byte_size, f.checksum_sha256, f.media_type, f.blob_id, '
        'f.blob_state, f.cipher_format, f.cipher_version '
        'FROM items i JOIN file_blobs f ON f.id = i.file_blob_id '
        "WHERE i.owner_id = 'android-w5-account' ORDER BY f.media_type",
      )
      .get();
  if (rows.length != _fixtures.length) {
    throw StateError('expected exactly three complete Item/file rows');
  }
  final byKind = {for (final fixture in _fixtures) fixture.kind: fixture};
  final referenced = <String>{};
  for (final row in rows) {
    final kind = row.read<String>('media_type');
    final fixture = byKind[kind];
    if (fixture == null ||
        row.read<String>('filename') != fixture.filename ||
        row.read<String>('content_type') != fixture.contentType ||
        row.read<int>('byte_size') != fixture.bytes.length ||
        row.read<String>('checksum_sha256') !=
            sha256.convert(fixture.bytes).toString() ||
        row.read<String>('blob_state') != 'ready' ||
        row.read<String>('cipher_format') != 'mec1' ||
        row.read<int>('cipher_version') != 1) {
      throw StateError('$kind logical facts do not match the fixture');
    }
    final blobId = row.read<String>('blob_id');
    referenced.add(blobId);
    final stat = await stores.blobs.stat(VaultBlobId(blobId));
    if (stat.state != VaultBlobState.ready ||
        stat.plaintextLength != fixture.bytes.length ||
        stat.plaintextSha256 != sha256.convert(fixture.bytes).toString()) {
      throw StateError('$kind Vault facts do not match Drift');
    }
  }
  final ready = (await stores.blobs.readyBlobIds())
      .map((id) => id.value)
      .toSet();
  if (referenced.length != 3 ||
      !referenced.containsAll(expectedBlobIds) ||
      !ready.containsAll(referenced) ||
      ready.length != referenced.length) {
    throw StateError('partial Item or orphaned ready blob detected');
  }
}

Future<List<String>> _scanCiphertext(
  Directory support,
  List<String> expectedBlobIds,
) async {
  final objects = await support
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File && entity.path.endsWith('.mec1'))
      .cast<File>()
      .toList();
  if (objects.length != 3) {
    throw StateError('expected exactly three MEC1 objects');
  }
  final names = <String>[];
  for (final object in objects) {
    final name = object.uri.pathSegments.last;
    final blobId = name.substring(0, name.length - '.mec1'.length);
    if (!expectedBlobIds.contains(blobId)) {
      throw StateError('ciphertext filename is not an expected opaque blob id');
    }
    final bytes = await object.readAsBytes();
    for (final fixture in _fixtures) {
      if (_contains(bytes, fixture.bytes) ||
          _contains(bytes, utf8.encode(fixture.filename)) ||
          _contains(bytes, utf8.encode('PLAINTEXT-2148'))) {
        throw StateError('ciphertext exposes ${fixture.kind} plaintext facts');
      }
    }
    names.add(name);
  }
  names.sort();
  return names;
}

Future<Map<String, Object?>?> _readEvidence(File evidence) async {
  if (!await evidence.exists()) return null;
  return jsonDecode(await evidence.readAsString()) as Map<String, Object?>;
}

String _randomToken() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(24, (_) => random.nextInt(256)));
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matched = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _Stage {
  _Stage(this.value);
  String value;
}

final class _Fixture implements MediaInput {
  const _Fixture({
    required this.kind,
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String kind;
  @override
  final String filename;
  @override
  final String contentType;
  final List<int> bytes;
  @override
  int get knownLength => bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.value(bytes);
}

final class _AndroidKeys implements VaultKeyMaterial {
  _AndroidKeys(this.accountId);
  @override
  final VaultAccountId accountId;
  final bytes = Uint8List.fromList(
    List<int>.generate(32, (index) => index + 37),
  );

  @override
  Future<void> dispose() async => bytes.fillRange(0, bytes.length, 0);

  @override
  Future<T> use<T>(
    FutureOr<T> Function(Uint8List accountDek) operation,
  ) async => await operation(bytes);
}
