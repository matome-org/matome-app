import 'package:drift/drift.dart';

@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  @override
  String get tableName => 'workspaces';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  IntColumn get isDefault =>
      integer().named('isDefault').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('createdAt')();
  TextColumn get spaceType =>
      text().named('space_type').withDefault(const Constant('personal'))();
  TextColumn get ownerId => text().named('owner_id').nullable()();
  IntColumn get isLocal =>
      integer().named('is_local').withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Capture recovery is intentionally independent from canonical Item lifetime.
@DataClassName('RecordingDraftRow')
class RecordingDrafts extends Table {
  @override
  String get tableName => 'recording_drafts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get segmentsJson => text().named('segments_json')();
  IntColumn get durationMs =>
      integer().named('duration_ms').withDefault(const Constant(0))();
  TextColumn get sessionId =>
      text().named('session_id').withDefault(const Constant('legacy'))();
  TextColumn get captureKind =>
      text().named('capture_kind').withDefault(const Constant('microphone'))();
  TextColumn get backend => text().withDefault(const Constant('record'))();
  TextColumn get stagingPath => text().named('staging_path').nullable()();
  TextColumn get finalPath => text().named('final_path').nullable()();
  TextColumn get codec => text().withDefault(const Constant('aac_lc'))();
  TextColumn get state => text().withDefault(const Constant('paused'))();
  TextColumn get heartbeatAt => text().named('heartbeat_at').nullable()();
}

@DataClassName('SpaceMemberRow')
class SpaceMembers extends Table {
  @override
  String get tableName => 'space_members';

  TextColumn get id => text()();
  TextColumn get spaceId => text().named('space_id')();
  TextColumn get userId => text().named('user_id')();
  TextColumn get role => text().withDefault(const Constant('member'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OrganizationRow')
class Organizations extends Table {
  @override
  String get tableName => 'organizations';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MatomeRow')
class Matomes extends Table {
  @override
  String get tableName => 'matomes';

  TextColumn get id => text()();
  TextColumn get spaceId => text().named('space_id').nullable()();
  TextColumn get title => text()();
  IntColumn get happenedAt => integer().named('happened_at')();
  TextColumn get description => text().nullable()();
  TextColumn get aggregatedSummary =>
      text().named('aggregated_summary').nullable()();
  BoolColumn get summaryStale =>
      boolean().named('summary_stale').withDefault(const Constant(false))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get coreId => integer().named('core_id').nullable()();
  IntColumn get archivedAt => integer().named('archived_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ContactRow')
class Contacts extends Table {
  @override
  String get tableName => 'contacts';

  TextColumn get id => text()();
  TextColumn get ownerId => text().named('owner_id')();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get company => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
  TextColumn get linkedUserId => text().named('linked_user_id').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get coreId => integer().named('core_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MatomeContactRow')
class MatomeContacts extends Table {
  @override
  String get tableName => 'matome_contacts';

  TextColumn get id => text()();
  TextColumn get matomeId => text().named('matome_id')();
  TextColumn get contactId => text().named('contact_id')();
  TextColumn get role => text().withDefault(const Constant('attendee'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {matomeId, contactId},
  ];
}

@DataClassName('SpaceContactRow')
class SpaceContacts extends Table {
  @override
  String get tableName => 'space_contacts';

  TextColumn get id => text()();
  TextColumn get spaceId => text().named('space_id')();
  TextColumn get contactId => text().named('contact_id')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {spaceId, contactId},
  ];
}

@DataClassName('MatomeShareRow')
class MatomeShares extends Table {
  @override
  String get tableName => 'matome_shares';

  TextColumn get id => text()();
  TextColumn get matomeId => text().named('matome_id')();
  TextColumn get sharedWithUserId => text().named('shared_with_user_id')();
  TextColumn get permission => text().withDefault(const Constant('read'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Canonical local-first file payload. Core upload facts live beside the
/// device-only media path and encryption envelope.
@DataClassName('FileBlobRow')
class FileBlobs extends Table {
  @override
  String get tableName => 'file_blobs';

  TextColumn get id => text()();
  IntColumn get coreId => integer().named('core_id').nullable()();
  TextColumn get storageKey => text().named('storage_key').nullable()();
  TextColumn get filename => text().nullable()();
  TextColumn get originalExtension =>
      text().named('original_extension').nullable()();
  TextColumn get contentType => text().named('content_type').nullable()();
  IntColumn get byteSize =>
      integer().named('byte_size').withDefault(const Constant(0))();
  TextColumn get checksumSha256 => text().named('checksum_sha256').nullable()();
  TextColumn get mediaType => text().named('media_type')();
  IntColumn get duration => integer().nullable()();
  TextColumn get uploadState =>
      text().named('upload_state').withDefault(const Constant('pending'))();
  IntColumn get uploadGeneration =>
      integer().named('upload_generation').withDefault(const Constant(1))();
  IntColumn get uploadedAt => integer().named('uploaded_at').nullable()();
  TextColumn get multipartContext =>
      text().named('multipart_context').nullable()();
  TextColumn get openPolicy => text()
      .named('open_policy')
      .withDefault(const Constant('download_only'))();
  TextColumn get localPath => text().named('local_path').nullable()();
  TextColumn get wrappedFek => text().named('wrapped_fek').nullable()();
  TextColumn get fileNoncePrefix =>
      text().named('file_nonce_prefix').nullable()();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(true))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TextContentRow')
class TextContents extends Table {
  @override
  String get tableName => 'text_contents';

  TextColumn get id => text()();
  IntColumn get coreId => integer().named('core_id').nullable()();
  TextColumn get body => text()();
  TextColumn get acceptedBody => text().named('accepted_body').nullable()();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(true))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

/// Canonical local-first Item. The local id never changes; Core identity is
/// reconciled into [coreId]. Placement supports loose, direct Space, and Matome
/// membership with Matome placement taking precedence in the UI resolver.
@DataClassName('ItemRow')
class Items extends Table {
  @override
  String get tableName => 'items';

  TextColumn get id => text()();
  IntColumn get coreId => integer().named('core_id').nullable()();
  TextColumn get ownerId => text().named('owner_id')();
  TextColumn get clientId => text().named('client_id')();
  TextColumn get clientFingerprint =>
      text().named('client_fingerprint').nullable()();
  TextColumn get workspaceId => text().named('workspace_id').nullable()();
  TextColumn get matomeId => text().named('matome_id').nullable()();
  IntColumn get position => integer().nullable()();
  TextColumn get itemType => text().named('item_type')();
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  TextColumn get notes => text().nullable()();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
  TextColumn get processingState => text()
      .named('processing_state')
      .withDefault(const Constant('not_requested'))();
  TextColumn get processingRunId =>
      text().named('processing_run_id').nullable()();
  IntColumn get processingAttempt =>
      integer().named('processing_attempt').withDefault(const Constant(0))();
  IntColumn get sourceRevision =>
      integer().named('source_revision').withDefault(const Constant(1))();
  IntColumn get acceptedSourceRevision => integer()
      .named('accepted_source_revision')
      .withDefault(const Constant(0))();
  IntColumn get processingConfigRevision =>
      integer().named('processing_config_revision').nullable()();
  TextColumn get processingOutputs =>
      text().named('processing_outputs').withDefault(const Constant('{}'))();
  TextColumn get processingRequestedOutputs => text()
      .named('processing_requested_outputs')
      .withDefault(const Constant('[]'))();
  TextColumn get processingError =>
      text().named('processing_error').nullable()();
  TextColumn get processingErrorCode =>
      text().named('processing_error_code').nullable()();
  TextColumn get fileBlobId => text().named('file_blob_id').nullable()();
  TextColumn get textContentId => text().named('text_content_id').nullable()();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(true))();
  TextColumn get syncState =>
      text().named('sync_state').withDefault(const Constant('local_saved'))();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {ownerId, matomeId, position},
    {ownerId, clientId},
  ];
}

/// Durable executor state for every device-owned asynchronous operation.
/// Mutable canonical state remains on the Item, while revisioned text work also
/// snapshots its submitted body/version so replay never reads a newer edit.
@DataClassName('WorkQueueRow')
class WorkQueue extends Table {
  @override
  String get tableName => 'work_queue';

  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get itemId => text().named('item_id')();
  TextColumn get dedupeKey => text().named('dedupe_key')();
  TextColumn get state => text()();
  TextColumn get stage => text()();
  TextColumn get dependsOn => text().named('depends_on').nullable()();
  TextColumn get operationBody => text().named('operation_body').nullable()();
  IntColumn get submittedSourceRevision =>
      integer().named('submitted_source_revision').nullable()();
  IntColumn get expectedSourceRevision =>
      integer().named('expected_source_revision').nullable()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get availableAt => integer().named('available_at')();
  TextColumn get leaseOwner => text().named('lease_owner').nullable()();
  IntColumn get leaseUntil => integer().named('lease_until').nullable()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get errorCode => text().named('error_code').nullable()();
  TextColumn get blockedReason => text().named('blocked_reason').nullable()();
  IntColumn get configRevision =>
      integer().named('config_revision').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {dedupeKey},
  ];
}

/// Device-side direct Item-to-Contact relation retained for current Files and
/// Contacts behavior. It does not recreate the removed recording domain.
@DataClassName('ItemContactRow')
class ItemContacts extends Table {
  @override
  String get tableName => 'item_contacts';

  TextColumn get id => text()();
  TextColumn get itemId => text().named('item_id')();
  TextColumn get contactId => text().named('contact_id')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, contactId},
  ];
}
