/// Local-first recording id model (plan #43, Wave 1).
///
/// A recording must persist with a stable local primary key the instant capture
/// finishes — before any Core id is known. We mint a UUID-based local id and
/// reconcile the Core numeric id into the separate nullable `coreId` column once
/// upload succeeds (never a PK remap).
///
/// This mirrors the existing workspace local-id precedent and the
/// `coreIdToLocalId` reconcile seam, but uses an explicit `rec_local_<uuid>`
/// prefix so a local-only row is recognisable by id alone (see
/// [isLocalRecordingId]).
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Prefix marking a recording id as locally-minted (no Core id yet).
const String kLocalRecordingIdPrefix = 'rec_local_';

/// Mints a fresh local recording id of the form `rec_local_<uuid-v4>`.
///
/// The result is guaranteed not to collide with a stringified Core int id, so
/// the m005 backfill and any `int.tryParse(id)` call site treat it as
/// local-only (Core id lives in the `coreId` column, NULL until reconciled).
String mintLocalRecordingId() => '$kLocalRecordingIdPrefix${_uuid.v4()}';

/// Whether [id] was minted locally (carries the [kLocalRecordingIdPrefix]).
///
/// A `true` result means the row has no Core id baked into its PK; callers must
/// read the `coreId` column (NULL ⇒ not yet reconciled) rather than parsing the
/// id. A `false` result is a legacy stringified-Core id.
bool isLocalRecordingId(String id) => id.startsWith(kLocalRecordingIdPrefix);

/// Local-only processing status for a recording that has been persisted on
/// device but not yet uploaded/created on Core. Distinct from the backend
/// `processing`/`done`/`failed` states (see `RecordingStatus`).
///
/// Defined here for Wave 1; Wave 2 sets it on local-first finish and Wave 4's
/// retry queue clears it once the recording reconciles.
const String kProcessingStatusPendingUpload = 'pending_upload';

/// Item-level display projections for durable queue holds. Typed scheduling and
/// retry state lives on `work_queue`; these values keep existing cards explicit.
const String kProcessingStatusBlockedSignedOut = 'blocked_signed_out';
const String kProcessingStatusBlockedOffline = 'blocked_offline';
const String kProcessingStatusBlockedLocalSpace = 'blocked_local_space';
const String kProcessingStatusBlockedParent = 'blocked_parent';
const String kProcessingStatusBlockedCore = 'blocked_core';

const Set<String> kUploadQueuePendingStatuses = <String>{
  kProcessingStatusPendingUpload,
  kProcessingStatusBlockedSignedOut,
  kProcessingStatusBlockedOffline,
  kProcessingStatusBlockedLocalSpace,
  kProcessingStatusBlockedParent,
  kProcessingStatusBlockedCore,
};

bool isUploadQueuePendingStatus(String status) =>
    kUploadQueuePendingStatuses.contains(status);
