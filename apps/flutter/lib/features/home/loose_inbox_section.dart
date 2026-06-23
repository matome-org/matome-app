/// The LOOSE-items section of the W3 Inbox VIEW (local-first-spaces #102 W3,
/// ADR-0006 §1). Renders the loose half of the effective-space-NULL Inbox — bare
/// items with no matome and no space — using the W0 [InboxItemCard], above the
/// draft-matome list the home screen already shows.
///
/// Gated behind [FeatureFlags.localFirstSpaces]: with the flag OFF the home
/// screen never builds this (the loose controller publishes an empty list and
/// queries nothing), so the Inbox stays byte-unchanged. The triage affordance
/// ("File") REUSES the shared [showRelationshipPicker] — the single relationship
/// surface — to file a loose item into a space ([InboxController.moveToSpace]);
/// it does not hand-roll a new picker.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/inbox_item_card.dart';
import '../../ui/relationship_picker.dart';
import '../../ui/space_sync_chip.dart';
import '../spaces/filing_spaces_provider.dart';
import 'home_filters.dart' show formatTimestamp;
import 'inbox_controller.dart';
import 'inbox_item.dart';
import 'loose_inbox_controller.dart';

/// Watches [looseInboxControllerProvider] and renders each loose item as an
/// [InboxItemCard] (kind `looseItem`). Renders nothing while loading / on error
/// / when empty so it composes cleanly above the draft-matome list.
class LooseInboxSection extends ConsumerWidget {
  const LooseInboxSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final items = ref.watch(looseInboxControllerProvider).valueOrNull ??
        const <InboxItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: _LooseCard(item: item),
          ),
      ],
    );
  }
}

class _LooseCard extends ConsumerWidget {
  const _LooseCard({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = item.card;
    return InboxItemCard(
      key: ValueKey('loose-item-${item.id}'),
      kind: InboxEntryKind.looseItem,
      title: card.title,
      meta: t.inbox.looseMeta(
        type: _mediaLabel(card.mediaType),
        time: formatTimestamp(
          DateTime.fromMillisecondsSinceEpoch(item.createdAt),
        ),
      ),
      tagLabel: t.inbox.looseTag,
      fileLabel: t.inbox.fileAction,
      icon: _mediaIcon(card.mediaType),
      // A loose item is local by design until filed into a cloud space.
      syncState: card.isOnCloud ? SpaceSyncState.cloud : SpaceSyncState.local,
      onFile: () => _file(context, ref),
    );
  }

  /// Triage: open the SHARED relationship picker over the available spaces and
  /// file this loose item into the chosen one — reusing the one picker surface,
  /// not a bespoke sheet. The move routes through [InboxController.moveToSpace]
  /// (local-first write + best-effort Core PATCH); the loose controller re-reads
  /// when the recording controller emits, so the card drops out of the Inbox.
  Future<void> _file(BuildContext context, WidgetRef ref) async {
    final spaces = ref.read(filingSpacesProvider).valueOrNull ?? const [];
    final result = await showRelationshipPicker(
      context: context,
      data: RelationshipPickerData(
        title: t.inbox.fileIntoSpaceTitle,
        searchHint: t.inbox.fileSearchHint,
        emptyLabel: t.inbox.fileEmpty,
        candidates: [
          for (final s in spaces)
            RelationshipCandidate(
              id: s.id,
              title: s.name,
              icon: Icons.workspaces_outline,
            ),
        ],
      ),
    );
    if (result == null) return;
    final ids = result.candidateIds;
    if (ids == null || ids.isEmpty) return;
    final spaceId = ids.first;
    await ref.read(inboxControllerProvider.notifier).moveToSpace(item.id, spaceId);
  }

  static String _mediaLabel(String mediaType) => switch (mediaType) {
        'image' => 'Photo',
        'document' => 'Document',
        _ => 'Audio',
      };

  static IconData _mediaIcon(String mediaType) => switch (mediaType) {
        'image' => Icons.image_outlined,
        'document' => Icons.description_outlined,
        _ => Icons.mic_none,
      };
}
