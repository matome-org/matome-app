/// Platform-neutral contracts for Matome's encrypted media vault.
library;

export 'src/contracts.dart';
export 'src/mec1.dart';
export 'src/native_blob_store_stub.dart'
    if (dart.library.io) 'src/native_blob_store_io.dart';
export 'src/web_blob_store_stub.dart'
    if (dart.library.js_interop) 'src/web_blob_store_web.dart';
