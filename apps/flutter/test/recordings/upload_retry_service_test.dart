import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/endpoint_controller.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';

void main() {
  test(
    'network recovery probes the current runtime endpoint before draining',
    () async {
      final queue = _RecordingQueue();
      final probedEndpoints = <String>[];
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          uploadQueueProvider.overrideWithValue(queue),
          uploadRetryServiceProvider.overrideWith(
            (ref) => UploadRetryService(
              ref,
              interval: const Duration(milliseconds: 5),
              probe: (baseUrl) async {
                probedEndpoints.add(baseUrl);
                return baseUrl == 'http://127.0.0.1:7999';
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(uploadRetryServiceProvider).start();
      expect(queue.drains, 1, reason: 'app start drains once');

      await container
          .read(endpointConfigProvider.notifier)
          .setBaseUrl('http://127.0.0.1:7999');
      await queue.networkRecovery.future.timeout(const Duration(seconds: 1));

      expect(probedEndpoints, contains('http://127.0.0.1:7999'));
      expect(queue.drains, 2, reason: 'unreachable to reachable drains once');
    },
  );
}

class _RecordingQueue extends UploadQueue {
  _RecordingQueue() : super(_NullRef());

  int drains = 0;
  final networkRecovery = Completer<void>();

  @override
  Future<void> drain() async {
    drains++;
    if (drains == 2 && !networkRecovery.isCompleted) {
      networkRecovery.complete();
    }
  }
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the recording queue never reads Ref');
}
