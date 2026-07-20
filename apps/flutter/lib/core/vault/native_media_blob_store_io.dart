import 'dart:io';

import 'package:matome_vault/matome_vault.dart';
import 'package:path_provider/path_provider.dart';

typedef ApplicationSupportUriResolver = Future<Uri> Function();

/// Opens the account-scoped native store under the host's private support root.
Future<MediaBlobStore> openNativeMediaBlobStore({
  required VaultAccountId accountId,
  required VaultKeyMaterial keyMaterial,
  ApplicationSupportUriResolver? resolveApplicationSupport,
}) async {
  final uri = await (resolveApplicationSupport ?? _applicationSupportUri)();
  if (uri.scheme != 'file') {
    throw ArgumentError('Application Support must be a local file URI.');
  }
  return NativeMediaBlobStore.open(
    applicationSupportRoot: Directory.fromUri(uri).path,
    accountId: accountId,
    keyMaterial: keyMaterial,
  );
}

Future<Uri> _applicationSupportUri() async =>
    (await getApplicationSupportDirectory()).uri;
