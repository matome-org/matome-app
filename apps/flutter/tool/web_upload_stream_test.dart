import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/features/recordings/presigned_upload_transport.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:test/test.dart';

void main() {
  const endpoint = 'https://127.0.0.1:17777/upload';

  test('Chromium streams exact plaintext and returns provider ETag', () async {
    final fixture = List<int>.generate(
      64 * 1024 * 5 + 317,
      (index) => (index * 29 + 7) & 0xff,
    );
    final expected = sha256.convert(fixture).toString();
    var opened = 0;
    var emitted = 0;
    Stream<List<int>> source() async* {
      opened++;
      for (var start = 0; start < fixture.length; start += 8192) {
        final end = (start + 8192).clamp(0, fixture.length);
        emitted += end - start;
        yield fixture.sublist(start, end);
      }
    }

    final etag = await sendPresignedUpload(
      UploadRequest(
        method: 'PUT',
        url: endpoint,
        headers: {'x-test-checksum': expected},
      ),
      source(),
      fixture.length,
      requireEtag: true,
    );

    expect(etag, expected);
    expect(opened, 1);
    expect(emitted, fixture.length);
  });

  test('signed Content-Length fails closed before opening plaintext', () async {
    var opened = false;
    Stream<List<int>> source() async* {
      opened = true;
      yield [1, 2, 3];
    }

    await expectLater(
      sendPresignedUpload(
        const UploadRequest(
          method: 'PUT',
          url: endpoint,
          headers: {'content-length': '3'},
        ),
        source(),
        3,
        requireEtag: true,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'streaming_upload_unsupported',
        ),
      ),
    );
    expect(opened, isFalse);
  });

  test(
    'Chromium streams Core browser descriptors to MinIO',
    () async {
      final dio = Dio();
      final fixtureResponse = await dio.get<Map<String, dynamic>>(
        'https://127.0.0.1:17777/fixture',
      );
      final fixture = fixtureResponse.data!;

      Stream<List<int>> zeros(int length) async* {
        const chunkSize = 64 * 1024;
        var remaining = length;
        while (remaining > 0) {
          final size = remaining.clamp(0, chunkSize);
          yield Uint8List(size);
          remaining -= size;
        }
      }

      Future<String> upload(Map<String, dynamic> raw, int length) {
        final request = UploadRequest.fromJson(raw);
        return sendPresignedUpload(
          UploadRequest(
            method: request.method,
            url: request.url,
            headers: {
              ...request.headers,
              'x-matome-proxy-content-length': '$length',
            },
          ),
          zeros(length),
          length,
          requireEtag: true,
        );
      }

      final single = fixture['single'] as Map<String, dynamic>;
      final singleEtag = await upload(
        single['request'] as Map<String, dynamic>,
        single['length'] as int,
      );

      final partEtags = <String>[];
      for (final raw in fixture['parts'] as List<dynamic>) {
        final part = raw as Map<String, dynamic>;
        partEtags.add(
          await upload(
            part['request'] as Map<String, dynamic>,
            part['length'] as int,
          ),
        );
      }

      await dio.post<void>(
        'https://127.0.0.1:17777/result',
        data: jsonEncode({'single_etag': singleEtag, 'part_etags': partEtags}),
        options: Options(contentType: 'application/json'),
      );

      expect(singleEtag, isNotEmpty);
      expect(partEtags, everyElement(isNotEmpty));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
