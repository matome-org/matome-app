import 'package:url_launcher/url_launcher.dart';

import 'document_open_service.dart';

ExternalDocumentLauncher createPlatformExternalDocumentLauncher() =>
    _NativeExternalDocumentLauncher();

class _NativeExternalDocumentLauncher implements ExternalDocumentLauncher {
  @override
  ExternalOpenReservation reserve() => const _NativeReservation();
}

class _NativeReservation implements ExternalOpenReservation {
  const _NativeReservation();

  @override
  Future<bool> launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  void close() {}
}
