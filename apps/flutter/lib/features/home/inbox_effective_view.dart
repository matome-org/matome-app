/// The Inbox VIEW over effective-space-NULL (local-first-spaces #102 W3,
/// ADR-0006 §1 / sync-gate spec R1.3).
///
/// > INBOX ⟺ effectiveSpace == NULL — a VIEW over everything, not a stored
/// > field. Two kinds of thing have a NULL effective space and so live in the
/// > Inbox: a **loose item** (a recording with no matome and no space) and a
/// > **draft matome** (a matome with no space).
///
/// This file is the SINGLE place the Inbox membership predicate is computed, and
/// it routes EVERY decision through the ONE authoritative resolver
/// [EffectiveSpace] — it never re-derives `effectiveSpace` with an inline
/// `spaceId == null` (ADR-0006 §2 / spec R1.2: a second recompute leaks private
/// data). The DAO queries pre-narrow the candidate rows; this layer is the
/// resolver-backed confirmation that each candidate's effective space really is
/// NULL.
library;

import '../../core/db/matome_card.dart';
import '../spaces/effective_space.dart';
import 'inbox_item.dart';

/// Whether a candidate LOOSE recording's effective space is NULL — i.e. it
/// belongs in the Inbox. Routes through [EffectiveSpace.effectiveSpaceId]
/// (matome WINS, then own space) rather than inspecting the row inline.
///
/// A loose recording has neither a matome (so its matome's space is NULL) nor a
/// filed space, so the resolver returns NULL. A row that slipped in with a
/// non-null `workspaceId` (or that is in a filed matome) resolves to a non-null
/// space and is correctly EXCLUDED from the Inbox view.
bool isInboxLooseItem({
  required String? matomeSpaceId,
  required String? workspaceId,
}) =>
    EffectiveSpace.effectiveSpaceId(
      ItemMembership(matomeSpaceId: matomeSpaceId, workspaceId: workspaceId),
    ) ==
    null;

/// Whether a candidate matome is a DRAFT (no space) — i.e. it belongs in the
/// Inbox. A matome's own space IS the effective space of every item in it
/// (matome WINS), so a matome with [MatomeItem.spaceId] NULL resolves, via the
/// resolver, to a NULL effective space for itself and its children → Inbox.
bool isInboxDraftMatome(MatomeItem matome) =>
    EffectiveSpace.effectiveSpaceId(
      // A matome-level membership: the matome IS the space-bearer, so feed its
      // own spaceId as the matome-space side and leave the item-space side
      // empty. The resolver yields the matome's space (or NULL ⇒ Inbox).
      ItemMembership(matomeSpaceId: matome.spaceId, workspaceId: null),
    ) ==
    null;

/// Filters [matomes] (already pre-narrowed to `spaceId IS NULL` by the DAO) down
/// to the DRAFT matomes whose effective space the resolver confirms is NULL.
List<MatomeItem> inboxDraftMatomes(List<MatomeItem> matomes) =>
    matomes.where(isInboxDraftMatome).toList(growable: false);

/// Filters [items] (already pre-narrowed to loose candidates by the DAO) down to
/// the LOOSE items whose effective space the resolver confirms is NULL. Each
/// [InboxItem] carries no matome/space columns on its card, so the caller passes
/// the raw membership it loaded from the row.
List<InboxItem> inboxLooseItems(
  List<InboxItem> items, {
  required String? Function(InboxItem item) matomeSpaceIdOf,
  required String? Function(InboxItem item) workspaceIdOf,
}) =>
    items
        .where(
          (i) => isInboxLooseItem(
            matomeSpaceId: matomeSpaceIdOf(i),
            workspaceId: workspaceIdOf(i),
          ),
        )
        .toList(growable: false);
