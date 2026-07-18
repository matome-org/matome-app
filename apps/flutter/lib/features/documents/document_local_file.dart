import 'document_local_file_io.dart'
    if (dart.library.js_interop) 'document_local_file_web.dart';

Future<bool> documentLocalFileExists(String path) => localFileExists(path);

Future<List<int>> readDocumentLocalPrefix(String path, int maxBytes) =>
    readLocalPrefix(path, maxBytes);
