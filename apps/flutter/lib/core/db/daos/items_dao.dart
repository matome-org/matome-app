import 'package:drift/drift.dart';

import '../../../features/items/matome_item_type.dart';
import '../app_database.dart';
import '../tables.dart';

part 'items_dao.g.dart';

class MatomeItemWithPayload {
  const MatomeItemWithPayload({
    required this.item,
    required this.type,
    this.file,
    this.text,
  });

  final ItemRow item;
  final MatomeItemType type;
  final FileBlobRow? file;
  final TextContentRow? text;
}

@DriftAccessor(tables: [Items, FileBlobs, TextContents])
class ItemsDao extends DatabaseAccessor<AppDatabase> with _$ItemsDaoMixin {
  ItemsDao(super.db);

  Future<List<MatomeItemWithPayload>> listForMatome(int matomeId) async {
    final query =
        select(items).join([
            leftOuterJoin(fileBlobs, fileBlobs.id.equalsExp(items.fileBlobId)),
            leftOuterJoin(
              textContents,
              textContents.id.equalsExp(items.textContentId),
            ),
          ])
          ..where(items.matomeId.equals(matomeId))
          ..orderBy([OrderingTerm.asc(items.position)]);

    final rows = await query.get();
    return rows.map(_rowWithPayload).toList(growable: false);
  }

  Future<MatomeItemWithPayload?> getWithPayload(int itemId) async {
    final query = select(items).join([
      leftOuterJoin(fileBlobs, fileBlobs.id.equalsExp(items.fileBlobId)),
      leftOuterJoin(
        textContents,
        textContents.id.equalsExp(items.textContentId),
      ),
    ])..where(items.id.equals(itemId));

    final row = await query.getSingleOrNull();
    return row == null ? null : _rowWithPayload(row);
  }

  Future<void> updateTextBody(int textContentId, String body) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(textContents)..where((t) => t.id.equals(textContentId)))
        .write(TextContentsCompanion(body: Value(body), updatedAt: Value(now)));
  }

  Future<void> deleteWithPayload(int itemId) async {
    await transaction(() async {
      final row = await getWithPayload(itemId);
      if (row == null) return;
      await (delete(items)..where((item) => item.id.equals(itemId))).go();
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
    });
  }

  MatomeItemWithPayload _rowWithPayload(TypedResult row) {
    final item = row.readTable(items);
    final type = matomeItemTypeFromWire(item.itemType);
    final file = row.readTableOrNull(fileBlobs);
    final text = row.readTableOrNull(textContents);

    return mapMatomeItemType(
      type,
      file: () => MatomeItemWithPayload(
        item: item,
        type: type,
        file: file ?? _missingPayload(item),
      ),
      text: () => MatomeItemWithPayload(
        item: item,
        type: type,
        text: text ?? _missingPayload(item),
      ),
    );
  }

  Never _missingPayload(ItemRow item) {
    throw StateError('Item ${item.id} has no ${item.itemType} payload');
  }
}
