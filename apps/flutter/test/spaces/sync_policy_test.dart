// W4 #1498 — the ONE operation-keyed decision point (plan #102, spec R2.1).
//
// SyncPolicy.can(caller, operation, space) is the SINGLE gate. These unit tests
// pin its shape (operation-keyed, NOT role-keyed) and its today-behaviour:
// spaceSync ⟺ the effective space is a CLOUD space (owner ⇒ allow), delegated
// to the ONE resolver EffectiveSpace — never a second predicate here.

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/spaces/effective_space.dart';
import 'package:matome_flutter/features/spaces/sync_policy.dart';

void main() {
  const cloud = SpaceRef(id: 'c', syncMode: SpaceSyncMode.cloud);
  const local = SpaceRef(id: 'l', syncMode: SpaceSyncMode.local);
  const caller = Caller(userId: 'user-1');

  group('Operation.spaceSync — the data-egress gate', () {
    test('CLOUD space ⇒ allowed (owner ⇒ allow today)', () {
      expect(SyncPolicy.can(caller, Operation.spaceSync, cloud), isTrue);
    });

    test('LOCAL space ⇒ DENIED (filing ≠ sync; never egressed)', () {
      expect(SyncPolicy.can(caller, Operation.spaceSync, local), isFalse);
    });

    test('NULL space (Inbox) ⇒ DENIED (fail-closed)', () {
      expect(SyncPolicy.can(caller, Operation.spaceSync, null), isFalse);
    });

    test('anonymous caller does NOT widen access — still cloud-only today', () {
      expect(
        SyncPolicy.can(Caller.anonymous, Operation.spaceSync, cloud),
        isTrue,
      );
      expect(
        SyncPolicy.can(Caller.anonymous, Operation.spaceSync, local),
        isFalse,
      );
    });

    test(
      'delegates to the ONE resolver (matches EffectiveSpace.spaceIsCloud)',
      () {
        // The gate must NOT invent a second predicate: its spaceSync answer is
        // exactly the resolver's space-level predicate.
        for (final space in [cloud, local, null]) {
          expect(
            SyncPolicy.can(caller, Operation.spaceSync, space),
            EffectiveSpace.spaceIsCloud(space),
            reason: 'spaceSync == resolver.spaceIsCloud for $space',
          );
        }
      },
    );
  });

  group('Operation.spaceWrite / spaceRead — filing/reading (≠ sync)', () {
    test('filing into a LOCAL space is ALLOWED (filing ≠ sync, spec R2)', () {
      expect(SyncPolicy.can(caller, Operation.spaceWrite, local), isTrue);
    });

    test('filing into a CLOUD space is ALLOWED', () {
      expect(SyncPolicy.can(caller, Operation.spaceWrite, cloud), isTrue);
    });

    test('reading any resolvable space is ALLOWED', () {
      expect(SyncPolicy.can(caller, Operation.spaceRead, local), isTrue);
      expect(SyncPolicy.can(caller, Operation.spaceRead, cloud), isTrue);
    });

    test('a NULL space is denied for every operation (nothing to act on)', () {
      expect(SyncPolicy.can(caller, Operation.spaceWrite, null), isFalse);
      expect(SyncPolicy.can(caller, Operation.spaceRead, null), isFalse);
    });
  });

  group(
    'Operation.spacePromote — promotion authz (owner-scope, NOT cloudness)',
    () {
      // R3.6: promotion gates on OWNERSHIP, not on the space being cloud — the
      // whole point is to promote a space that is STILL local. So a LOCAL space
      // is promotable by its owner (unlike spaceSync, which DENIES local).
      const ownedByCaller = SpaceRef(
        id: 'l',
        syncMode: SpaceSyncMode.local,
        ownerId: 'user-1',
      );
      const ownedByOther = SpaceRef(
        id: 'l2',
        syncMode: SpaceSyncMode.local,
        ownerId: 'someone-else',
      );
      const unowned = SpaceRef(id: 'l3', syncMode: SpaceSyncMode.local);

      test(
        'owner of a LOCAL space MAY promote it (cloudness is NOT the gate)',
        () {
          expect(
            SyncPolicy.can(caller, Operation.spacePromote, ownedByCaller),
            isTrue,
          );
        },
      );

      test('a NON-OWNER caller is DENIED (spec R3.6 — no foreign promote)', () {
        expect(
          SyncPolicy.can(caller, Operation.spacePromote, ownedByOther),
          isFalse,
        );
      });

      test('an unowned personal space (m006 NULL owner) ⇒ caller owns it', () {
        expect(SyncPolicy.can(caller, Operation.spacePromote, unowned), isTrue);
      });

      test('an anonymous/unresolved caller NEVER promotes (fail-closed)', () {
        expect(
          SyncPolicy.can(Caller.anonymous, Operation.spacePromote, unowned),
          isFalse,
        );
        expect(
          SyncPolicy.can(
            Caller.anonymous,
            Operation.spacePromote,
            ownedByCaller,
          ),
          isFalse,
        );
      });

      test('a NULL space is denied (nothing to promote)', () {
        expect(SyncPolicy.can(caller, Operation.spacePromote, null), isFalse);
      });
    },
  );

  test('Operation catalog is minimal (no role enum baked in)', () {
    // The catalog is the stable key set; it must stay minimal in #102. This pins
    // the seam so a future operation is added deliberately (and a role enum is
    // never introduced as the gate key). `spacePromote` (W4 #1499) is the
    // owner-scope authz key for promotion — added deliberately as a catalog
    // entry, not a new gate.
    expect(Operation.values, <Operation>[
      Operation.spaceRead,
      Operation.spaceWrite,
      Operation.spaceSync,
      Operation.spacePromote,
    ]);
  });
}
