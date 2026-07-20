import 'package:matome_vault/matome_vault.dart';

typedef ApplicationSupportUriResolver = Future<Uri> Function();

Future<MediaBlobStore> openNativeMediaBlobStore({
  required VaultAccountId accountId,
  required VaultKeyMaterial keyMaterial,
  ApplicationSupportUriResolver? resolveApplicationSupport,
}) => Future.error(
  UnsupportedError('The native media blob store is unavailable on Web.'),
);
