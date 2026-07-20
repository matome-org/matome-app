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
      var reports = 0;
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          uploadQueueProvider.overrideWithValue(queue),
          uploadRetryServiceProvider.overrideWith(
            (ref) => UploadRetryService(
              ref,
              interval: const Duration(milliseconds: 5),
              reportQueue: () async => reports++,
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
      await queue.firstDrainFinished.future.timeout(const Duration(seconds: 1));
      expect(reports, 1, reason: 'app start reports after the drain');

      await container
          .read(endpointConfigProvider.notifier)
          .setBaseUrl('http://127.0.0.1:7999');
      await queue.networkRecovery.future.timeout(const Duration(seconds: 1));

      expect(probedEndpoints, contains('http://127.0.0.1:7999'));
      expect(
        queue.drains,
        greaterThanOrEqualTo(2),
        reason: 'reachable ticks keep due durable retries moving',
      );
    },
  );

  test('steady reachability keeps due queue retries moving', () async {
    final queue = _RecordingQueue();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
        uploadQueueProvider.overrideWithValue(queue),
        uploadRetryServiceProvider.overrideWith(
          (ref) => UploadRetryService(
            ref,
            interval: const Duration(milliseconds: 5),
            probe: (_) async => true,
            reportQueue: () async {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(uploadRetryServiceProvider).start();
    await queue.networkRecovery.future.timeout(const Duration(seconds: 1));

    expect(queue.drains, greaterThanOrEqualTo(2));
  });
}

class _RecordingQueue extends UploadQueue {
  _RecordingQueue() : super(_NullRef());

  int drains = 0;
  final networkRecovery = Completer<void>();
  final firstDrainFinished = Completer<void>();

  @override
  Future<void> drain() async {
    drains++;
    if (drains == 1 && !firstDrainFinished.isCompleted) {
      firstDrainFinished.complete();
    }
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
