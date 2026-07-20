import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/observability/app_log.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late InMemoryTokenStore tokenStore;
  late RecordingsRepository repo;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    tokenStore = InMemoryTokenStore();
    repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: tokenStore, dio: dio),
    );
  });

  group('createItemRecording', () {
    test('parses the W0 item + upload envelope from 201', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      final fixture =
          (jsonDecode(
                    File(
                      '../../contracts/v1/fixtures/canonical.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['item_create_response']
              as Map<String, dynamic>;
      adapter.onPost(
        '/api/matomes/42/items',
        (server) => server.reply(201, fixture),
        data: Matchers.any,
      );

      final result = await repo.createItemRecording(
        title: 'F4 test',
        matomeId: 42,
        clientId: 'rec_local_test',
        durationSeconds: 3,
        badge: 'test',
      );

      expect(result.recording.id, 42);
      expect(result.recording.processing.state, ProcessingState.notRequested);
      expect(result.upload.method, 'PUT');
      expect(result.upload.isPost, isFalse);
      expect(result.upload.url, contains('signature=redacted'));
    });
  });

  group('enqueueProcessing', () {
    test('accepts 202 and returns the echoed recording', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onPost(
        '/api/items/6/process',
        (server) => server.reply(202, {
          'item': {
            'id': 6,
            'owner_id': 1,
            'matome_id': 42,
            'item_type': 'file',
            'title': 'F4 test',
            'processing_state': 'queued',
            'processing_run_id': 'run-6',
            'processing_attempt': 1,
            'processing_requested_outputs': ['transcript', 'summary'],
            'processing_outputs': const <String, dynamic>{},
          },
          'processing': {'queued': true},
        }),
      );

      final rec = await repo.enqueueProcessing(6);
      expect(rec.id, 6);
    });
  });

  group('verified upload lifecycle', () {
    test('requests and parses resumable multipart state', () async {
      final partChecksum = List.filled(64, 'a').join();
      final fileChecksum = List.filled(64, 'b').join();
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onPost(
        '/api/v1/items/42/uploads',
        (server) => server.reply(200, {
          'contract_version': '1',
          'upload': {
            'upload_id': 'item-42-upload-3',
            'upload_generation': 3,
            'mode': 'multipart',
            'transport': 'direct_signed_length',
            'state': 'uploading',
            'part_size': 16 * 1024 * 1024,
            'accepted_parts': [
              {
                'part_number': 1,
                'etag': 'part-1',
                'checksum_sha256': partChecksum,
                'byte_size': 16 * 1024 * 1024,
              },
            ],
            'missing_parts': [2],
            'expires_at': '2026-07-16T12:00:00Z',
          },
        }),
        data: {
          'contract_version': '1',
          'idempotency_key': 'item-42-rev-1-upload',
          'input_revision': 1,
          'mode': 'auto',
          'transport': 'direct_signed_length',
          'byte_size': 26 * 1024 * 1024,
          'content_type': 'audio/wav',
          'checksum_sha256': fileChecksum,
        },
      );

      final upload = await repo.requestUpload(
        42,
        inputRevision: 1,
        byteSize: 26 * 1024 * 1024,
        contentType: 'audio/wav',
        checksumSha256: fileChecksum,
      );

      expect(upload.uploadId, 'item-42-upload-3');
      expect(upload.mode, UploadMode.multipart);
      expect(upload.transport, UploadTransport.directSignedLength);
      expect(upload.acceptedParts.single.etag, 'part-1');
      expect(upload.missingParts, [2]);
      expect(upload.request, isNull, reason: 'multipart URLs are per-part');
    });

    test(
      'presigns a checksum-bound part and completes verified bytes',
      () async {
        final firstChecksum = List.filled(64, 'a').join();
        final fileChecksum = List.filled(64, 'b').join();
        final secondChecksum = List.filled(64, 'c').join();
        await tokenStore.saveTokens(accessToken: 'tok');
        adapter.onPost(
          '/api/v1/uploads/item-42-upload-3/parts/2/presign',
          (server) => server.reply(200, {
            'contract_version': '1',
            'part': {
              'part_number': 2,
              'byte_size': 10,
              'checksum_sha256': secondChecksum,
              'request': {
                'method': 'PUT',
                'url': 'https://storage.invalid/part-2',
                'headers': {
                  'content-length': '10',
                  'x-amz-checksum-sha256': 'checksum-base64',
                },
              },
            },
          }),
          data: {'checksum_sha256': secondChecksum},
        );
        adapter.onPost(
          '/api/v1/uploads/item-42-upload-3/complete',
          (server) => server.reply(200, {
            'contract_version': '1',
            'upload': {
              'upload_id': 'item-42-upload-3',
              'upload_generation': 3,
              'mode': 'multipart',
              'state': 'uploaded',
              'verified_byte_size': 26 * 1024 * 1024,
              'verified_checksum_sha256': fileChecksum,
              'completed_at': '2026-07-15T12:03:00Z',
            },
          }),
          data: {
            'contract_version': '1',
            'upload_generation': 3,
            'checksum_sha256': fileChecksum,
            'parts': [
              {
                'part_number': 1,
                'etag': 'part-1',
                'checksum_sha256': firstChecksum,
              },
              {
                'part_number': 2,
                'etag': 'part-2',
                'checksum_sha256': secondChecksum,
              },
            ],
          },
        );

        final part = await repo.presignUploadPart(
          'item-42-upload-3',
          partNumber: 2,
          checksumSha256: secondChecksum,
        );
        final completed = await repo.completeUpload(
          'item-42-upload-3',
          uploadGeneration: 3,
          checksumSha256: fileChecksum,
          parts: [
            UploadPart(
              partNumber: 1,
              etag: 'part-1',
              checksumSha256: firstChecksum,
              byteSize: 16 * 1024 * 1024,
            ),
            UploadPart(
              partNumber: 2,
              etag: 'part-2',
              checksumSha256: secondChecksum,
              byteSize: 10,
            ),
          ],
        );

        expect(part.request.headers['content-length'], '10');
        expect(completed.state, UploadState.uploaded);
        expect(completed.verifiedByteSize, 26 * 1024 * 1024);
      },
    );

    test(
      'streams only the requested file range and returns provider ETag',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final received = Completer<List<int>>();
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          expect(
            request.headers.value('x-amz-checksum-sha256'),
            'part-checksum',
          );
          final body = await request.fold<List<int>>(
            <int>[],
            (bytes, chunk) => bytes..addAll(chunk),
          );
          request.response.headers.set('etag', '"part-etag"');
          request.response.statusCode = 200;
          await request.response.close();
          received.complete(body);
        });
        final bytes = List<int>.generate(32, (index) => index);

        final etag = await repo.uploadStreamRange(
          UploadRequest(
            method: 'PUT',
            url: 'http://${server.address.host}:${server.port}/part',
            headers: const {'x-amz-checksum-sha256': 'part-checksum'},
          ),
          Stream.value(bytes.sublist(8, 20)),
          12,
        );

        expect(
          await received.future,
          List<int>.generate(12, (index) => index + 8),
        );
        expect(etag, 'part-etag');
      },
    );

    test('preserves Vault corruption and never logs a signed URL', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 200;
        await request.response.close();
      });
      await expectLater(
        repo.uploadStreamRange(
          UploadRequest(
            method: 'PUT',
            url: 'http://${server.address.host}:${server.port}/signed',
          ),
          Stream.error(
            const VaultFailure(
              VaultFailureCode.corruptCiphertext,
              'authenticated chunk failed',
            ),
          ),
          1,
        ),
        throwsA(
          isA<VaultFailure>().having(
            (failure) => failure.code,
            'code',
            VaultFailureCode.corruptCiphertext,
          ),
        ),
      );

      final logs = <String>[];
      AppLog.testSink = logs.add;
      addTearDown(() => AppLog.testSink = null);
      await expectLater(
        repo.uploadStreamRange(
          const UploadRequest(
            method: 'PUT',
            url: 'http://127.0.0.1:1/object?X-Amz-Signature=secret',
          ),
          Stream.value(const [1]),
          1,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(logs.join('\n'), isNot(contains('X-Amz')));
      expect(logs.join('\n'), isNot(contains('secret')));
    });
  });

  group('fetchRecording (poll source)', () {
    test('returns the recording on 200', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onGet(
        '/api/items/6',
        (server) => server.reply(200, {
          'item': {
            'id': 6,
            'owner_id': 1,
            'matome_id': 42,
            'item_type': 'file',
            'title': 'F4 test',
            'processing_state': 'succeeded',
            'processing_run_id': 'run-6',
            'processing_attempt': 1,
            'processing_requested_outputs': ['summary'],
            'processing_outputs': {
              'summary': {'type': 'summary', 'markdown': 'done'},
            },
          },
        }),
      );
      final rec = await repo.fetchRecording(6);
      expect(rec!.status, RecordingStatus.done);
    });

    test('returns null on 404 (transient miss)', () async {
      await tokenStore.saveTokens(accessToken: 'tok');
      adapter.onGet(
        '/api/items/99',
        (server) => server.reply(404, {'error': 'not_found'}),
      );
      expect(await repo.fetchRecording(99), isNull);
    });
  });
}
