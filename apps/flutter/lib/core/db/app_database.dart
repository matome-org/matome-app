import 'package:drift/drift.dart';

import '../observability/app_log.dart';
import 'connection.dart';
import 'db_encryption.dart';
import 'daos/contacts_dao.dart';
import 'daos/items_dao.dart';
import 'daos/matomes_dao.dart';
import 'daos/recording_drafts_dao.dart';
import 'daos/spaces_dao.dart';
import 'daos/workspaces_dao.dart';
import 'daos/work_queue_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Destructive canonical-Items reset. There are no deployed databases, so v22
/// intentionally rebuilds the local store instead of carrying legacy data,
/// aliases, or dual reads forward.
const int kSchemaVersion = 24;

@DriftDatabase(
  tables: [
    Workspaces,
    RecordingDrafts,
    SpaceMembers,
    Organizations,
    Matomes,
    Contacts,
    MatomeContacts,
    SpaceContacts,
    MatomeShares,
    FileBlobs,
    TextContents,
    Items,
    WorkQueue,
    ItemContacts,
  ],
  daos: [
    WorkspacesDao,
    RecordingDraftsDao,
    SpacesDao,
    MatomesDao,
    ContactsDao,
    ItemsDao,
    WorkQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({SecureKeyStore? keyStore})
    : super(openConnection(keyStore: keyStore));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      AppLog.event(LogCat.db, 'db onCreate version=$kSchemaVersion');
      await m.createAll();
      await _seedDefaultWorkspace();
    },
    onUpgrade: (m, from, to) async {
      AppLog.event(LogCat.db, 'db destructive reset $from->$to');
      if (from >= kSchemaVersion) return;

      // Reverse dependency order. The two legacy names are dropped explicitly;
      // they have no table definitions or runtime read path in the new model.
      for (final table in <String>[
        'recording_contacts',
        'work_queue',
        'item_contacts',
        'matome_shares',
        'space_contacts',
        'matome_contacts',
        'items',
        'text_contents',
        'file_blobs',
        'recordings',
        'contacts',
        'matomes',
        'organizations',
        'space_members',
        'recording_drafts',
        'workspaces',
      ]) {
        await customStatement('DROP TABLE IF EXISTS $table');
      }
      await m.createAll();
      await _seedDefaultWorkspace();
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _seedDefaultWorkspace() async {
    await into(workspaces).insert(
      WorkspacesCompanion.insert(
        id: 'ws_default_personal',
        name: 'Pessoal',
        isDefault: const Value(1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        spaceType: const Value('personal'),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
