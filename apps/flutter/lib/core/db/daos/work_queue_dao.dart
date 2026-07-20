import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'work_queue_dao.g.dart';

const String kWorkKindFileUpload = 'file_upload';
const String kWorkKindFileDelete = 'file_delete';
const String kWorkKindTextCreate = 'text_create';
const String kWorkKindTextUpdate = 'text_update';
const String kWorkKindTextDelete = 'text_delete';
const String kWorkKindTextProcess = 'text_process';

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
const String kWorkStagePrepareDelete = 'prepare_delete';
const String kWorkStageDeleteRemote = 'delete_remote';
const String kWorkStageDeleteCiphertext = 'delete_ciphertext';
const String kWorkStageDeleteMetadata = 'delete_metadata';

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
const String kWorkErrorVersionConflict = 'version_conflict';

WorkQueueCompanion genericWork({
  required String id,
  required String kind,
  required String itemId,
  required String dedupeKey,
  required int now,
  String? blobId,
  int? blobRevision,
  String stage = kWorkStageReconcileParent,
  String? dependsOn,
  int configRevision = 0,
}) {
  return WorkQueueCompanion.insert(
    id: id,
    kind: kind,
    itemId: itemId,
    blobId: Value(blobId),
    blobRevision: Value(blobRevision),
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
  required String blobId,
  required int blobRevision,
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
    blobId: blobId,
    blobRevision: blobRevision,
    dedupeKey: key,
    now: now,
    stage: stage,
    dependsOn: dependsOn,
    configRevision: configRevision,
  );
}

WorkQueueCompanion fileDeleteWork({
  required String itemId,
  required String blobId,
  required int now,
}) => genericWork(
  id: 'work:$itemId:$kWorkKindFileDelete',
  kind: kWorkKindFileDelete,
  itemId: itemId,
  blobId: blobId,
  dedupeKey: '$itemId:$kWorkKindFileDelete',
  now: now,
  stage: kWorkStagePrepareDelete,
);

WorkQueueCompanion textWork({
  required String kind,
  required String itemId,
  required int submittedSourceRevision,
  required int expectedSourceRevision,
  required int now,
  required int configRevision,
  String? operationBody,
  String stage = kWorkStageReconcileParent,
  String? dependsOn,
}) {
  final key = '$itemId:$kind:$submittedSourceRevision';
  return genericWork(
    id: 'work:$key',
    kind: kind,
    itemId: itemId,
    dedupeKey: key,
    now: now,
    stage: stage,
    dependsOn: dependsOn,
    configRevision: configRevision,
  ).copyWith(
    operationBody: Value(operationBody),
    submittedSourceRevision: Value(submittedSourceRevision),
    expectedSourceRevision: Value(expectedSourceRevision),
  );
}

class TextWorkCompletion {
  const TextWorkCompletion({required this.appliedToCurrent});

  final bool appliedToCurrent;
}

@DriftAccessor(tables: [WorkQueue, Items, TextContents, ItemContacts])
class WorkQueueDao extends DatabaseAccessor<AppDatabase>
    with _$WorkQueueDaoMixin {
  WorkQueueDao(super.db);

  Future<void> enqueue({
    required String ownerId,
    required WorkQueueCompanion work,
  }) => _enqueueForOwner(ownerId, work);

  Future<void> enqueueOrIgnore({
    required String ownerId,
    required WorkQueueCompanion work,
  }) => _enqueueForOwner(ownerId, work, mode: InsertMode.insertOrIgnore);

  Future<WorkQueueRow?> getForItem(String itemId, String kind) {
    return (select(workQueue)
          ..where((row) => row.itemId.equals(itemId) & row.kind.equals(kind))
          ..orderBy([
            (row) => OrderingTerm.desc(row.submittedSourceRevision),
            (row) => OrderingTerm.desc(row.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WorkQueueRow?> getById(String id) =>
      (select(workQueue)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<List<WorkQueueRow>> listAll() => (select(
    workQueue,
  )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();

  Future<void> prepareDrain({
    required String ownerId,
    required int now,
    required int configRevision,
  }) {
    return transaction(() async {
      await _recoverExpired(now, ownerId);
      await (update(workQueue)..where(
            (row) =>
                _belongsToOwner(row, ownerId) &
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
    required String ownerId,
    required String leaseOwner,
    required int now,
    required Duration leaseDuration,
    Set<String> excludedIds = const {},
    Set<String> kinds = const {},
  }) {
    return transaction(() async {
      await _recoverExpired(now, ownerId);
      final query =
          select(
              workQueue,
            ).join([innerJoin(items, items.id.equalsExp(workQueue.itemId))])
            ..where(
              items.ownerId.equals(ownerId) &
                  workQueue.state.isIn([
                    kWorkStateQueued,
                    kWorkStateRetry,
                    kWorkStateBlocked,
                  ]) &
                  workQueue.availableAt.isSmallerOrEqualValue(now) &
                  (kinds.isEmpty
                      ? const Constant(true)
                      : workQueue.kind.isIn(kinds)) &
                  (excludedIds.isEmpty
                      ? const Constant(true)
                      : workQueue.id.isNotIn(excludedIds)),
            )
            ..orderBy([
              OrderingTerm.asc(workQueue.availableAt),
              OrderingTerm.asc(workQueue.updatedAt),
              OrderingTerm.asc(workQueue.id),
            ]);

      for (final result in await query.get()) {
        final candidate = result.readTable(workQueue);
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
                      _belongsToOwner(row, ownerId) &
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

  // These transitions intentionally use an id-and-lease CAS instead of another
  // Item owner join. Only owner-scoped claimNext can issue the active lease
  // tuple, so possession of that tuple is the mutation authority.
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

  Future<bool> completeTextDelete(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
  }) {
    return transaction(() async {
      final owned = await (select(
        workQueue,
      )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
      if (owned == null) return false;
      final item =
          await (select(items)..where(
                (row) => row.id.equals(itemId) & row.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (item == null) return false;
      await (delete(
        itemContacts,
      )..where((row) => row.itemId.equals(itemId))).go();
      await (delete(items)..where((row) => row.id.equals(itemId))).go();
      if (item.textContentId != null) {
        await (delete(
          textContents,
        )..where((row) => row.id.equals(item.textContentId!))).go();
      }
      await (delete(workQueue)..where((row) => row.itemId.equals(itemId))).go();
      return true;
    });
  }

  Future<TextWorkCompletion?> completeTextMutation(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
    required int remoteId,
    required int remoteSourceRevision,
    required String remoteBody,
    required int configRevision,
  }) {
    return transaction(() async {
      final work = await (select(
        workQueue,
      )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
      final submittedRevision = work?.submittedSourceRevision;
      final submittedBody = work?.operationBody;
      if (work == null || submittedRevision == null || submittedBody == null) {
        return null;
      }
      final item =
          await (select(items)..where(
                (row) => row.id.equals(itemId) & row.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (item == null || item.textContentId == null) return null;
      final text = await (select(
        textContents,
      )..where((row) => row.id.equals(item.textContentId!))).getSingleOrNull();
      if (text == null) return null;

      final appliedToCurrent =
          !item.isDeleted &&
          item.sourceRevision == submittedRevision &&
          text.body == submittedBody &&
          remoteBody == submittedBody;
      await (update(items)..where((row) => row.id.equals(itemId))).write(
        ItemsCompanion(
          coreId: Value(remoteId),
          acceptedSourceRevision: Value(remoteSourceRevision),
          sourceRevision: appliedToCurrent
              ? Value(remoteSourceRevision)
              : const Value.absent(),
          syncState: Value(
            item.isDeleted
                ? 'pending_delete'
                : (appliedToCurrent ? 'synced' : 'pending_sync'),
          ),
          isDirty: Value(!appliedToCurrent || item.isDeleted),
          updatedAt: Value(now),
        ),
      );
      await (update(
        textContents,
      )..where((row) => row.id.equals(text.id))).write(
        TextContentsCompanion(
          coreId: Value(remoteId),
          acceptedBody: Value(remoteBody),
          isDirty: Value(!appliedToCurrent || item.isDeleted),
          updatedAt: Value(now),
        ),
      );
      await _markSucceeded(work.id, leaseOwner: leaseOwner, now: now);
      if (appliedToCurrent) {
        await into(workQueue).insert(
          textWork(
            kind: kWorkKindTextProcess,
            itemId: itemId,
            submittedSourceRevision: remoteSourceRevision,
            expectedSourceRevision: remoteSourceRevision,
            operationBody: remoteBody,
            now: now,
            configRevision: configRevision,
            stage: kWorkStageEnqueueProcessing,
            dependsOn: work.id,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      return TextWorkCompletion(appliedToCurrent: appliedToCurrent);
    });
  }

  Future<bool> completeTextProcessingAccepted(
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
      final work = await (select(
        workQueue,
      )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
      if (work == null || work.submittedSourceRevision == null) return false;
      final item =
          await (select(items)..where(
                (row) => row.id.equals(itemId) & row.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (item == null) return false;
      await _markSucceeded(work.id, leaseOwner: leaseOwner, now: now);
      if (item.isDeleted ||
          item.isDirty ||
          item.sourceRevision != work.submittedSourceRevision ||
          item.acceptedSourceRevision != work.submittedSourceRevision) {
        return true;
      }
      await (update(items)..where((row) => row.id.equals(itemId))).write(
        ItemsCompanion(
          processingState: Value(processingState),
          processingRunId: Value(processingRunId),
          processingAttempt: Value(processingAttempt),
          processingRequestedOutputs: Value(
            jsonEncode(processingRequestedOutputs.toList()),
          ),
          processingError: const Value(null),
          processingErrorCode: const Value(null),
        ),
      );
      return true;
    });
  }

  Future<bool> reconcileTextClientConflict(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
    required int remoteId,
    required int remoteSourceRevision,
    required String remoteBody,
    required int configRevision,
  }) {
    return transaction(() async {
      final work = await (select(
        workQueue,
      )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
      final item =
          await (select(items)..where(
                (row) => row.id.equals(itemId) & row.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (work == null || item == null || item.textContentId == null) {
        return false;
      }
      final text = await (select(
        textContents,
      )..where((row) => row.id.equals(item.textContentId!))).getSingleOrNull();
      if (text == null) return false;
      final nextRevision = item.sourceRevision > remoteSourceRevision
          ? item.sourceRevision
          : remoteSourceRevision + 1;
      await (update(items)..where((row) => row.id.equals(itemId))).write(
        ItemsCompanion(
          coreId: Value(remoteId),
          acceptedSourceRevision: Value(remoteSourceRevision),
          sourceRevision: Value(nextRevision),
          syncState: const Value('pending_sync'),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await (update(
        textContents,
      )..where((row) => row.id.equals(text.id))).write(
        TextContentsCompanion(
          coreId: Value(remoteId),
          acceptedBody: Value(remoteBody),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _markSucceeded(work.id, leaseOwner: leaseOwner, now: now);
      await into(workQueue).insert(
        textWork(
          kind: kWorkKindTextUpdate,
          itemId: itemId,
          submittedSourceRevision: nextRevision,
          expectedSourceRevision: remoteSourceRevision,
          operationBody: text.body,
          now: now,
          configRevision: configRevision,
          stage: kWorkStageCreateRemote,
          dependsOn: work.id,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return true;
    });
  }

  Future<bool> restoreTextDeleteConflict(
    String id, {
    required String itemId,
    required String ownerId,
    required String leaseOwner,
    required int now,
    required int remoteId,
    required int remoteSourceRevision,
    required String remoteBody,
  }) {
    return transaction(() async {
      final work = await (select(
        workQueue,
      )..where((row) => _owned(row, id, leaseOwner, now))).getSingleOrNull();
      final item =
          await (select(items)..where(
                (row) => row.id.equals(itemId) & row.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (work == null || item == null || item.textContentId == null) {
        return false;
      }
      final text = await (select(
        textContents,
      )..where((row) => row.id.equals(item.textContentId!))).getSingleOrNull();
      if (text == null) return false;
      await (update(items)..where((row) => row.id.equals(itemId))).write(
        ItemsCompanion(
          coreId: Value(remoteId),
          acceptedSourceRevision: Value(remoteSourceRevision),
          sourceRevision: Value(
            item.sourceRevision > remoteSourceRevision
                ? item.sourceRevision
                : remoteSourceRevision,
          ),
          isDeleted: const Value(false),
          syncState: const Value('conflict'),
          isDirty: Value(text.body != remoteBody),
          processingErrorCode: const Value(kWorkErrorVersionConflict),
          updatedAt: Value(now),
        ),
      );
      await (update(
        textContents,
      )..where((row) => row.id.equals(text.id))).write(
        TextContentsCompanion(
          coreId: Value(remoteId),
          acceptedBody: Value(remoteBody),
          isDirty: Value(text.body != remoteBody),
          updatedAt: Value(now),
        ),
      );
      await (delete(workQueue)..where((row) => row.id.equals(id))).go();
      return true;
    });
  }

  Future<bool> _markSucceeded(
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

  Future<void> resetForManualRetry({
    required String ownerId,
    required String itemId,
    required int now,
  }) async {
    await (update(workQueue)..where(
          (row) =>
              _belongsToOwner(row, ownerId) &
              row.itemId.equals(itemId) &
              row.state.isIn([
                kWorkStateDead,
                kWorkStateRetry,
                kWorkStateBlocked,
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
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> makeDue({
    required String ownerId,
    required String kind,
    required int now,
  }) async {
    await (update(workQueue)..where(
          (row) =>
              _belongsToOwner(row, ownerId) &
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

  Future<void> _recoverExpired(int now, String ownerId) {
    return (update(workQueue)..where(
          (row) =>
              _belongsToOwner(row, ownerId) &
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

  Future<void> _enqueueForOwner(
    String ownerId,
    WorkQueueCompanion work, {
    InsertMode? mode,
  }) {
    return transaction(() async {
      final itemId = work.itemId.value;
      final item =
          await (selectOnly(items)
                ..addColumns([items.id])
                ..where(
                  items.id.equals(itemId) & items.ownerId.equals(ownerId),
                ))
              .getSingleOrNull();
      if (item == null) return;
      await into(workQueue).insert(work, mode: mode);
    });
  }

  Expression<bool> _belongsToOwner($WorkQueueTable row, String ownerId) {
    final ownedItemIds = selectOnly(items)
      ..addColumns([items.id])
      ..where(items.ownerId.equals(ownerId));
    return row.itemId.isInQuery(ownedItemIds);
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
