import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:matome_vault/matome_vault.dart';
import 'package:web/web.dart';

const _phaseKey = 'matome.vault.2146.phase';
const _accountKey = 'matome.vault.2146.account';
const _blobKey = 'matome.vault.2146.blob';
const _sentinel = 'MATOME_WEB_RELOAD_SENTINEL_2146';

Future<void> main() async {
  try {
    _phase('started');
    final existingAccount = window.localStorage.getItem(_accountKey);
    if (window.localStorage.getItem(_phaseKey) != 'written' ||
        existingAccount == null) {
      final account = VaultAccountId(
        'reload-proof-${DateTime.now().microsecondsSinceEpoch}',
      );
      final keys = _Keys(account);
      final store = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      final stat = await store.ingest(
        _Input(Uint8List.fromList(utf8.encode(_sentinel))),
      );
      await keys.dispose();
      window.localStorage.setItem(_accountKey, account.value);
      window.localStorage.setItem(_blobKey, stat.id.value);
      window.localStorage.setItem(_phaseKey, 'written');
      _phase('reload');
      window.location.reload();
      return;
    }

    _phase('reopened');
    final account = VaultAccountId(existingAccount);
    final keys = _Keys(account);
    final store = await WebMediaBlobStore.open(
      accountId: account,
      keyMaterial: keys,
    );
    final id = VaultBlobId(window.localStorage.getItem(_blobKey)!);
    final read = await store.openAuthenticatedRead(id);
    final output = BytesBuilder(copy: false);
    await for (final chunk in read.bytes) {
      output.add(chunk);
    }
    if (utf8.decode(output.takeBytes()) != _sentinel) {
      throw StateError('authenticated reload plaintext mismatch');
    }
    final purposes = <VaultLeasePurpose, bool>{};
    for (final purpose in const [
      VaultLeasePurpose.playback,
      VaultLeasePurpose.preview,
      VaultLeasePurpose.externalOpen,
    ]) {
      final lease = await store.createLease(
        id,
        purpose: purpose,
        ttl: const Duration(minutes: 1),
      );
      if (!await _urlReadable(lease.location)) {
        throw StateError('${purpose.name} Blob URL is unreadable');
      }
      await lease.dispose();
      if (await _urlReadable(lease.location)) {
        throw StateError('${purpose.name} Blob URL survived revoke');
      }
      purposes[purpose] = true;
    }
    await store.prepareDelete(id);
    await store.delete(id);
    await store.delete(id);
    if ((await store.stat(id)).state != VaultBlobState.missing ||
        (await store.reconcile()).changed) {
      throw StateError('delete/reconcile did not converge idempotently');
    }
    await keys.dispose();
    window.localStorage.removeItem(_phaseKey);
    window.localStorage.removeItem(_accountKey);
    window.localStorage.removeItem(_blobKey);
    _finish({
      'status': 'pass',
      'reload': true,
      'secureContext': window.isSecureContext,
      'authenticatedRead': true,
      'preservedUntilExplicitDelete': true,
      'audioUrlRevoked': purposes[VaultLeasePurpose.playback],
      'imageUrlRevoked': purposes[VaultLeasePurpose.preview],
      'documentUrlRevoked': purposes[VaultLeasePurpose.externalOpen],
      'deleteReconciled': true,
      'cleanup': true,
    });
  } catch (error, stack) {
    _finish({
      'status': 'fail',
      'error': error.toString(),
      'stack': stack.toString(),
    });
  }
}

Future<bool> _urlReadable(Uri uri) async {
  try {
    final response = await window.fetch(uri.toString().toJS).toDart;
    return response.ok;
  } catch (_) {
    return false;
  }
}

void _phase(String value) {
  var output = document.getElementById('phase');
  if (output == null) {
    output = document.createElement('pre')..id = 'phase';
    document.body?.append(output);
  }
  output.textContent = value;
}

void _finish(Map<String, Object?> report) {
  final output = document.createElement('pre') as HTMLElement
    ..id = 'result'
    ..textContent = jsonEncode(report);
  document.body?.replaceChildren(output);
}

final class _Input implements MediaInput {
  const _Input(this.bytes);
  final Uint8List bytes;
  @override
  String? get contentType => null;
  @override
  String get filename => 'must-not-persist.wav';
  @override
  int get knownLength => bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.value(bytes);
}

final class _Keys implements VaultKeyMaterial {
  _Keys(this.accountId)
    : _bytes = Uint8List.fromList(List<int>.generate(32, (index) => index + 1));
  @override
  final VaultAccountId accountId;
  Uint8List? _bytes;
  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) =>
      Future.sync(() => operation(_bytes!));
  @override
  Future<void> dispose() async {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
  }
}
