import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'work_queue_dao.g.dart';

const String kWorkKindFileUpload = 'file_upload';

const String kWorkStateQueued = 'queued';
const String kWorkStateRunning = 'running';
const String kWorkStateRetry = 'retry';
const String kWorkStateBlocked = 'blocked';
const String kWorkStateSucceeded = 'succeeded';
const String kWorkStateDead = 'dead';

const String kWorkStageReconcileParent = 'reconcile_parent';
const String kWorkStageCreateRemote = 'create_remote';
const String kWorkStageHashFile = 'hash_file';
const String kWorkStageRequestUpload = 'request_upload';
const String kWorkStageUpload = 'upload';
const String kWorkStageUploadSingle = 'upload_single';
const String kWorkStageUploadParts = 'upload_parts';
const String kWorkStageCompleteUpload = 'complete_upload';
const String kWorkStageEnqueueProcessing = 'enqueue_processing';
const String kWorkStageProcessingAccepted = 'processing_accepted';
const String kWorkStageUploadOnlyComplete = 'upload_only_complete';

const String kWorkBlockSignedOut = 'signed_out';
const String kWorkBlockOffline = 'offline';
const String kWorkBlockLocalSpace = 'local_space';
const String kWorkBlockParent = 'parent';
const String kWorkBlockCore = 'core';

const String kWorkErrorTransport = 'transport';
const String kWorkErrorTimeout = 'timeout';
const String kWorkErrorRateLimited = 'rate_limited';
const String kWorkErrorServerUnavailable = 'server_unavailable';
const String kWorkErrorUnauthorized = 'unauthorized';
const String kWorkErrorContentRejected = 'content_rejected';
const String kWorkErrorInvalidLocalData = 'invalid_local_data';
const String kWorkErrorUnexpected = 'unexpected';

WorkQueueCompanion genericWork({
  required String id,
  required String kind,
  required String itemId,
  required String dedupeKey,
  required int now,
  String stage = kWorkStageReconcileParent,
  String? dependsOn,
  int configRevision = 0,
}) {
  return WorkQueueCompanion.insert(
    id: id,
    kind: kind,
    itemId: itemId,
    dedupeKey: dedupeKey,
    state: kWorkStateQueued,
    stage: stage,
    dependsOn: Value(dependsOn),
    availableAt: now,
    configRevision: Value(configRevision),
    createdAt: now,
    updatedAt: now,
  );
}

WorkQueueCompanion fileUploadWork({
  required String itemId,
  required int sourceRevision,
  required int now,
  int configRevision = 0,
  String stage = kWorkStageReconcileParent,
  String? dependsOn,
  String? dedupeKey,
}) {
  final key = dedupeKey ?? '$itemId:$kWorkKindFileUpload:$sourceRevision';
  return genericWork(
    id: 'work:$key',
    kind: kWorkKindFileUpload,
    itemId: itemId,
    dedupeKey: key,
    now: now,
    stage: stage,
    dependsOn: dependsOn,
    configRevision: configRevision,
  );
}

@DriftAccessor(tables: [WorkQueue, Items])
class WorkQueueDao extends DatabaseAccessor<AppDatabase>
    with _$WorkQueueDaoMixin {
  WorkQueueDao(super.db);

  Future<void> enqueue(WorkQueueCompanion work) => into(workQueue).insert(work);

  Future<void> enqueueOrIgnore(WorkQueueCompanion work) =>
      into(workQueue).insert(work, mode: InsertMode.insertOrIgnore);

  Future<WorkQueueRow?> getForItem(String itemId, String kind) {
    return (select(workQueue)
          ..where((row) => row.itemId.equals(itemId) & row.kind.equals(kind)))
        .getSingleOrNull();
  }

  Future<List<WorkQueueRow>> listAll() => (select(
    workQueue,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();

  Future<void> prepareDrain({required int now, required int configRevision}) {
    return transaction(() async {
      await _recoverExpired(now);
      await (update(workQueue)..where(
            (row) =>
                row.configRevision.isNotValue(configRevision) &
                row.state.isNotIn([
                  kWorkStateRunning,
                  kWorkStateSucceeded,
                  kWorkStateDead,
                ]),
          ))
          .write(
            WorkQueueCompanion(
              state: const Value(kWorkStateQueued),
              attempt: const Value(0),
              availableAt: Value(now),
              leaseOwner: const Value(null),
              leaseUntil: const Value(null),
              errorCode: const Value(null),
              blockedReason: const Value(null),
              configRevision: Value(configRevision),
              updatedAt: Value(now),
            ),
          );
    });
  }

  Future<WorkQueueRow?> claimNext({
    required String leaseOwner,
    required int now,
    required Duration leaseDuration,
    Set<String> excludedIds = const {},
    Set<String> kinds = const {},
  }) {
    return transaction(() async {
      await _recoverExpired(now);
      final query = select(workQueue)
        ..where(
          (row) =>
              row.state.isIn([
                kWorkStateQueued,
                kWorkStateRetry,
                kWorkStateBlocked,
              ]) &
              row.availableAt.isSmallerOrEqualValue(now) &
              (kinds.isEmpty ? const Constant(true) : row.kind.isIn(kinds)) &
              (excludedIds.isEmpty
                  ? const Constant(true)
                  : row.id.isNotIn(excludedIds)),
        )
        ..orderBy([
          (row) => OrderingTerm.asc(row.availableAt),
          (row) => OrderingTerm.asc(row.updatedAt),
          (row) => OrderingTerm.asc(row.id),
        ]);

      for (final candidate in await query.get()) {
        final dependencyId = candidate.dependsOn;
        if (dependencyId != null) {
          final dependency = await (select(
            workQueue,
          )..where((row) => row.id.equals(dependencyId))).getSingleOrNull();
          if (dependency?.state != kWorkStateSucceeded) continue;
        }
        final changed =
            await (update(workQueue)..where(
                  (row) =>
                      row.id.equals(candidate.id) &
                      row.state.isIn([
                        kWorkStateQueued,
                        kWorkStateRetry,
                        kWorkStateBlocked,
                      ]),
                ))
                .write(
                  WorkQueueCompanion(
                    state: const Value(kWorkStateRunning),
                    leaseOwner: Value(leaseOwner),
                    leaseUntil: Value(now + leaseDuration.inMilliseconds),
                    blockedReason: const Value(null),
                    updatedAt: Value(now),
                  ),
                );
        if (changed == 1) {
          return (select(
            workQueue,
          )..where((row) => row.id.equals(candidate.id))).getSingle();
        }
      }
      return null;
    });
  }

  Future<bool> advance(
    String id, {
    required String leaseOwner,
    required String stage,
    required double progress,
    required int now,
  }) async {
    final changed =
        await (update(
          workQueue,
        )..where((row) => _owned(row, id, leaseOwner, now))).write(
          WorkQueueCompanion(
            stage: Value(stage),
            progress: Value(progress),
            errorCode: const Value(null),
            blockedReason: const Value(null),
            updatedAt: Value(now),
          ),
        );
    return changed == 1;
  }

  Future<bool> renew(
    String id, {
    required String leaseOwner,
    required int now,
    required Duration leaseDuration,
  }) async {
    final changed =
        await (update(
          workQueue,
        )..where((row) => _owned(row, id, leaseOwner, now))).write(
          WorkQueueCompanion(
            leaseUntil: Value(now + leaseDuration.inMilliseconds),
            updatedAt: Value(now),
          ),
        );
    return changed == 1;
  }

  Future<bool> complete(
    String id, {
    required String leaseOwner,
    required int now,
  }) async {
    final changed =
        await (update(
          workQueue,
        )..where((row) => _owned(row, id, leaseOwner, now))).write(
          WorkQueueCompanion(
            state: const Value(kWorkStateSucceeded),
            progress: const Value(1),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            errorCode: const Value(null),
            blockedReason: const Value(null),
            updatedAt: Value(now),
          ),
        );
    return changed == 1;
  }

  Future<bool> completeProcessingAccepted(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
    required String processingState,
    required String? processingRunId,
    required int processingAttempt,
    required Iterable<String> processingRequestedOutputs,
  }) {
    return transaction(() async {
      final changed =
          await (update(
            workQueue,
          )..where((row) => _owned(row, id, leaseOwner, now))).write(
            WorkQueueCompanion(
              state: const Value(kWorkStateSucceeded),
              stage: const Value(kWorkStageProcessingAccepted),
              progress: const Value(1),
              leaseOwner: const Value(null),
              leaseUntil: const Value(null),
              errorCode: const Value(null),
              blockedReason: const Value(null),
              updatedAt: Value(now),
            ),
          );
      if (changed != 1) return false;
      final itemChanged =
          await (update(items)..where(
                (item) => item.id.equals(itemId) & item.ownerId.equals(ownerId),
              ))
              .write(
                ItemsCompanion(
                  processingState: Value(processingState),
                  processingRunId: Value(processingRunId),
                  processingAttempt: Value(processingAttempt),
                  processingRequestedOutputs: Value(
                    jsonEncode(processingRequestedOutputs.toList()),
                  ),
                  processingError: const Value(null),
                  processingErrorCode: const Value(null),
                  syncState: const Value('synced'),
                  isDirty: const Value(false),
                ),
              );
      if (itemChanged != 1) {
        throw StateError('Accepted work references a missing Item');
      }
      return true;
    });
  }

  Future<bool> completeUploadOnly(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
  }) {
    return transaction(() async {
      final changed =
          await (update(
            workQueue,
          )..where((row) => _owned(row, id, leaseOwner, now))).write(
            WorkQueueCompanion(
              state: const Value(kWorkStateSucceeded),
              stage: const Value(kWorkStageUploadOnlyComplete),
              progress: const Value(1),
              leaseOwner: const Value(null),
              leaseUntil: const Value(null),
              errorCode: const Value(null),
              blockedReason: const Value(null),
              updatedAt: Value(now),
            ),
          );
      if (changed != 1) return false;
      final itemChanged =
          await (update(items)..where(
                (item) => item.id.equals(itemId) & item.ownerId.equals(ownerId),
              ))
              .write(
                const ItemsCompanion(
                  processingState: Value('not_requested'),
                  syncState: Value('uploaded'),
                  processingErrorCode: Value(null),
                  isDirty: Value(false),
                ),
              );
      if (itemChanged != 1) {
        throw StateError('Completed upload work references a missing Item');
      }
      return true;
    });
  }

  Future<bool> block(
    String id, {
    required String leaseOwner,
    required String reason,
    String? errorCode,
    required int now,
  }) async {
    final changed =
        await (update(
          workQueue,
        )..where((row) => _owned(row, id, leaseOwner, now))).write(
          WorkQueueCompanion(
            state: const Value(kWorkStateBlocked),
            availableAt: Value(now),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            errorCode: Value(errorCode),
            blockedReason: Value(reason),
            updatedAt: Value(now),
          ),
        );
    return changed == 1;
  }

  Future<bool> retry(
    String id, {
    required String leaseOwner,
    required String errorCode,
    String? blockedReason,
    required int availableAt,
    required int maxAttempts,
    required int now,
  }) async {
    final current = await (select(
      workQueue,
    )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
    if (current == null) return false;
    final nextAttempt = current.attempt + 1;
    final dead = nextAttempt >= maxAttempts;
    final changed =
        await (update(
          workQueue,
        )..where((row) => _owned(row, id, leaseOwner, now))).write(
          WorkQueueCompanion(
            state: Value(dead ? kWorkStateDead : kWorkStateRetry),
            attempt: Value(nextAttempt),
            availableAt: Value(availableAt),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            errorCode: Value(errorCode),
            blockedReason: Value(blockedReason),
            updatedAt: Value(now),
          ),
        );
    return changed == 1;
  }

  Future<void> resetForManualRetry(String itemId, int now) async {
    await (update(workQueue)..where(
          (row) =>
              row.itemId.equals(itemId) & row.kind.equals(kWorkKindFileUpload),
        ))
        .write(
          WorkQueueCompanion(
            state: const Value(kWorkStateQueued),
            attempt: const Value(0),
            availableAt: Value(now),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            errorCode: const Value(null),
            blockedReason: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> makeDue(String kind, int now) async {
    await (update(workQueue)..where(
          (row) =>
              row.kind.equals(kind) &
              row.state.isIn([kWorkStateRetry, kWorkStateBlocked]),
        ))
        .write(
          WorkQueueCompanion(
            state: const Value(kWorkStateQueued),
            availableAt: Value(now),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _recoverExpired(int now) {
    return (update(workQueue)..where(
          (row) =>
              row.state.equals(kWorkStateRunning) &
              row.leaseUntil.isSmallerOrEqualValue(now),
        ))
        .write(
          WorkQueueCompanion(
            state: const Value(kWorkStateQueued),
            availableAt: Value(now),
            leaseOwner: const Value(null),
            leaseUntil: const Value(null),
            updatedAt: Value(now),
          ),
        );
  }

  Expression<bool> _owned(
    $WorkQueueTable row,
    String id,
    String owner,
    int now,
  ) {
    return row.id.equals(id) &
        row.state.equals(kWorkStateRunning) &
        row.leaseOwner.equals(owner) &
        row.leaseUntil.isBiggerThanValue(now);
  }
}
