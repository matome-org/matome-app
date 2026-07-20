// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/daos/work_queue_dao.dart';
import '../http/api_client.dart';
import '../settings/settings_store.dart';
import 'product_event_reporter.dart';

enum DeviceQueueReportResult { reported, throttled, dropped }

/// Reports one bounded observation of the durable queue.
///
/// The projection is an egress boundary: only aggregate facts and reconciled
/// Core Item ids are serialized. Local ids, paths, names, content, lease owners,
/// raw errors, and key material never enter the request map.
class DeviceQueueReporter {
  DeviceQueueReporter({
    required AppDatabase database,
    required ApiClient apiClient,
    required SettingsStore settingsStore,
    required int Function() appliedConfigRevision,
    required Duration Function() reportingInterval,
    DateTime Function()? clock,
  }) : _database = database,
       _apiClient = apiClient,
       _settingsStore = settingsStore,
       _appliedConfigRevision = appliedConfigRevision,
       _reportingInterval = reportingInterval,
       _clock = clock ?? DateTime.now;

  static const sequenceSettingKey = 'matome.device_queue_report_sequence.v1';
  static const _maxItems = 100;
  static const _states = {'queued', 'running', 'retry', 'blocked', 'dead'};
  static const _stages = {
    kWorkStageReconcileParent,
    kWorkStageCreateRemote,
    kWorkStageHashFile,
    kWorkStageRequestUpload,
    kWorkStageUpload,
    kWorkStageUploadSingle,
    kWorkStageUploadParts,
    kWorkStageCompleteUpload,
    kWorkStageEnqueueProcessing,
    kWorkStageProcessingAccepted,
    kWorkStageUploadOnlyComplete,
  };
  static const _mediaTypes = {'audio', 'image', 'document', 'video'};
  static const _errorCodes = {
    kWorkErrorTransport,
    kWorkErrorTimeout,
    kWorkErrorRateLimited,
    kWorkErrorServerUnavailable,
    kWorkErrorUnauthorized,
    kWorkErrorContentRejected,
    kWorkErrorInvalidLocalData,
    kWorkErrorUnexpected,
  };

  final AppDatabase _database;
  final ApiClient _apiClient;
  final SettingsStore _settingsStore;
  final int Function() _appliedConfigRevision;
  final Duration Function() _reportingInterval;
  final DateTime Function() _clock;

  DateTime? _lastReportedAt;
  Future<DeviceQueueReportResult>? _activeReport;

  Future<DeviceQueueReportResult> report({bool force = false}) {
    final active = _activeReport;
    if (active != null) return active;

    late final Future<DeviceQueueReportResult> run;
    run = _report(force: force).whenComplete(() {
      if (identical(_activeReport, run)) _activeReport = null;
    });
    _activeReport = run;
    return run;
  }

  Future<DeviceQueueReportResult> _report({required bool force}) async {
    final now = _clock();
    final last = _lastReportedAt;
    if (!force && last != null && now.difference(last) < _reportingInterval()) {
      return DeviceQueueReportResult.throttled;
    }

    try {
      final snapshot = await _snapshot(now);
      final previous =
          int.tryParse(await _settingsStore.read(sequenceSettingKey) ?? '') ??
          0;
      final sequence = previous + 1;

      final response = await _apiClient.dio.post<void>(
        '/api/device/queue-snapshot',
        data: <String, Object?>{
          'contract_version': '1',
          'sequence': sequence,
          'applied_config_revision': _appliedConfigRevision(),
          'snapshot': snapshot,
        },
      );

      if (response.statusCode != 204) return DeviceQueueReportResult.dropped;
      await _settingsStore.write(sequenceSettingKey, sequence.toString());
      _lastReportedAt = now;
      return DeviceQueueReportResult.reported;
    } on DioException {
      return DeviceQueueReportResult.dropped;
    } on Object {
      return DeviceQueueReportResult.dropped;
    }
  }

  Future<Map<String, Object?>> _snapshot(DateTime now) async {
    final localSpaceIds =
        (await (_database.select(
              _database.workspaces,
            )..where((space) => space.isLocal.equals(1))).get())
            .map((row) => row.id)
            .toSet();
    final localMatomeIds =
        (await (_database.select(
              _database.matomes,
            )..where((matome) => matome.spaceId.isIn(localSpaceIds))).get())
            .map((row) => row.id)
            .toSet();

    final query =
        _database.select(_database.workQueue).join([
            innerJoin(
              _database.items,
              _database.items.id.equalsExp(_database.workQueue.itemId),
            ),
            leftOuterJoin(
              _database.fileBlobs,
              _database.fileBlobs.id.equalsExp(_database.items.fileBlobId),
            ),
          ])
          ..where(_database.workQueue.state.isNotIn([kWorkStateSucceeded]))
          ..orderBy([
            OrderingTerm.asc(_database.workQueue.createdAt),
            OrderingTerm.asc(_database.workQueue.id),
          ]);

    final general = <_QueueFact>[];
    final local = <_QueueFact>[];
    for (final joined in await query.get()) {
      final work = joined.readTable(_database.workQueue);
      final item = joined.readTable(_database.items);
      final file = joined.readTableOrNull(_database.fileBlobs);
      if (!_states.contains(work.state) || !_stages.contains(work.stage)) {
        continue;
      }

      final mediaType = file?.mediaType;
      final fact = _QueueFact(
        coreItemId: item.coreId,
        state: work.state,
        stage: work.stage,
        mediaType: _mediaTypes.contains(mediaType) ? mediaType : null,
        ageSeconds: _ageSeconds(now, work.createdAt),
        progress: work.progress.clamp(0, 1).toDouble(),
        errorCode: _errorCodes.contains(work.errorCode) ? work.errorCode : null,
      );

      final localSpace =
          (item.workspaceId != null &&
              localSpaceIds.contains(item.workspaceId)) ||
          (item.matomeId != null && localMatomeIds.contains(item.matomeId));
      (localSpace ? local : general).add(fact);
    }

    final snapshot = <String, Object?>{
      'counts': _counts(general, (fact) => fact.state),
      'stages': _counts(general, (fact) => fact.stage),
      'errors': _counts(
        general.where((fact) => fact.errorCode != null),
        (fact) => fact.errorCode!,
      ),
      'oldest_age_seconds': general.isEmpty
          ? null
          : general.map((fact) => fact.ageSeconds).reduce(_max),
      'progress': <String, Object?>{
        'average': general.isEmpty
            ? 0.0
            : _roundProgress(
                general.fold<double>(0, (sum, fact) => sum + fact.progress) /
                    general.length,
              ),
        'minimum': general.isEmpty
            ? 0.0
            : general.map((fact) => fact.progress).reduce(_min),
      },
      'items': general
          .where((fact) => fact.coreItemId != null && fact.mediaType != null)
          .take(_maxItems)
          .map(
            (fact) => <String, Object?>{
              'core_item_id': fact.coreItemId,
              'state': fact.state,
              'stage': fact.stage,
              'media_type': fact.mediaType,
              'age_seconds': fact.ageSeconds,
              'progress': fact.progress,
              'error_code': fact.errorCode,
            },
          )
          .toList(growable: false),
    };

    if (await _settingsStore.read(ProductEventReporter.optInSettingKey) ==
        'true') {
      snapshot['local_spaces'] = <String, Object?>{
        'work_count': local.length,
        'oldest_age_seconds': local.isEmpty
            ? null
            : local.map((fact) => fact.ageSeconds).reduce(_max),
      };
    }
    return snapshot;
  }

  static Map<String, int> _counts(
    Iterable<_QueueFact> facts,
    String Function(_QueueFact) key,
  ) {
    final counts = <String, int>{};
    for (final fact in facts) {
      counts.update(key(fact), (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static int _ageSeconds(DateTime now, int createdAt) =>
      ((now.millisecondsSinceEpoch - createdAt) ~/ 1000).clamp(0, 315360000);
  static double _roundProgress(double value) => (value * 1000).round() / 1000;
  static int _max(int left, int right) => left > right ? left : right;
  static double _min(double left, double right) => left < right ? left : right;
}

class _QueueFact {
  const _QueueFact({
    required this.coreItemId,
    required this.state,
    required this.stage,
    required this.mediaType,
    required this.ageSeconds,
    required this.progress,
    required this.errorCode,
  });

  final int? coreItemId;
  final String state;
  final String stage;
  final String? mediaType;
  final int ageSeconds;
  final double progress;
  final String? errorCode;
}
