// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import '../home/inbox_upload.dart';
import '../../core/vault/media_inputs.dart';
import 'package:meeting_capture/meeting_capture.dart';
import 'meeting_capture_service.dart';

typedef MeetingArtifactPersist =
    Future<String> Function(MeetingCaptureArtifact artifact, {String? title});
typedef MeetingUploadSchedule = void Function(String localId);

/// Orders the only allowed egress edge: validate and publish locally, commit the
/// Item + work row, clear recovery state, then let the queue start afterward.
class MeetingCaptureFinisher {
  const MeetingCaptureFinisher({
    required MeetingCaptureService service,
    required MeetingArtifactPersist persist,
    required MeetingUploadSchedule scheduleUpload,
  }) : _service = service,
       _persist = persist,
       _scheduleUpload = scheduleUpload;

  final MeetingCaptureService _service;
  final MeetingArtifactPersist _persist;
  final MeetingUploadSchedule _scheduleUpload;

  factory MeetingCaptureFinisher.forInbox({
    required MeetingCaptureService service,
    required InboxUploader uploader,
  }) {
    return MeetingCaptureFinisher(
      service: service,
      persist: (artifact, {title}) => uploader.persist(
        PickedUpload(
          input: mediaInputFromFile(
            File(artifact.path),
            filename: 'meeting.m4a',
            contentType: 'audio/mp4',
            knownLength: artifact.facts.byteSize,
          ),
          title: title ?? 'New Meeting',
          mediaType: 'audio',
          filename: 'meeting.m4a',
          mimeType: 'audio/mp4',
          byteSize: artifact.facts.byteSize,
        ),
        durationSeconds: artifact.facts.duration.inSeconds,
        localId: 'rec_local_${artifact.sessionId}',
        expectedByteSize: artifact.facts.byteSize,
      ),
      scheduleUpload: (localId) => unawaited(uploader.drainPersisted(localId)),
    );
  }

  Future<String> finish({String? title}) async {
    final artifact = await _service.stop();
    return persistRecovered(artifact, title: title);
  }

  /// Commit an artifact returned by [MeetingCaptureService.recover] without
  /// attempting to stop a recorder that no longer exists.
  Future<String> persistRecovered(
    MeetingCaptureArtifact artifact, {
    String? title,
  }) async {
    await _service.validatePublishedArtifact(artifact);
    final localId = await _persist(artifact, title: title);
    await _service.acknowledgePersisted(artifact.sessionId);
    _scheduleUpload(localId);
    return localId;
  }
}
