import 'package:dio/dio.dart';
import 'package:matome_vault/matome_vault.dart';

import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import 'upload_descriptor.dart';

Future<String> sendPresignedUpload(
  UploadRequest request,
  Stream<List<int>> stream,
  int length, {
  required bool requireEtag,
}) async {
  final rawDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  try {
    final response = await rawDio.requestUri<void>(
      Uri.parse(request.url),
      data: stream,
      options: Options(
        method: request.method,
        headers: <String, dynamic>{
          ...request.headers,
          Headers.contentLengthHeader: length,
          Headers.contentTypeHeader: 'application/octet-stream',
        },
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiException(
        'Recording upload failed.',
        statusCode: status,
        code: 'upload_failed',
      );
    }
    final etag = response.headers.value('etag')?.replaceAll('"', '').trim();
    if (requireEtag && (etag == null || etag.isEmpty)) {
      throw const ApiException(
        'Upload response did not include an ETag.',
        code: 'upload_missing_etag',
      );
    }
    return etag ?? '';
  } on DioException catch (error, stack) {
    final cause = error.error;
    if (cause is VaultFailure) {
      Error.throwWithStackTrace(cause, stack);
    }
    AppLog.error(
      LogCat.upload,
      'presigned upload transport failed type=${error.type.name}',
    );
    throw ApiException.fromDio(error);
  } finally {
    rawDio.close(force: true);
  }
}
