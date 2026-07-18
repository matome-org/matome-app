import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/items/matome_item_type.dart';
import '../../../features/matome/matome_ids.dart';
import '../../../features/recordings/recording_ids.dart'
    show kLocalRecordingIdPrefix, kUploadQueuePendingStatuses;
import '../../../features/recordings/recording.dart';
import '../app_database.dart';
import 'work_queue_dao.dart';
import '../file_row.dart';
import '../tables.dart';

part 'items_dao.g.dart';

const int _kMsPerDay = 24 * 60 * 60 * 1000;

/// One canonical Item joined to exactly one payload row.
class ItemWithPayload {
  const ItemWithPayload({
    required this.item,
    required this.type,
    this.file,
    this.text,
  });

  final ItemRow item;
  final MatomeItemType type;
  final FileBlobRow? file;
  final TextContentRow? text;

  String get id => item.id;
  int? get coreId => item.coreId;
  String get ownerId => item.ownerId;
  String? get workspaceId => item.workspaceId;
  String? get matomeId => item.matomeId;
  String get title => item.title;
  String? get notes => item.notes;
  int get createdAt => item.createdAt;
  String get mediaType => file?.mediaType ?? 'text';
  int? get durationSeconds => file?.duration;
  String? get localPath => file?.localPath;
  String? get wrappedFek => file?.wrappedFek;
  String? get fileNoncePrefix => file?.fileNoncePrefix;
  int? get byteSize => file?.byteSize;
  String? get originalExtension => file?.originalExtension;

  bool get isProcessing =>
      item.processingState == 'queued' || item.processingState == 'processing';

  ProcessingState get processingState =>
      ProcessingState.fromWire(item.processingState);

  String get processingStatus {
    if (kUploadQueuePendingStatuses.contains(item.syncState) ||
        item.syncState.startsWith('blocked_')) {
      return item.syncState;
    }
    return switch (item.processingState) {
      'not_requested' => 'not_requested',
      'not_available' => 'not_available',
      'queued' => 'queued',
      'processing' => 'processing',
      'succeeded' => 'succeeded',
      'partial' => 'partial',
      'failed' => 'failed',
      _ => 'not_requested',
    };
  }

  ProcessingOutputs get processingOutputs {
    try {
      return ProcessingOutputs.fromJson(jsonDecode(item.processingOutputs));
    } on FormatException {
      return const ProcessingOutputs.empty();
    }
  }

  String? get summary => processingOutputs.summary?.markdown;
  String? get transcript => processingOutputs.transcript?.text;
  String? get description => processingOutputs.description?.text;
  String? get ocrText => processingOutputs.ocrText?.text;
  String? get extractedText => processingOutputs.extractedText?.text;
  String? get processingErrorCode => item.processingErrorCode;
}

class ItemWithWorkspace {
  const ItemWithWorkspace(this.item, this.workspaceName);

  final ItemWithPayload item;
  final String? workspaceName;
}

@DriftAccessor(
  tables: [
    Items,
    FileBlobs,
    TextContents,
    Workspaces,
    Matomes,
    MatomeContacts,
    Contacts,
    ItemContacts,
    WorkQueue,
  ],
)
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Future<void> createFileItem({
    required ItemsCompanion item,
    required FileBlobsCompanion file,
    WorkQueueCompanion? initialWork,
  }) {
    _requirePayloadArc(item, MatomeItemType.file);
    return transaction(() async {
      await into(fileBlobs).insert(file);
      await into(items).insert(await _normalizePlacement(item));
      if (initialWork != null) await into(workQueue).insert(initialWork);
    });
  }

  Future<void> createTextItem({
    required ItemsCompanion item,
    required TextContentsCompanion text,
    WorkQueueCompanion? initialWork,
  }) {
    _requirePayloadArc(item, MatomeItemType.text);
    return transaction(() async {
      await into(textContents).insert(text);
      await into(items).insert(await _normalizePlacement(item));
      if (initialWork != null) await into(workQueue).insert(initialWork);
    });
  }

  Future<void> upsertTextItem({
    required ItemsCompanion item,
    required TextContentsCompanion text,
  }) {
    _requirePayloadArc(item, MatomeItemType.text);
    return transaction(() async {
      await into(textContents).insertOnConflictUpdate(text);
      await into(items).insertOnConflictUpdate(await _normalizePlacement(item));
    });
  }

  Future<void> upsertFileItem({
    required ItemsCompanion item,
    required FileBlobsCompanion file,
    bool ensureMatome = false,
    WorkQueueCompanion? initialWork,
  }) {
    _requirePayloadArc(item, MatomeItemType.file);
    return transaction(() async {
      var normalized = item;
      if (ensureMatome &&
          (!normalized.matomeId.present || normalized.matomeId.value == null)) {
        final existing = await _itemById(
          normalized.id.value,
          normalized.ownerId.value,
        );
        if (existing?.matomeId != null) {
          normalized = normalized.copyWith(matomeId: Value(existing!.matomeId));
        } else {
          final matomeId = mintLocalMatomeId();
          final createdAt = normalized.createdAt.value;
          await into(matomes).insert(
            MatomesCompanion.insert(
              id: matomeId,
              spaceId: normalized.workspaceId.present
                  ? Value(normalized.workspaceId.value)
                  : const Value(null),
              title: normalized.title.present
                  ? normalized.title.value
                  : 'Untitled',
              happenedAt: createdAt,
              createdAt: createdAt,
            ),
          );
          normalized = normalized.copyWith(
            matomeId: Value(matomeId),
            position: const Value(0),
          );
        }
      }
      await into(fileBlobs).insertOnConflictUpdate(file);
      await into(
        items,
      ).insertOnConflictUpdate(await _normalizePlacement(normalized));
      if (initialWork != null) {
        await into(workQueue).insert(initialWork);
      }
      final matomeId = normalized.matomeId.present
          ? normalized.matomeId.value
          : null;
      if (matomeId != null) await _markMatomeSummaryStale(matomeId);
    });
  }

  Future<List<ItemWithPayload>> listAll(String ownerId) => _joined(
    ownerId: ownerId,
    orderNewestFirst: true,
  ).map(_rowWithPayload).get();

  Future<List<ItemWithPayload>> listInbox(String ownerId) {
    return _joined(
      ownerId: ownerId,
      extraWhere: items.workspaceId.isNull(),
      orderNewestFirst: true,
    ).map(_rowWithPayload).get();
  }

  Future<List<ItemWithPayload>> listLoose(String ownerId) {
    return _joined(
      ownerId: ownerId,
      extraWhere: items.matomeId.isNull() & items.workspaceId.isNull(),
      orderNewestFirst: true,
    ).map(_rowWithPayload).get();
  }

  Future<List<ItemWithPayload>> listForMatome(String matomeId, String ownerId) {
    return _joined(
      ownerId: ownerId,
      extraWhere: items.matomeId.equals(matomeId),
      orderByPosition: true,
    ).map(_rowWithPayload).get();
  }

  Future<List<ItemWithPayload>> listForSpace(
    String workspaceId,
    String ownerId,
  ) {
    return _joined(
      ownerId: ownerId,
      extraWhere: items.workspaceId.equals(workspaceId),
      orderNewestFirst: true,
    ).map(_rowWithPayload).get();
  }

  Future<ItemWithPayload?> getById(String itemId, String ownerId) async {
    final row = await _joined(
      ownerId: ownerId,
      extraWhere: items.id.equals(itemId),
      includeDeleted: true,
    ).getSingleOrNull();
    return row == null ? null : _rowWithPayload(row);
  }

  Future<ItemWithPayload?> getByCoreId(int coreId, String ownerId) async {
    final row = await (_joined(
      ownerId: ownerId,
      extraWhere: items.coreId.equals(coreId),
      orderNewestFirst: true,
      includeDeleted: true,
    )..limit(1)).getSingleOrNull();
    return row == null ? null : _rowWithPayload(row);
  }

  Future<ItemWithPayload?> getByClientId(
    String clientId,
    String ownerId,
  ) async {
    final row = await _joined(
      ownerId: ownerId,
      extraWhere: items.clientId.equals(clientId),
      includeDeleted: true,
    ).getSingleOrNull();
    return row == null ? null : _rowWithPayload(row);
  }

  Stream<ItemWithPayload?> watchById(String itemId, String ownerId) => _joined(
    ownerId: ownerId,
    extraWhere: items.id.equals(itemId) & items.isDeleted.equals(false),
  ).watchSingleOrNull().map((row) => row == null ? null : _rowWithPayload(row));

  Future<List<ItemWithPayload>> listPendingUploads(String ownerId) {
    return _joined(
      ownerId: ownerId,
      extraWhere:
          items.syncState.isIn(kUploadQueuePendingStatuses) |
          (items.syncState.equals('processing') &
              items.coreId.isNotNull() &
              items.id.like('$kLocalRecordingIdPrefix%')),
      orderNewestFirst: true,
    ).map(_rowWithPayload).get();
  }

  Future<int> updateItem(String itemId, String ownerId, ItemsCompanion patch) {
    return (update(items)..where(
          (item) => item.id.equals(itemId) & item.ownerId.equals(ownerId),
        ))
        .write(patch);
  }

  Future<int> updateFile(
    String itemId,
    String ownerId,
    FileBlobsCompanion patch,
  ) async {
    final item = await getById(itemId, ownerId);
    final fileId = item?.item.fileBlobId;
    if (fileId == null) return 0;
    return (update(
      fileBlobs,
    )..where((file) => file.id.equals(fileId))).write(patch);
  }

  Future<int> updateText(
    String itemId,
    String ownerId,
    TextContentsCompanion patch,
  ) async {
    final item = await getById(itemId, ownerId);
    final textId = item?.item.textContentId;
    if (textId == null) return 0;
    return (update(
      textContents,
    )..where((text) => text.id.equals(textId))).write(patch);
  }

  Future<int> editTextBody({
    required String itemId,
    required String ownerId,
    required String body,
    required int now,
    required int configRevision,
  }) {
    return transaction(() async {
      final current = await getById(itemId, ownerId);
      final textId = current?.item.textContentId;
      if (current == null || textId == null || current.item.isDeleted) return 0;
      await (update(
        textContents,
      )..where((text) => text.id.equals(textId))).write(
        TextContentsCompanion(
          body: Value(body),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      final changed = await updateItem(
        itemId,
        ownerId,
        ItemsCompanion(
          title: Value(body.split('\n').first),
          sourceRevision: Value(current.item.sourceRevision + 1),
          processingState: const Value('not_requested'),
          processingRunId: const Value(null),
          processingAttempt: const Value(0),
          processingOutputs: const Value('{}'),
          processingRequestedOutputs: const Value('[]'),
          processingError: const Value(null),
          processingErrorCode: const Value(null),
          syncState: const Value('pending_sync'),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      final submittedRevision = current.item.sourceRevision + 1;
      final predecessor =
          await (select(workQueue)
                ..where(
                  (work) =>
                      work.itemId.equals(itemId) &
                      work.kind.isIn([
                        kWorkKindTextCreate,
                        kWorkKindTextUpdate,
                      ]) &
                      work.state.isIn([
                        kWorkStateQueued,
                        kWorkStateRunning,
                        kWorkStateRetry,
                        kWorkStateBlocked,
                      ]),
                )
                ..orderBy([
                  (work) => OrderingTerm.desc(work.submittedSourceRevision),
                  (work) => OrderingTerm.desc(work.createdAt),
                ])
                ..limit(1))
              .getSingleOrNull();
      await into(workQueue).insert(
        textWork(
          kind: kWorkKindTextUpdate,
          itemId: itemId,
          submittedSourceRevision: submittedRevision,
          expectedSourceRevision:
              predecessor?.submittedSourceRevision ??
              current.item.acceptedSourceRevision,
          operationBody: body,
          now: now,
          configRevision: configRevision,
          stage: kWorkStageCreateRemote,
          dependsOn: predecessor?.id,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return changed;
    });
  }

  Future<int> tombstoneText({
    required String itemId,
    required String ownerId,
    required int now,
    required int configRevision,
  }) {
    return transaction(() async {
      final current = await getById(itemId, ownerId);
      if (current == null || current.text == null) return 0;
      final predecessor =
          await (select(workQueue)
                ..where(
                  (work) =>
                      work.itemId.equals(itemId) &
                      work.kind.isIn([
                        kWorkKindTextCreate,
                        kWorkKindTextUpdate,
                      ]) &
                      work.state.isIn([
                        kWorkStateQueued,
                        kWorkStateRunning,
                        kWorkStateRetry,
                        kWorkStateBlocked,
                      ]),
                )
                ..orderBy([
                  (work) => OrderingTerm.desc(work.submittedSourceRevision),
                  (work) => OrderingTerm.desc(work.createdAt),
                ])
                ..limit(1))
              .getSingleOrNull();
      final expectedRevision =
          predecessor?.submittedSourceRevision ??
          current.item.acceptedSourceRevision;
      final changed = await updateItem(
        itemId,
        ownerId,
        ItemsCompanion(
          isDeleted: const Value(true),
          syncState: const Value('pending_delete'),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await into(workQueue).insert(
        textWork(
          kind: kWorkKindTextDelete,
          itemId: itemId,
          submittedSourceRevision: current.item.sourceRevision,
          expectedSourceRevision: expectedRevision,
          operationBody: current.text!.body,
          now: now,
          configRevision: configRevision,
          stage: kWorkStageCreateRemote,
          dependsOn: predecessor?.id,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      return changed;
    });
  }

  Future<int> deleteWithPayload(String itemId, String ownerId) {
    return transaction(() async {
      final row = await getById(itemId, ownerId);
      if (row == null) return 0;
      await (delete(
        workQueue,
      )..where((work) => work.itemId.equals(itemId))).go();
      await (delete(
        itemContacts,
      )..where((edge) => edge.itemId.equals(itemId))).go();
      final deleted =
          await (delete(items)..where(
                (item) => item.id.equals(itemId) & item.ownerId.equals(ownerId),
              ))
              .go();
      if (row.file != null) {
        await (delete(
          fileBlobs,
        )..where((file) => file.id.equals(row.file!.id))).go();
      }
      if (row.text != null) {
        await (delete(
          textContents,
        )..where((text) => text.id.equals(row.text!.id))).go();
      }
      if (row.item.matomeId != null) {
        await _markMatomeSummaryStale(row.item.matomeId!);
      }
      return deleted;
    });
  }

  Future<int> pruneMissingCleanText(String ownerId, Set<int> remoteCoreIds) {
    return transaction(() async {
      final candidates =
          await (select(items)..where(
                (item) =>
                    item.ownerId.equals(ownerId) &
                    item.itemType.equals(MatomeItemType.text.wireName) &
                    item.coreId.isNotNull() &
                    item.isDirty.equals(false) &
                    item.syncState.equals('synced') &
                    item.isDeleted.equals(false),
              ))
              .get();
      var removed = 0;
      for (final item in candidates) {
        if (remoteCoreIds.contains(item.coreId)) continue;
        final activeWork =
            await (select(workQueue)
                  ..where(
                    (work) =>
                        work.itemId.equals(item.id) &
                        work.state.isNotIn([
                          kWorkStateSucceeded,
                          kWorkStateDead,
                        ]),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (activeWork != null) continue;
        await (delete(
          itemContacts,
        )..where((edge) => edge.itemId.equals(item.id))).go();
        await (delete(items)..where((row) => row.id.equals(item.id))).go();
        if (item.textContentId != null) {
          await (delete(
            textContents,
          )..where((text) => text.id.equals(item.textContentId!))).go();
        }
        await (delete(
          workQueue,
        )..where((work) => work.itemId.equals(item.id))).go();
        removed++;
      }
      return removed;
    });
  }

  Future<List<FileRow>> filesForOwner(String ownerId) async {
    final rows = await (_joined(
      ownerId: ownerId,
      extraWhere: items.itemType.equals(MatomeItemType.file.wireName),
      orderNewestFirst: true,
      includePlacement: true,
    )).get();
    if (rows.isEmpty) return const [];

    final matomeIds = rows
        .map((row) => row.readTable(items).matomeId)
        .whereType<String>()
        .toSet();
    final contactsByMatome = <String, List<String>>{};
    if (matomeIds.isNotEmpty) {
      final query =
          select(matomeContacts).join([
              innerJoin(
                contacts,
                contacts.id.equalsExp(matomeContacts.contactId),
              ),
            ])
            ..where(
              matomeContacts.matomeId.isIn(matomeIds) &
                  contacts.ownerId.equals(ownerId),
            )
            ..orderBy([OrderingTerm.asc(contacts.displayName)]);
      for (final row in await query.get()) {
        final matomeId = row.readTable(matomeContacts).matomeId;
        (contactsByMatome[matomeId] ??= []).add(
          row.readTable(contacts).displayName,
        );
      }
    }

    final itemIds = rows.map((row) => row.readTable(items).id).toSet();
    final contactsByItem = <String, List<String>>{};
    if (itemIds.isNotEmpty) {
      final query =
          select(itemContacts).join([
              innerJoin(
                contacts,
                contacts.id.equalsExp(itemContacts.contactId),
              ),
            ])
            ..where(
              itemContacts.itemId.isIn(itemIds) &
                  contacts.ownerId.equals(ownerId),
            )
            ..orderBy([OrderingTerm.asc(contacts.displayName)]);
      for (final row in await query.get()) {
        final itemId = row.readTable(itemContacts).itemId;
        (contactsByItem[itemId] ??= []).add(
          row.readTable(contacts).displayName,
        );
      }
    }

    return rows
        .map((row) {
          final payload = _rowWithPayload(row);
          final matome = row.readTableOrNull(matomes);
          final names = <String>[];
          final seen = <String>{};
          for (final name in contactsByItem[payload.id] ?? const <String>[]) {
            if (seen.add(name)) names.add(name);
          }
          for (final name in contactsByMatome[matome?.id] ?? const <String>[]) {
            if (seen.add(name)) names.add(name);
          }
          return FileRow.fromItem(
            payload,
            matomeTitle: matome?.title,
            spaceName: row.readTableOrNull(workspaces)?.name,
            matomeSpaceId: matome?.spaceId,
            contacts: names,
          );
        })
        .toList(growable: false);
  }

  Future<List<MatomeRow>> matomeTargetsForOwner(String ownerId) async {
    final query = selectOnly(items, distinct: true)
      ..addColumns([items.matomeId])
      ..where(items.ownerId.equals(ownerId) & items.matomeId.isNotNull());
    final ids = (await query.get())
        .map((row) => row.read(items.matomeId))
        .whereType<String>()
        .toSet();
    if (ids.isEmpty) return const [];
    return (select(matomes)
          ..where((matome) => matome.id.isIn(ids) & matome.archivedAt.isNull())
          ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
        .get();
  }

  Future<Map<String, String?>> matomeIdsForOwnedItems(
    Set<String> itemIds,
    String ownerId,
  ) async {
    if (itemIds.isEmpty) return const {};
    final rows =
        await (select(items)..where(
              (item) => item.id.isIn(itemIds) & item.ownerId.equals(ownerId),
            ))
            .get();
    return {for (final row in rows) row.id: row.matomeId};
  }

  Future<int> moveItemsToMatome(
    Set<String> itemIds,
    String? matomeId,
    String ownerId,
  ) {
    if (itemIds.isEmpty) return Future.value(0);
    return transaction(() async {
      if (matomeId != null && await _isForeignMatome(matomeId, ownerId)) {
        return 0;
      }
      final prior = await matomeIdsForOwnedItems(itemIds, ownerId);
      var position = matomeId == null
          ? null
          : await _nextPosition(matomeId, ownerId);
      var moved = 0;
      for (final itemId in itemIds) {
        moved +=
            await (update(items)..where(
                  (item) =>
                      item.id.equals(itemId) & item.ownerId.equals(ownerId),
                ))
                .write(
                  ItemsCompanion(
                    matomeId: Value(matomeId),
                    position: Value(position),
                    isDirty: const Value(true),
                  ),
                );
        if (position != null) position++;
      }
      for (final id in <String>{
        ...prior.values.whereType<String>(),
        ?matomeId,
      }) {
        await _markMatomeSummaryStale(id);
      }
      return moved;
    });
  }

  Future<void> restoreItemMatomes(
    Map<String, String?> priorByItem,
    String ownerId,
  ) async {
    await transaction(() async {
      for (final entry in priorByItem.entries) {
        final position = entry.value == null
            ? null
            : await _nextPosition(entry.value!, ownerId);
        await (update(items)..where(
              (item) =>
                  item.id.equals(entry.key) & item.ownerId.equals(ownerId),
            ))
            .write(
              ItemsCompanion(
                matomeId: Value(entry.value),
                position: Value(position),
                isDirty: const Value(true),
              ),
            );
      }
    });
  }

  Future<int> fileIntoSpace(
    String itemId,
    String? workspaceId,
    String ownerId,
  ) {
    return updateItem(
      itemId,
      ownerId,
      ItemsCompanion(
        workspaceId: Value(workspaceId),
        isDirty: const Value(true),
      ),
    );
  }

  Future<List<ItemWithPayload>> itemsByDateRange(
    int startEpoch,
    int endEpoch,
    String ownerId,
  ) {
    return _joined(
      ownerId: ownerId,
      extraWhere: items.createdAt.isBetweenValues(startEpoch, endEpoch),
      orderNewestFirst: true,
    ).map(_rowWithPayload).get();
  }

  Future<List<ItemWithPayload>> itemsByDay(int dayEpoch, String ownerId) =>
      itemsByDateRange(dayEpoch, dayEpoch + _kMsPerDay - 1, ownerId);

  Future<List<ItemWithWorkspace>> itemsByDayWithWorkspace(
    int dayEpoch,
    String ownerId,
  ) async {
    final query = _joined(
      ownerId: ownerId,
      extraWhere: items.createdAt.isBetweenValues(
        dayEpoch,
        dayEpoch + _kMsPerDay - 1,
      ),
      orderNewestFirst: true,
      includePlacement: true,
    );
    return (await query.get())
        .map(
          (row) => ItemWithWorkspace(
            _rowWithPayload(row),
            row.readTableOrNull(workspaces)?.name,
          ),
        )
        .toList(growable: false);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joined({
    required String ownerId,
    Expression<bool>? extraWhere,
    bool orderNewestFirst = false,
    bool orderByPosition = false,
    bool includePlacement = false,
    bool includeDeleted = false,
  }) {
    final joins = <Join<HasResultSet, dynamic>>[
      leftOuterJoin(fileBlobs, fileBlobs.id.equalsExp(items.fileBlobId)),
      leftOuterJoin(
        textContents,
        textContents.id.equalsExp(items.textContentId),
      ),
      if (includePlacement) ...[
        leftOuterJoin(matomes, matomes.id.equalsExp(items.matomeId)),
        leftOuterJoin(
          workspaces,
          workspaces.id.equalsExp(
            // The direct workspace is used for the label. Effective placement
            // still resolves matome.space_id first in FileRow.
            items.workspaceId,
          ),
        ),
      ],
    ];
    final query = select(items).join(joins)
      ..where(items.ownerId.equals(ownerId));
    if (!includeDeleted) query.where(items.isDeleted.equals(false));
    if (extraWhere != null) query.where(extraWhere);
    if (orderNewestFirst) {
      query.orderBy([OrderingTerm.desc(items.createdAt)]);
    } else if (orderByPosition) {
      query.orderBy([OrderingTerm.asc(items.position)]);
    }
    return query;
  }

  ItemWithPayload _rowWithPayload(TypedResult row) {
    final item = row.readTable(items);
    final type = matomeItemTypeFromWire(item.itemType);
    return mapMatomeItemType(
      type,
      file: () => ItemWithPayload(
        item: item,
        type: type,
        file: row.readTableOrNull(fileBlobs) ?? _missingPayload(item),
      ),
      text: () => ItemWithPayload(
        item: item,
        type: type,
        text: row.readTableOrNull(textContents) ?? _missingPayload(item),
      ),
    );
  }

  Future<ItemsCompanion> _normalizePlacement(ItemsCompanion item) async {
    final matomeId = item.matomeId.present ? item.matomeId.value : null;
    if (matomeId == null) {
      return item.copyWith(position: const Value(null));
    }
    if (item.position.present && item.position.value != null) return item;
    return item.copyWith(
      position: Value(await _nextPosition(matomeId, item.ownerId.value)),
    );
  }

  Future<int> _nextPosition(String matomeId, String ownerId) async {
    final max = items.position.max();
    final query = selectOnly(items)
      ..addColumns([max])
      ..where(items.matomeId.equals(matomeId) & items.ownerId.equals(ownerId));
    return ((await query.getSingle()).read(max) ?? -1) + 1;
  }

  Future<ItemRow?> _itemById(String id, String ownerId) =>
      (select(
            items,
          )..where((item) => item.id.equals(id) & item.ownerId.equals(ownerId)))
          .getSingleOrNull();

  Future<bool> _isForeignMatome(String matomeId, String ownerId) async {
    final rows = await (select(
      items,
    )..where((item) => item.matomeId.equals(matomeId))).get();
    return rows.isNotEmpty && rows.every((item) => item.ownerId != ownerId);
  }

  Future<void> _markMatomeSummaryStale(String matomeId) {
    return (update(matomes)..where((matome) => matome.id.equals(matomeId)))
        .write(const MatomesCompanion(summaryStale: Value(true)));
  }

  void _requirePayloadArc(ItemsCompanion item, MatomeItemType expected) {
    final actual = matomeItemTypeFromWire(item.itemType.value);
    final valid = mapMatomeItemType(
      actual,
      file: () =>
          item.fileBlobId.present &&
          item.fileBlobId.value != null &&
          (!item.textContentId.present || item.textContentId.value == null),
      text: () =>
          item.textContentId.present &&
          item.textContentId.value != null &&
          (!item.fileBlobId.present || item.fileBlobId.value == null),
    );
    if (actual != expected || !valid) {
      throw ArgumentError('Item payload does not match ${expected.wireName}');
    }
  }

  Never _missingPayload(ItemRow item) {
    throw StateError('Item ${item.id} has no ${item.itemType} payload');
  }
}
