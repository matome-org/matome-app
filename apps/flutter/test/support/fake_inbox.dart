import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';

/// An [InboxController] seeded with a fixed list — no Drift, no Core. Subclasses
/// the real controller so it satisfies the provider override type, but replaces
/// the load/refresh/sync surface so nothing hits the DB or network.
class FakeInboxController extends InboxController {
  FakeInboxController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<InboxItem>> _seed;

  @override
  Future<void> refresh() async {
    state = _seed;
  }

  @override
  Future<void> reloadFromLocal() async {
    state = _seed;
  }
}

/// A [MatomeInboxController] seeded with a fixed matome list — no Drift, no Core
/// (#1378). Subclasses the real controller so it satisfies the provider
/// override type, but replaces the load/refresh surface so nothing hits the DB.
class FakeMatomeInboxController extends MatomeInboxController {
  FakeMatomeInboxController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<MatomeItem>> _seed;

  @override
  Future<void> refresh() async {
    state = _seed;
  }

  @override
  Future<void> reloadFromLocal() async {
    state = _seed;
  }
}
