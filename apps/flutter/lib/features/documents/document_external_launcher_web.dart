import 'package:web/web.dart' as web;

import 'document_open_service.dart';

ExternalDocumentLauncher createPlatformExternalDocumentLauncher() =>
    _WebExternalDocumentLauncher();

class _WebExternalDocumentLauncher implements ExternalDocumentLauncher {
  @override
  ExternalOpenReservation reserve() {
    final popup = web.window.open('about:blank', '_blank');
    popup?.opener = null;
    return _WebReservation(popup);
  }
}

class _WebReservation implements ExternalOpenReservation {
  const _WebReservation(this._popup);

  final web.Window? _popup;

  @override
  Future<bool> launch(Uri uri) async {
    final popup = _popup;
    if (popup == null) return false;
    popup.location.href = uri.toString();
    return true;
  }

  @override
  void close() => _popup?.close();
}
