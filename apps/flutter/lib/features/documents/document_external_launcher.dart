import 'document_external_launcher_io.dart'
    if (dart.library.js_interop) 'document_external_launcher_web.dart';
import 'document_open_service.dart';

ExternalDocumentLauncher createExternalDocumentLauncher() =>
    createPlatformExternalDocumentLauncher();
