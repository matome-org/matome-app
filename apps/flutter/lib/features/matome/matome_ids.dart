/// Local-first Matome id model (matome-centric-pivot, ADR-0003 / ADR-0004).
///
/// A Matome is minted the instant capture/import finishes — before it is
/// triaged into a Space and therefore before any Core id can exist. We mint a
/// UUID-based local id and reconcile the Core numeric id into the separate
/// nullable `coreId` column once the Matome is filed into a (synced) Space and
/// the first sync succeeds (never a PK remap).
///
/// This mirrors [mintLocalRecordingId] / `recording_ids.dart` exactly, but uses
/// an explicit `mat_local_<uuid>` prefix so a local-only (untriaged / Inbox)
/// Matome is recognisable by id alone (see [isLocalMatomeId]).
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Prefix marking a Matome id as locally-minted (no Core id yet — Inbox /
/// untriaged, `spaceId == null`, never synced; see ADR-0004).
const String kLocalMatomeIdPrefix = 'mat_local_';

/// Mints a fresh local Matome id of the form `mat_local_<uuid-v4>`.
///
/// The result is guaranteed not to collide with a stringified Core int id, so
/// the m007 backfill and any `int.tryParse(id)` call site treat it as
/// local-only (the Core id lives in the `coreId` column, NULL until the Matome
/// is triaged into a Space and reconciled).
String mintLocalMatomeId() => '$kLocalMatomeIdPrefix${_uuid.v4()}';

/// Whether [id] was minted locally (carries the [kLocalMatomeIdPrefix]).
///
/// A `true` result means the Matome has no Core id baked into its PK; callers
/// must read the `coreId` column (NULL ⇒ not yet reconciled / still in the
/// Inbox) rather than parsing the id. A `false` result is a legacy stringified-
/// Core id.
bool isLocalMatomeId(String id) => id.startsWith(kLocalMatomeIdPrefix);
