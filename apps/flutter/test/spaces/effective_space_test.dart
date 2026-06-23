import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/spaces/effective_space.dart';

// ---------------------------------------------------------------------------
// Table-driven matrix for the ONE authoritative effectiveSpace / isCloudSynced
// resolver (#1493, plan #102 W1 — ADR-0006 §2/§5, sync-gate spec R1/R2).
//
// The membership matrix (R1):
//   loose            (matomeSpaceId null, workspaceId null)        → Inbox (NULL)
//   in-matome        (matomeSpaceId set)                           → matome's space
//   draft-matome     (matomeSpaceId null, workspaceId null)        → Inbox (NULL)
//   filed-direct     (matomeSpaceId null, workspaceId set)         → workspace_id
//   CONFLICT         (matomeSpaceId set AND workspaceId set)       → matome WINS
//
// crossed with the space sync axis (R2): local space → not synced; cloud space
// → synced. Plus the fail-closed branches (unknown space id, NULL space).
// ---------------------------------------------------------------------------

/// A tiny in-memory space registry → the [SpaceRef] resolver the API takes.
SpaceRef? Function(String) registry(Map<String, SpaceRef> spaces) =>
    (id) => spaces[id];

/// Convenience builders for the two sync modes (tenancy/ownerId default to the
/// #102 constants — personal / current user — to PROVE the seam carries them).
SpaceRef localSpace(String id) =>
    SpaceRef(id: id, syncMode: SpaceSyncMode.local);
SpaceRef cloudSpace(String id) =>
    SpaceRef(id: id, syncMode: SpaceSyncMode.cloud);

void main() {
  // -------------------------------------------------------------------------
  // R1 — effectiveSpaceId: the precedence rule (matome WINS), table-driven.
  // -------------------------------------------------------------------------
  group('effectiveSpaceId — membership precedence (R1)', () {
    final cases = <({
      String name,
      ItemMembership item,
      String? expected,
    })>[
      (
        name: 'loose item (no matome, no workspace) → NULL (Inbox)',
        item: const ItemMembership(),
        expected: null,
      ),
      (
        name: 'in-matome → the matome\'s space',
        item: const ItemMembership(matomeSpaceId: 'space_M'),
        expected: 'space_M',
      ),
      (
        name: 'draft-matome (matome with null space) → NULL (Inbox)',
        item: const ItemMembership(matomeSpaceId: null, workspaceId: null),
        expected: null,
      ),
      (
        name: 'filed-direct (workspace_id, no matome) → workspace_id',
        item: const ItemMembership(workspaceId: 'space_W'),
        expected: 'space_W',
      ),
      (
        name: 'CONFLICT (in matome AND filed-direct) → matome WINS',
        item: const ItemMembership(
          matomeSpaceId: 'space_M',
          workspaceId: 'space_W',
        ),
        expected: 'space_M',
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        expect(EffectiveSpace.effectiveSpaceId(c.item), c.expected);
      });
    }
  });

  // -------------------------------------------------------------------------
  // R2 — statusOf / isCloudSynced: effective space × sync mode, table-driven.
  // -------------------------------------------------------------------------
  group('statusOf / isCloudSynced — sync gate (R2)', () {
    final spaces = <String, SpaceRef>{
      'space_local': localSpace('space_local'),
      'space_cloud': cloudSpace('space_cloud'),
      'space_M_local': localSpace('space_M_local'),
      'space_M_cloud': cloudSpace('space_M_cloud'),
      'space_W_local': localSpace('space_W_local'),
      'space_W_cloud': cloudSpace('space_W_cloud'),
    };
    final resolve = registry(spaces);

    final cases = <({
      String name,
      ItemMembership item,
      Type expectedStatus,
      bool expectedCloudSynced,
      String? expectedSpaceId,
    })>[
      // loose / draft → Inbox, never synced.
      (
        name: 'loose item → SyncInbox, not cloud-synced',
        item: const ItemMembership(),
        expectedStatus: SyncInbox,
        expectedCloudSynced: false,
        expectedSpaceId: null,
      ),
      (
        name: 'draft-matome → SyncInbox, not cloud-synced',
        item: const ItemMembership(matomeSpaceId: null),
        expectedStatus: SyncInbox,
        expectedCloudSynced: false,
        expectedSpaceId: null,
      ),
      // in-matome → matome's space drives the status.
      (
        name: 'in-matome (LOCAL space) → SyncLocalOnly, not cloud-synced',
        item: const ItemMembership(matomeSpaceId: 'space_M_local'),
        expectedStatus: SyncLocalOnly,
        expectedCloudSynced: false,
        expectedSpaceId: 'space_M_local',
      ),
      (
        name: 'in-matome (CLOUD space) → SyncCloud, cloud-synced',
        item: const ItemMembership(matomeSpaceId: 'space_M_cloud'),
        expectedStatus: SyncCloud,
        expectedCloudSynced: true,
        expectedSpaceId: 'space_M_cloud',
      ),
      // filed-direct → workspace_id drives the status.
      (
        name: 'filed-direct (LOCAL space) → SyncLocalOnly, not cloud-synced',
        item: const ItemMembership(workspaceId: 'space_W_local'),
        expectedStatus: SyncLocalOnly,
        expectedCloudSynced: false,
        expectedSpaceId: 'space_W_local',
      ),
      (
        name: 'filed-direct (CLOUD space) → SyncCloud, cloud-synced',
        item: const ItemMembership(workspaceId: 'space_W_cloud'),
        expectedStatus: SyncCloud,
        expectedCloudSynced: true,
        expectedSpaceId: 'space_W_cloud',
      ),
      // CONFLICT — matome WINS, so the matome's space drives sync, NOT the
      // shadowed workspace_id. Matome cloud + workspace local → SYNCED.
      (
        name: 'CONFLICT (matome CLOUD, workspace LOCAL) → matome wins → '
            'SyncCloud, cloud-synced',
        item: const ItemMembership(
          matomeSpaceId: 'space_M_cloud',
          workspaceId: 'space_W_local',
        ),
        expectedStatus: SyncCloud,
        expectedCloudSynced: true,
        expectedSpaceId: 'space_M_cloud',
      ),
      // CONFLICT — matome local + workspace cloud → NOT synced (matome wins;
      // the shadowed cloud workspace must NOT leak the item to Core).
      (
        name: 'CONFLICT (matome LOCAL, workspace CLOUD) → matome wins → '
            'SyncLocalOnly, NOT cloud-synced (shadowed cloud must not leak)',
        item: const ItemMembership(
          matomeSpaceId: 'space_M_local',
          workspaceId: 'space_W_cloud',
        ),
        expectedStatus: SyncLocalOnly,
        expectedCloudSynced: false,
        expectedSpaceId: 'space_M_local',
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final status = EffectiveSpace.statusOf(c.item, resolveSpace: resolve);
        expect(status.runtimeType, c.expectedStatus);
        expect(
          EffectiveSpace.isCloudSynced(c.item, resolveSpace: resolve),
          c.expectedCloudSynced,
        );
        // The status payload carries the EFFECTIVE space (precedence-resolved).
        final payloadSpaceId = switch (status) {
          SyncInbox() => null,
          SyncLocalOnly(:final space) => space.id,
          SyncCloud(:final space) => space.id,
        };
        expect(payloadSpaceId, c.expectedSpaceId);
      });
    }
  });

  // -------------------------------------------------------------------------
  // Fail-closed branches — an effective space that resolves to nothing must
  // never sync (it falls to Inbox, not silently to Core).
  // -------------------------------------------------------------------------
  group('fail-closed — unresolvable / missing space', () {
    test('effective space id unknown to the registry → SyncInbox, not synced',
        () {
      final resolve = registry(const {});
      const item = ItemMembership(workspaceId: 'space_ghost');
      expect(
        EffectiveSpace.statusOf(item, resolveSpace: resolve),
        isA<SyncInbox>(),
      );
      expect(
        EffectiveSpace.isCloudSynced(item, resolveSpace: resolve),
        isFalse,
      );
    });

    test('spaceIsCloud(null) is false (no space ⇒ never synced)', () {
      expect(EffectiveSpace.spaceIsCloud(null), isFalse);
    });

    test('spaceIsCloud(local) false, spaceIsCloud(cloud) true', () {
      expect(EffectiveSpace.spaceIsCloud(localSpace('x')), isFalse);
      expect(EffectiveSpace.spaceIsCloud(cloudSpace('x')), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Forward-compat seam — the VALUE OBJECT carries tenancy + ownerId (constant
  // in #102) so org-spaces add ONE branch, not a rewrite. Proven present and
  // NOT consulted by the sync gate (Axis A only — R2.2).
  // -------------------------------------------------------------------------
  group('forward-compat — Space VALUE OBJECT seam (H4 / R1.4 / R2.2)', () {
    test('SpaceRef carries tenancy + ownerId; defaults are personal / null',
        () {
      const s = SpaceRef(id: 's', syncMode: SpaceSyncMode.cloud);
      expect(s.tenancy, SpaceTenancy.personal);
      expect(s.ownerId, isNull);
    });

    test('tenancy/ownerId do NOT affect the sync gate (Axis A only — R2.2)',
        () {
      // Two cloud spaces identical on Axis A but differing on Axis B both sync.
      final personal = SpaceRef(
        id: 's',
        syncMode: SpaceSyncMode.cloud,
        tenancy: SpaceTenancy.personal,
        ownerId: 'user_1',
      );
      final org = SpaceRef(
        id: 's',
        syncMode: SpaceSyncMode.cloud,
        tenancy: SpaceTenancy.org,
        ownerId: 'user_2',
      );
      const item = ItemMembership(workspaceId: 's');
      expect(
        EffectiveSpace.isCloudSynced(item, resolveSpace: (_) => personal),
        isTrue,
      );
      expect(
        EffectiveSpace.isCloudSynced(item, resolveSpace: (_) => org),
        isTrue,
      );
    });

    test('SpaceRef value equality includes all four fields', () {
      expect(
        const SpaceRef(id: 'a', syncMode: SpaceSyncMode.cloud),
        const SpaceRef(id: 'a', syncMode: SpaceSyncMode.cloud),
      );
      expect(
        const SpaceRef(id: 'a', syncMode: SpaceSyncMode.cloud),
        isNot(const SpaceRef(id: 'a', syncMode: SpaceSyncMode.local)),
      );
    });

    test('SpaceRef hashCode is consistent with equality; toString is debuggable',
        () {
      const a = SpaceRef(id: 'a', syncMode: SpaceSyncMode.cloud);
      const b = SpaceRef(id: 'a', syncMode: SpaceSyncMode.cloud);
      expect(a.hashCode, b.hashCode);
      expect(
        a.toString(),
        contains('SpaceRef(id: a'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Exhaustiveness proof — a switch over SyncStatus with NO default arm
  // compiles ONLY because the sealed hierarchy is exhaustively handled. Adding
  // a future case (orgManaged / policyBlocked) would break this switch at
  // compile time — which is the contract (R2.1, no silent default).
  // -------------------------------------------------------------------------
  group('sealed exhaustiveness (R2.1)', () {
    String label(SyncStatus s) => switch (s) {
          SyncInbox() => 'inbox',
          SyncLocalOnly() => 'local',
          SyncCloud() => 'cloud',
        };

    test('every status maps via a default-less switch', () {
      expect(label(const SyncInbox()), 'inbox');
      expect(label(SyncLocalOnly(space: localSpace('x'))), 'local');
      expect(label(SyncCloud(space: cloudSpace('x'))), 'cloud');
    });
  });
}
