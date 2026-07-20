import '../../core/db/daos/items_dao.dart';

/// The only application boundary allowed to create an Item deletion.
/// Side effects are executed later by the durable work queue.
final class ItemDeletionService {
  ItemDeletionService(
    this._items,
    this._drain, {
    int Function()? configRevision,
    DateTime Function()? clock,
  }) : _configRevision = configRevision ?? (() => 0),
       _clock = clock ?? DateTime.now;

  final ItemsDao _items;
  final Future<void> Function() _drain;
  final int Function() _configRevision;
  final DateTime Function() _clock;

  Future<bool> delete(String itemId, String ownerId) async {
    final item = await _items.getByIdIncludingDeleted(itemId, ownerId);
    if (item == null) return false;
    final now = _clock().millisecondsSinceEpoch;
    final created = item.file != null
        ? await _items.tombstoneFileDelete(
            itemId: itemId,
            ownerId: ownerId,
            now: now,
          )
        : item.coreId == null
        ? await _items.deleteLocalText(itemId, ownerId)
        : await _items.tombstoneText(
                itemId: itemId,
                ownerId: ownerId,
                now: now,
                configRevision: _configRevision(),
              ) ==
              1;
    if (created) await _drain();
    return created;
  }
}
