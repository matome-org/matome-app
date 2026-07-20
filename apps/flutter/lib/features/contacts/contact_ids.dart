/// Local-first Contact id model (matome-centric-pivot, .docs/internal/architecture.md §11 (D4) — Contacts
/// schema slice, m008).
///
/// A Contact is owner-owned and minted on device the instant it is created —
/// before any Core id can exist. We mint a UUID-based local id and reconcile
/// the Core numeric id into the separate nullable `core_id` column once the
/// Contact is synced (never a PK remap).
///
/// This mirrors [mintLocalMatomeId] / `matome_ids.dart` exactly, but uses an
/// explicit `contact_local_<uuid>` prefix so a local-only Contact is
/// recognisable by id alone (see [isLocalContactId]).
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Prefix marking a Contact id as locally-minted (no Core id yet).
const String kLocalContactIdPrefix = 'contact_local_';

/// Mints a fresh local Contact id of the form `contact_local_<uuid-v4>`.
///
/// The result is guaranteed not to collide with a stringified Core int id, so
/// any `int.tryParse(id)` call site treats it as local-only (the Core id lives
/// in the `core_id` column, NULL until reconciled).
String mintLocalContactId() => '$kLocalContactIdPrefix${_uuid.v4()}';

/// Whether [id] was minted locally (carries the [kLocalContactIdPrefix]).
///
/// A `true` result means the Contact has no Core id baked into its PK; callers
/// must read the `core_id` column (NULL ⇒ not yet reconciled) rather than
/// parsing the id. A `false` result is a legacy stringified-Core id.
bool isLocalContactId(String id) => id.startsWith(kLocalContactIdPrefix);
