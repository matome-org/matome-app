import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

void main() {
  test(
    'Inbox parent -> Core parent -> idempotent item -> PUT -> done',
    () async {
      final core = await _ContractCore.start();
      addTearDown(core.close);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final temp = await Directory.systemTemp.createTemp('parent_core_e2e_');
      addTearDown(() => temp.delete(recursive: true));

      await db
          .into(db.matomes)
          .insert(
            MatomesCompanion.insert(
              id: 'mat_local_inbox',
              title: 'Inbox parent',
              happenedAt: 1,
              createdAt: 1,
            ),
          );
      final media = File('${temp.path}/capture.m4a');
      await media.writeAsBytes(const [1, 3, 3, 7]);
      await db.recordingsDao.insertRecording(
        RecordingsCompanion.insert(
          id: 'rec_local_e2e',
          title: 'Capture',
          timestamp: 'now',
          duration: '2s',
          audioFilePath: media.path,
          createdAt: 1,
          matomeId: const Value('mat_local_inbox'),
          processingStatus: const Value('pending_upload'),
        ),
      );

      final tokens = InMemoryTokenStore();
      await tokens.saveTokens(accessToken: 'owner-token');
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(tokens),
          currentOwnerIdProvider.overrideWithValue('1'),
          apiClientProvider.overrideWithValue(
            ApiClient(tokenStore: tokens, baseUrl: core.baseUrl),
          ),
          uploadQueueProvider.overrideWith(
            (ref) => UploadQueue(ref, awaitResult: _pollAwaiter),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();

      final parent = await db.matomesDao.getById('mat_local_inbox');
      final child = await db.recordingsDao.getRecordingById('rec_local_e2e');
      expect(parent!.coreId, 11);
      expect(child!.coreId, 42);
      expect(child.processingStatus, 'done');
      expect(child.summary, 'Contract path complete');
      expect(core.uploadedBytes, const [1, 3, 3, 7]);
      expect(core.calls, ['parent', 'item', 'upload', 'process', 'poll']);
      expect(core.parentRequest.containsKey('workspace_id'), isFalse);
      expect(core.itemRequest['client_id'], 'rec_local_e2e');
      for (final path in const [
        '/api/matomes',
        '/api/matomes/11/items',
        '/api/items/42/process',
        '/api/items/42',
      ]) {
        expect(
          core.authByPath[path],
          everyElement('Bearer owner-token'),
          reason: 'Bearer auth on $path',
        );
      }
    },
  );
}

Future<RecordingResult> _pollAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  final waiter = RecordingResultWaiter(
    recordingId: recording.id,
    statusEvents: const Stream<RecordingStatusEvent>.empty(),
    poll: poll,
    pollInterval: const Duration(milliseconds: 5),
    timeout: const Duration(seconds: 1),
  );
  try {
    return await waiter.wait();
  } finally {
    waiter.cancel();
  }
}

class _ContractCore {
  _ContractCore._(this._server);

  final HttpServer _server;
  final calls = <String>[];
  final authByPath = <String, List<String>>{};
  final parentRequest = <String, dynamic>{};
  final itemRequest = <String, dynamic>{};
  List<int> uploadedBytes = const [];

  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  static Future<_ContractCore> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final core = _ContractCore._(server);
    server.listen(core._handle);
    return core;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path != '/upload') {
      (authByPath[path] ??= <String>[]).add(
        request.headers.value(HttpHeaders.authorizationHeader) ?? '',
      );
    }

    if (request.method == 'POST' && path == '/api/matomes') {
      calls.add('parent');
      parentRequest.addAll(await _jsonBody(request));
      await _json(request, HttpStatus.created, {
        'matome': {
          'id': 11,
          'owner_id': 1,
          'title': parentRequest['title'],
          'workspace_id': null,
          'contacts': <Object>[],
        },
      });
      return;
    }

    if (request.method == 'POST' && path == '/api/matomes/11/items') {
      calls.add('item');
      itemRequest.addAll(await _jsonBody(request));
      await _json(request, HttpStatus.created, {
        'contract_version': '1',
        'item': _item(status: 'pending'),
        'upload': {
          'upload_id': 'upl_e2e',
          'upload_generation': 1,
          'mode': 'single',
          'state': 'pending',
          'request': {'method': 'PUT', 'url': '$baseUrl/upload', 'headers': {}},
        },
      });
      return;
    }

    if (request.method == 'PUT' && path == '/upload') {
      calls.add('upload');
      uploadedBytes = await request.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == '/api/items/42/process') {
      calls.add('process');
      await _json(request, HttpStatus.accepted, {
        'item': _item(status: 'processing'),
        'processing': {'queued': true},
      });
      return;
    }

    if (request.method == 'GET' && path == '/api/items/42') {
      calls.add('poll');
      await _json(request, HttpStatus.ok, {
        'item': _item(status: 'done', summary: 'Contract path complete'),
      });
      return;
    }

    // InboxController starts one best-effort list refresh when the queue first
    // reconciles a Core id. It is outside this path's assertions but receives a
    // contract-valid empty list so no background request is left unresolved.
    if (request.method == 'GET' && path == '/api/items') {
      await _json(request, HttpStatus.ok, {'items': <Object>[]});
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Map<String, dynamic> _item({required String status, String? summary}) => {
    'id': 42,
    'client_id': 'rec_local_e2e',
    'owner_id': 1,
    'matome_id': 11,
    'item_type': 'file',
    'metadata': {'title': 'Capture', 'status': status},
    'file': {'media_type': 'audio', 'byte_size': 4, 'summary': ?summary},
  };

  Future<Map<String, dynamic>> _jsonBody(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
      <int>[],
      (body, chunk) => body..addAll(chunk),
    );
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> _json(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
