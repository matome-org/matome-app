import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeting_capture/meeting_capture.dart';

import '../../core/providers.dart';
import '../../core/storage/app_storage.dart';
import '../home/inbox_upload.dart';
import 'meeting_capture_finish.dart';
import 'meeting_capture_service.dart';

const int _minimumMeetingFreeBytes = 64 * 1024 * 1024;

final meetingCaptureBackendProvider = Provider<MeetingCaptureBackend>((ref) {
  final backend = MeetingCapturePlatform.instance.createBackend();
  ref.onDispose(() => unawaited(backend.dispose()));
  return backend;
});

final meetingCaptureCapabilityProvider =
    FutureProvider<MeetingCaptureCapability>(
      (ref) => MeetingCapturePlatform.instance.probe(),
    );

final meetingCaptureServiceProvider = Provider<MeetingCaptureService>((ref) {
  final inspectArtifact =
      MeetingCapturePlatform.instance.createArtifactInspector();
  final service = MeetingCaptureService(
    draftsDao: ref.watch(recordingDraftsDaoProvider),
    backend: ref.watch(meetingCaptureBackendProvider),
    storageDirectory: _secureMeetingStorage,
    inspectArtifact: inspectArtifact,
    availableBytes: _availableBytes,
    durabilityBarrier: _syncPublishedArtifact,
    minimumAvailableBytes: _minimumMeetingFreeBytes,
    operationTimeout: const Duration(seconds: 120),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final meetingCaptureFinisherProvider = Provider<MeetingCaptureFinisher>(
  (ref) => MeetingCaptureFinisher.forInbox(
    service: ref.watch(meetingCaptureServiceProvider),
    uploader: ref.watch(inboxUploaderProvider),
  ),
);

Future<Directory> _secureMeetingStorage() async {
  final directory = await matomeStorageDir();
  final chmod = await runBoundedCommand('chmod', ['700', directory.path]);
  if (chmod.exitCode != 0) {
    throw MeetingStorageUnsafeError(
      'Could not secure meeting storage: ${chmod.stderr}',
    );
  }
  return directory;
}

Future<int?> _availableBytes(String path) async {
  final result = await runBoundedCommand('df', ['-Pk', path]);
  if (result.exitCode != 0) return null;
  final lines = result.stdout
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.length < 2) return null;
  final columns = lines.last.trim().split(RegExp(r'\s+'));
  if (columns.length < 4) return null;
  final availableKiB = int.tryParse(columns[3]);
  return availableKiB == null ? null : availableKiB * 1024;
}

Future<void> _syncPublishedArtifact(String root, String artifactPath) async {
  for (final path in [artifactPath, root]) {
    final result = await runBoundedCommand('sync', ['-d', path]);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not sync meeting artifact', path);
    }
  }
}
