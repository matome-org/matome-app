import '../../core/db/daos/items_dao.dart';
import '../../core/db/recording_card.dart';

/// One Inbox row: the display [RecordingItem] plus the raw `createdAt` epoch
/// (ms) needed for date grouping and search over notes — neither of which the
/// card alone carries.
class InboxItem {
  const InboxItem({required this.card, required this.createdAt});

  final RecordingItem card;

  /// `items.created_at` (epoch ms), retained from the DB row for grouping.
  final int createdAt;

  factory InboxItem.fromItem(ItemWithPayload row, {String? workspaceName}) {
    return InboxItem(
      card: RecordingItem.fromItem(row, workspaceName: workspaceName),
      createdAt: row.createdAt,
    );
  }

  String get id => card.id;
}

/// A titled group of Inbox items (Today / Yesterday / "Mon D, YYYY").
class InboxSection {
  const InboxSection({required this.title, required this.items});

  final String title;
  final List<InboxItem> items;
}
