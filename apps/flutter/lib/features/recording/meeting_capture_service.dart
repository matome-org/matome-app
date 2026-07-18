// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../core/db/daos/recording_drafts_dao.dart';
import 'package:meeting_capture/meeting_capture.dart';

typedef MeetingStorageCapacityProbe = Future<int?> Function(String path);
typedef MeetingArtifactDurabilityBarrier =
    Future<void> Function(String storageRoot, String artifactPath);

Future<void> _noDurabilityBarrier(String _, String _) async {}

/// Owns the local-only meeting capture lifecycle. This class has no networking
/// dependency; upload can only be scheduled after [stop] returns a validated
/// artifact and the caller persists it locally.
class MeetingCaptureService {
  MeetingCaptureService({
    required RecordingDraftsDao draftsDao,
    required MeetingCaptureBackend backend,
    required Future<Directory> Function() storageDirectory,
    required MeetingArtifactInspector inspectArtifact,
    required MeetingStorageCapacityProbe availableBytes,
    MeetingArtifactDurabilityBarrier durabilityBarrier = _noDurabilityBarrier,
    required this.minimumAvailableBytes,
    this.heartbeatInterval = const Duration(seconds: 2),
    this.operationTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _draftsDao = draftsDao,
       _backend = backend,
       _storageDirectory = storageDirectory,
       _inspectArtifact = inspectArtifact,
       _availableBytes = availableBytes,
       _durabilityBarrier = durabilityBarrier,
       _now = now ?? DateTime.now {
    _backendEvents = _backend.events.listen(_handleBackendEvent);
  }

  final RecordingDraftsDao _draftsDao;
  final MeetingCaptureBackend _backend;
  final Future<Directory> Function() _storageDirectory;
  final MeetingArtifactInspector _inspectArtifact;
  final MeetingStorageCapacityProbe _availableBytes;
  final MeetingArtifactDurabilityBarrier _durabilityBarrier;
  final DateTime Function() _now;
  final Duration heartbeatInterval;
  final Duration operationTimeout;
  late final StreamSubscription<MeetingCaptureEvent> _backendEvents;

  /// Provider quota, not a product duration limit. Set to zero to disable.
  final int minimumAvailableBytes;

  Timer? _heartbeat;
  Future<void>? _heartbeatInFlight;
  RecordingDraft? _draft;
  DateTime? _startedAt;
  String? _storageRoot;
  String? _operation;
  MeetingCaptureState _state = MeetingCaptureState.idle;

  MeetingCaptureState get state => _state;
  Stream<MeetingCaptureEvent> get events => _backend.events;

  Future<void> start() => _exclusive('start', () async {
    try {
      await _start();
    } catch (_) {
      if (_state == MeetingCaptureState.starting) {
        _state = MeetingCaptureState.idle;
      }
      rethrow;
    }
  });

  Future<void> _start() async {
    if (_state != MeetingCaptureState.idle) {
      throw StateError('Meeting capture is already active');
    }
    _state = MeetingCaptureState.starting;

    final capability = await _bounded('probe', _backend.probe());
    if (!capability.supported) {
      _state = MeetingCaptureState.unavailable;
      throw MeetingCaptureUnsupportedError(
        capability.reason ?? 'Meeting capture is unavailable',
      );
    }
    final permission = await _bounded(
      'permission',
      _backend.requestPermission(),
    );
    if (permission != MeetingCapturePermission.granted) {
      _state = MeetingCaptureState.unavailable;
      throw MeetingCapturePermissionError(permission);
    }

    final directory = await _storageDirectory();
    await _pinStorageRoot(directory);
    final free = await _bounded(
      'storage-capacity',
      _availableBytes(_storageRoot!),
    );
    if (free != null && free < minimumAvailableBytes) {
      _state = MeetingCaptureState.unavailable;
      throw const MeetingStorageLowError();
    }

    final timestamp = _now().toUtc();
    final sessionId =
        'meeting_${timestamp.microsecondsSinceEpoch}_${_randomSuffix(6)}';
    final separator = Platform.pathSeparator;
    final stagingPath = '$_storageRoot$separator$sessionId.partial.m4a';
    final finalPath = '$_storageRoot$separator$sessionId.m4a';
    final request = MeetingCaptureRequest(
      sessionId: sessionId,
      stagingPath: stagingPath,
    );
    _draft = RecordingDraft(
      segments: [stagingPath],
      durationMs: 0,
      sessionId: sessionId,
      captureKind: RecordingCaptureKind.meeting,
      backend: _backend.backendId,
      stagingPath: stagingPath,
      finalPath: finalPath,
      codec: request.codec.wireName,
      state: RecordingDraftState.starting,
      heartbeatAt: timestamp,
    );
    await _draftsDao.saveTypedDraft(_draft!);

    try {
      await _startBackend(request);
      _startedAt = _now();
      _state = MeetingCaptureState.recording;
      await _saveDraft(state: RecordingDraftState.recording);
      _heartbeat = Timer.periodic(heartbeatInterval, (_) {
        if (_heartbeatInFlight != null) return;
        final tick = _heartbeatTick();
        _heartbeatInFlight = tick;
        unawaited(tick.whenComplete(() => _heartbeatInFlight = null));
      });
    } catch (_) {
      _state = MeetingCaptureState.failed;
      await _bestEffortBackendCancel();
      try {
        await _saveDraft(state: RecordingDraftState.failed);
      } catch (_) {
        // The starting draft remains the recovery anchor.
      }
      rethrow;
    }
  }

  Future<MeetingCaptureArtifact> stop() => _exclusive('stop', _stop);

  Future<MeetingCaptureArtifact> _stop() async {
    if (_state != MeetingCaptureState.recording || _draft == null) {
      throw StateError('No meeting capture is active');
    }
    _heartbeat?.cancel();
    _heartbeat = null;
    _state = MeetingCaptureState.finalizing;
    await _heartbeatInFlight;
    if (_state != MeetingCaptureState.finalizing || _draft == null) {
      throw StateError('Meeting capture ended while finalization was waiting');
    }
    await _saveDraft(state: RecordingDraftState.finalizing);

    try {
      final candidate = await _bounded('stop', _backend.stop());
      final draft = _draft!;
      if (candidate.path != draft.stagingPath ||
          !await _isOwnedRegularFile(candidate.path)) {
        throw const MeetingArtifactInvalidError(
          'Backend returned a file outside the owned staging path',
        );
      }
      final facts = await _inspectAndValidate(candidate.path);

      final finalPath = _expectedFinalPath(draft);
      final publishedFacts = await _publishArtifact(
        sourcePath: candidate.path,
        finalPath: finalPath,
        expectedFacts: facts,
      );
      _draft = draft.copyWith(
        segments: [finalPath],
        durationMs: publishedFacts.duration.inMilliseconds,
        state: RecordingDraftState.completed,
        heartbeatAt: _now().toUtc(),
      );
      await _draftsDao.saveTypedDraft(_draft!);
      _state = MeetingCaptureState.completed;
      return MeetingCaptureArtifact(
        sessionId: draft.sessionId,
        path: finalPath,
        facts: publishedFacts,
      );
    } catch (error) {
      _state = MeetingCaptureState.failed;
      if (error is MeetingCaptureTimeoutError && error.operation == 'stop') {
        await _bestEffortBackendCancel();
      }
      try {
        await _saveDraft(state: RecordingDraftState.failed);
      } catch (_) {
        // The finalizing draft remains the recovery anchor.
      }
      rethrow;
    }
  }

  /// Recover a killed/finalization-failed session. A decodable owned staging
  /// artifact is published to its final name; invalid owned files are removed.
  Future<MeetingCaptureArtifact?> recover() => _exclusive('recover', _recover);

  Future<MeetingCaptureArtifact?> _recover() async {
    if (_state != MeetingCaptureState.idle) {
      throw StateError('Cannot recover while meeting capture is active');
    }
    final draft = await _draftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    if (draft == null) return null;
    final directory = await _storageDirectory();
    await _pinStorageRoot(directory);
    _draft = draft;

    final candidates = <String>{
      if (draft.finalPath != null) draft.finalPath!,
      if (draft.stagingPath != null) draft.stagingPath!,
      ...draft.segments,
    }.where(_owns).toList(growable: false);
    String? candidate;
    MeetingArtifactFacts? facts;
    var sawTransientFailure = false;
    for (final path in candidates) {
      if (!await _isOwnedRegularFile(path)) continue;
      try {
        facts = await _inspectAndValidate(path);
        candidate = path;
        break;
      } on MeetingArtifactInvalidError {
        if (await _isOwnedRegularFile(path)) await File(path).delete();
      } catch (_) {
        sawTransientFailure = true;
      }
    }
    if (candidate == null) {
      if (!sawTransientFailure) {
        await _draftsDao.deleteDraft(captureKind: RecordingCaptureKind.meeting);
        _draft = null;
      } else {
        _state = MeetingCaptureState.idle;
      }
      return null;
    }

    final finalPath = _expectedFinalPath(draft);
    final publishedFacts = await _publishArtifact(
      sourcePath: candidate,
      finalPath: finalPath,
      expectedFacts: facts!,
    );
    _draft = draft.copyWith(
      segments: [finalPath],
      durationMs: publishedFacts.duration.inMilliseconds,
      state: RecordingDraftState.completed,
      heartbeatAt: _now().toUtc(),
    );
    await _draftsDao.saveTypedDraft(_draft!);
    for (final path in candidates.where((path) => path != finalPath)) {
      if (await _isOwnedRegularFile(path)) await File(path).delete();
    }
    _state = MeetingCaptureState.completed;
    return MeetingCaptureArtifact(
      sessionId: draft.sessionId,
      path: finalPath,
      facts: publishedFacts,
    );
  }

  /// Called only after the validated artifact, Item, file payload, and work row
  /// have committed together. A session mismatch cannot clear a newer draft.
  Future<void> acknowledgePersisted(String sessionId) async {
    final current = await _draftsDao.loadDraft(
      captureKind: RecordingCaptureKind.meeting,
    );
    if (current?.sessionId != sessionId ||
        current?.state != RecordingDraftState.completed) {
      return;
    }
    final deleted = await _draftsDao.deleteDraftIfSession(
      captureKind: RecordingCaptureKind.meeting,
      sessionId: sessionId,
      state: RecordingDraftState.completed,
    );
    if (deleted) {
      _draft = null;
      _startedAt = null;
      _state = MeetingCaptureState.idle;
    }
  }

  Future<void> discardRecovered() => _exclusive('discard-recovered', () async {
    final draft = _draft;
    if (_state != MeetingCaptureState.completed ||
        draft == null ||
        draft.state != RecordingDraftState.completed) {
      throw StateError('No recovered meeting artifact to discard');
    }
    final finalPath = _expectedFinalPath(draft);
    if (await _isOwnedRegularFile(finalPath)) await File(finalPath).delete();
    await _draftsDao.deleteDraftIfSession(
      captureKind: RecordingCaptureKind.meeting,
      sessionId: draft.sessionId,
      state: RecordingDraftState.completed,
    );
    _draft = null;
    _startedAt = null;
    _state = MeetingCaptureState.idle;
  });

  /// Re-inspect the published bytes immediately before local DB persistence.
  Future<void> validatePublishedArtifact(MeetingCaptureArtifact artifact) =>
      _exclusive('validate-published', () async {
        final draft = _draft;
        if (draft == null ||
            draft.sessionId != artifact.sessionId ||
            draft.finalPath != artifact.path ||
            !await _isOwnedRegularFile(artifact.path)) {
          throw const MeetingArtifactInvalidError(
            'Published artifact is no longer owned by this session',
          );
        }
        final current = await _inspectAndValidate(artifact.path);
        if (current.container != artifact.facts.container ||
            current.codec != artifact.facts.codec ||
            current.sampleRate != artifact.facts.sampleRate ||
            current.channels != artifact.facts.channels ||
            current.duration != artifact.facts.duration ||
            current.byteSize != artifact.facts.byteSize) {
          throw const MeetingArtifactInvalidError(
            'Published artifact changed after finalization',
          );
        }
      });

  Future<void> cancel() => _exclusive('cancel', () async {
    if (_state != MeetingCaptureState.recording) {
      throw StateError('No active meeting capture to cancel');
    }
    await _cancel(waitForHeartbeat: true);
  });

  Future<void> _cancel({required bool waitForHeartbeat}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (waitForHeartbeat) await _heartbeatInFlight;
    try {
      await _bounded('cancel', _backend.cancel());
    } catch (_) {
      _state = MeetingCaptureState.failed;
      await _saveDraft(state: RecordingDraftState.failed);
      rethrow;
    }

    final paths = _draft?.segments ?? const <String>[];
    for (final path in paths) {
      if (await _isOwnedRegularFile(path)) await File(path).delete();
    }
    await _draftsDao.deleteDraft(captureKind: RecordingCaptureKind.meeting);
    _draft = null;
    _startedAt = null;
    _state = MeetingCaptureState.cancelled;
  }

  Future<void> dispose() => _exclusive('dispose', _dispose);

  Future<void> _dispose() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _heartbeatInFlight;
    await _backendEvents.cancel();
    await _bounded('dispose', _backend.dispose());
  }

  void _handleBackendEvent(MeetingCaptureEvent event) {
    final terminal =
        event.state == MeetingCaptureState.failed ||
        (event.state == MeetingCaptureState.unavailable &&
            event.source != null);
    if (!terminal || _state != MeetingCaptureState.recording) return;
    unawaited(_failFromBackendEvent());
  }

  Future<void> _failFromBackendEvent() async {
    if (!_tryClaim('backend-event')) return;
    try {
      if (_state != MeetingCaptureState.recording) return;
      _heartbeat?.cancel();
      _heartbeat = null;
      _state = MeetingCaptureState.failed;
      await _bestEffortBackendCancel();
      try {
        await _saveDraft(state: RecordingDraftState.failed);
      } catch (_) {
        // The last recording heartbeat remains the recovery anchor.
      }
    } finally {
      _release('backend-event');
    }
  }

  Future<void> _heartbeatTick() async {
    try {
      if (_state != MeetingCaptureState.recording || _draft == null) return;
      final free = await _bounded(
        'storage-capacity',
        _availableBytes(_draft!.stagingPath!),
      );
      if (_state != MeetingCaptureState.recording || _draft == null) return;
      if (free != null && free < minimumAvailableBytes) {
        if (!_tryClaim('low-storage')) return;
        try {
          await _cancel(waitForHeartbeat: false);
        } finally {
          _release('low-storage');
        }
        return;
      }
      await _saveDraft(state: RecordingDraftState.recording);
    } catch (_) {
      if (_state != MeetingCaptureState.recording) return;
      _state = MeetingCaptureState.failed;
      await _bestEffortBackendCancel();
      try {
        await _saveDraft(state: RecordingDraftState.failed);
      } catch (_) {
        // The prior heartbeat remains a usable recovery anchor.
      }
    }
  }

  Future<void> _saveDraft({required RecordingDraftState state}) async {
    final draft = _draft;
    if (draft == null) return;
    final started = _startedAt;
    _draft = draft.copyWith(
      durationMs: started == null
          ? draft.durationMs
          : _now().difference(started).inMilliseconds,
      state: state,
      heartbeatAt: _now().toUtc(),
    );
    await _draftsDao.saveTypedDraft(_draft!);
  }

  void _validate(MeetingArtifactFacts facts) {
    if (!facts.decodable) {
      throw const MeetingArtifactInvalidError('Artifact is not decodable');
    }
    if (facts.container != MeetingContainer.m4a ||
        facts.codec != MeetingAudioCodec.aacLc ||
        facts.channels != 1 ||
        facts.sampleRate != 48000 ||
        facts.duration <= Duration.zero ||
        facts.byteSize <= 0) {
      throw const MeetingArtifactInvalidError(
        'Artifact does not match the M4A/AAC-LC mono capture contract',
      );
    }
  }

  Future<MeetingArtifactFacts> _inspectAndValidate(String path) async {
    if (!await _isOwnedRegularFile(path)) {
      throw const MeetingArtifactInvalidError(
        'Artifact is no longer an owned regular file',
      );
    }
    final facts = await _bounded('artifact-inspection', _inspectArtifact(path));
    _validate(facts);
    if (!await _isOwnedRegularFile(path)) {
      throw const MeetingArtifactInvalidError(
        'Artifact changed during inspection',
      );
    }
    final actualBytes = await File(path).length();
    if (facts.byteSize != actualBytes) {
      throw const MeetingArtifactInvalidError(
        'Inspected artifact size does not match the file',
      );
    }
    return facts;
  }

  bool _owns(String path) {
    final root = _storageRoot;
    final draft = _draft;
    if (root == null ||
        draft == null ||
        !RegExp(r'^meeting_[A-Za-z0-9_]+$').hasMatch(draft.sessionId)) {
      return false;
    }
    final staging = _expectedStagingPath(draft);
    final finalPath = _expectedFinalPath(draft);
    return path == staging || path == finalPath;
  }

  String _expectedStagingPath(RecordingDraft draft) =>
      '$_storageRoot${Platform.pathSeparator}${draft.sessionId}.partial.m4a';

  String _expectedFinalPath(RecordingDraft draft) =>
      '$_storageRoot${Platform.pathSeparator}${draft.sessionId}.m4a';

  Future<bool> _isOwnedRegularFile(String path) async {
    if (!_owns(path) || !await _storageRootIsPinned()) return false;
    return await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.file;
  }

  Future<void> _pinStorageRoot(Directory directory) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const MeetingStorageUnsafeError(
        'Meeting storage root must be a real directory',
      );
    }
    final canonical = await directory.resolveSymbolicLinks();
    _storageRoot = canonical;
    if (!await _storageRootIsPinned()) {
      _storageRoot = null;
      throw const MeetingStorageUnsafeError(
        'Meeting storage root could not be pinned safely',
      );
    }
  }

  Future<bool> _storageRootIsPinned() async {
    final root = _storageRoot;
    if (root == null ||
        await FileSystemEntity.type(root, followLinks: false) !=
            FileSystemEntityType.directory) {
      return false;
    }
    try {
      return await Directory(root).resolveSymbolicLinks() == root;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _flushFile(String path) async {
    if (!await _isOwnedRegularFile(path)) {
      throw const MeetingArtifactInvalidError(
        'Published artifact is no longer an owned regular file',
      );
    }
    final file = await File(path).open(mode: FileMode.append);
    try {
      await file.flush();
    } finally {
      await file.close();
    }
  }

  Future<MeetingArtifactFacts> _publishArtifact({
    required String sourcePath,
    required String finalPath,
    required MeetingArtifactFacts expectedFacts,
  }) async {
    if (!await _isOwnedRegularFile(sourcePath)) {
      throw const MeetingArtifactInvalidError(
        'Artifact source changed before publication',
      );
    }
    if (sourcePath != finalPath) {
      if (await FileSystemEntity.type(finalPath, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const MeetingArtifactInvalidError(
          'Final artifact destination already exists',
        );
      }
      if (!await _isOwnedRegularFile(sourcePath) ||
          !await _storageRootIsPinned()) {
        throw const MeetingArtifactInvalidError(
          'Artifact ownership changed before publication',
        );
      }
      await File(sourcePath).rename(finalPath);
    }
    await _flushFile(finalPath);
    await _bounded(
      'artifact-durability',
      _durabilityBarrier(_storageRoot!, finalPath),
    );
    final publishedFacts = await _inspectAndValidate(finalPath);
    if (!_sameFacts(expectedFacts, publishedFacts)) {
      throw const MeetingArtifactInvalidError(
        'Artifact changed during publication',
      );
    }
    return publishedFacts;
  }

  bool _sameFacts(MeetingArtifactFacts left, MeetingArtifactFacts right) =>
      left.decodable == right.decodable &&
      left.container == right.container &&
      left.codec == right.codec &&
      left.sampleRate == right.sampleRate &&
      left.channels == right.channels &&
      left.duration == right.duration &&
      left.byteSize == right.byteSize;

  Future<T> _exclusive<T>(String operation, Future<T> Function() body) async {
    _claim(operation);
    try {
      return await body();
    } finally {
      _release(operation);
    }
  }

  void _claim(String operation) {
    if (_operation != null) {
      throw StateError(
        'Meeting capture operation already running: $_operation',
      );
    }
    _operation = operation;
  }

  bool _tryClaim(String operation) {
    if (_operation != null) return false;
    _operation = operation;
    return true;
  }

  void _release(String operation) {
    if (_operation == operation) _operation = null;
  }

  Future<void> _bestEffortBackendCancel() async {
    try {
      await _backend.cancel().timeout(operationTimeout);
    } catch (_) {
      // The failed draft remains the recovery anchor.
    }
  }

  Future<void> _startBackend(MeetingCaptureRequest request) async {
    final pending = _backend.start(request);
    try {
      await pending.timeout(operationTimeout);
    } on TimeoutException {
      unawaited(
        pending.then<void>(
          (_) => _bestEffortBackendCancel(),
          onError: (_, _) {},
        ),
      );
      throw const MeetingCaptureTimeoutError('start');
    }
  }

  Future<T> _bounded<T>(String operation, Future<T> future) async {
    try {
      return await future.timeout(operationTimeout);
    } on TimeoutException {
      throw MeetingCaptureTimeoutError(operation);
    }
  }

  static final Random _random = Random();

  static String _randomSuffix(int length) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
