@Tags(['live'])
library;

// LIVE de-risk integration test (NOT part of the normal suite).
//
// Run only against a running Core API on :4000 with a valid access token:
//
//   LIVE_TOKEN=<access_token> flutter test test/live_socket_derisk_test.dart \
//       --tags live
//
// Proves, in real Dart via the phoenix_socket package:
//   * presign create -> stream upload -> /process (real HTTP),
//   * socket connect + join `user:{ownerId}` + receive `recording:status`.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recording_status_socket.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

void main() {
  final token = Platform.environment['LIVE_TOKEN'];
  final baseUrl =
      Platform.environment['LIVE_BASE_URL'] ?? 'http://localhost:4000';

  test('LIVE: presign upload + phoenix_socket join + recording:status', () async {
    if (token == null || token.isEmpty) {
      // Skipped unless LIVE_TOKEN is provided.
      return;
    }

    final tokenStore = InMemoryTokenStore();
    await tokenStore.saveTokens(accessToken: token);
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      validateStatus: (s) => s != null && s < 500,
    ));
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: tokenStore, dio: dio),
    );

    // 1. Create + presign.
    final created = await repo.createRecording(
      title: 'Dart de-risk',
      durationSeconds: 2,
      badge: 'dart',
    );
    final id = created.recording.id;
    final ownerId = created.recording.ownerId;
    // ignore: avoid_print
    print('CREATED id=$id owner=$ownerId presign=${created.upload.method} '
        '${created.upload.url.split('?').first}');

    // 2. Connect + join BEFORE processing, so the broadcast is captured.
    final socket = RecordingStatusSocket(
      apiBaseUrl: baseUrl,
      tokenStore: tokenStore,
      ownerId: ownerId,
    );
    final joined = await socket.connectAndJoin();
    // ignore: avoid_print
    print('SOCKET joined user:$ownerId = $joined');
    expect(joined, isTrue);

    final eventFuture = socket.events
        .firstWhere((e) => e.recordingId == id)
        .timeout(const Duration(seconds: 30));

    // 3. Upload bytes to the presigned URL (streamed).
    final tmp = File('${Directory.systemTemp.path}/derisk_$id.bin')
      ..writeAsBytesSync(List<int>.generate(2048, (i) => i % 256));
    await repo.uploadFile(created.upload, tmp);
    // ignore: avoid_print
    print('UPLOAD ok');

    // 4. Enqueue processing.
    await repo.enqueueProcessing(id);
    // ignore: avoid_print
    print('PROCESS enqueued');

    // 5. Await a real recording:status push.
    final RecordingStatusEvent event = await eventFuture;
    // ignore: avoid_print
    print('EVENT recording:status status=${event.status} '
        'summary=${event.summary}');
    expect(event.recordingId, id);
    expect(
      event.status,
      anyOf(RecordingStatus.processing, RecordingStatus.done),
    );

    await socket.dispose();
    tmp.deleteSync();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
