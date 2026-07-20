import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart'
    show
        AbortController,
        Headers,
        ReadableStream,
        ReadableStreamDefaultController,
        RequestInit,
        Response;

import '../../core/http/api_exception.dart';
import 'upload_descriptor.dart';

@JS('fetch')
external JSPromise<Response> _fetch(String input, RequestInit init);

extension type _ReadableSource._(JSObject _) implements JSObject {
  external factory _ReadableSource({
    required JSFunction pull,
    required JSFunction cancel,
  });
}

Future<String> sendPresignedUpload(
  UploadRequest request,
  Stream<List<int>> stream,
  int length, {
  required bool requireEtag,
}) async {
  final signedLength = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'content-length')
      .map((entry) => entry.value)
      .firstOrNull;
  if (signedLength != null) {
    if (int.tryParse(signedLength) != length) {
      throw const ApiException(
        'Signed upload length does not match the logical blob size.',
        code: 'invalid_local_data',
      );
    }
    throw const ApiException(
      'This browser cannot stream a request with a signed Content-Length.',
      code: 'streaming_upload_unsupported',
    );
  }
  final iterator = StreamIterator<List<int>>(stream);
  var emitted = 0;
  var finished = false;

  JSPromise<JSAny?> pull(ReadableStreamDefaultController controller) =>
      (() async {
        final hasNext = await iterator.moveNext();
        if (!hasNext) {
          if (emitted != length) {
            throw const ApiException(
              'Upload stream length did not match its logical size.',
              code: 'invalid_local_data',
            );
          }
          finished = true;
          controller.close();
          return null;
        }
        final chunk = iterator.current;
        if (chunk.isEmpty) return null;
        if (emitted + chunk.length > length) {
          throw const ApiException(
            'Upload stream exceeded its logical size.',
            code: 'invalid_local_data',
          );
        }
        emitted += chunk.length;
        controller.enqueue(Uint8List.fromList(chunk).toJS);
        return null;
      })().toJS;

  JSPromise<JSAny?> cancel(JSAny? _) => (() async {
    await iterator.cancel();
    return null;
  })().toJS;

  final body = ReadableStream(
    _ReadableSource(pull: pull.toJS, cancel: cancel.toJS),
  );
  final headers = Headers();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() != 'content-length') {
      headers.set(entry.key, entry.value);
    }
  }
  headers.set('content-type', 'application/octet-stream');
  final abort = AbortController();
  final timeout = Timer(const Duration(minutes: 5), () => abort.abort());
  try {
    final response = await _fetch(
      request.url,
      RequestInit(
        method: request.method,
        headers: headers,
        body: body,
        duplex: 'half',
        signal: abort.signal,
      ),
    ).toDart;
    if (!finished || emitted != length) {
      throw const ApiException(
        'Upload stream ended before its logical size.',
        code: 'invalid_local_data',
      );
    }
    if (!response.ok) {
      throw ApiException(
        'Recording upload failed.',
        statusCode: response.status,
        code: 'upload_failed',
      );
    }
    final etag = response.headers.get('etag')?.replaceAll('"', '').trim();
    if (requireEtag && (etag == null || etag.isEmpty)) {
      throw const ApiException(
        'Upload response did not include an ETag.',
        code: 'upload_missing_etag',
      );
    }
    return etag ?? '';
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException('Recording upload failed.', code: 'upload_failed');
  } finally {
    timeout.cancel();
    if (!finished) await iterator.cancel();
  }
}
