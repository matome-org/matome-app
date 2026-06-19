import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/auth_state.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart';
import '../../core/providers.dart';

const _uuid = Uuid();

/// Placeholder owner id used when no authenticated user is resolved (e.g. in
/// widget tests, or before session restore completes). Real ownership keys off
/// the signed-in user's Core id (`user_<id>`); contacts minted under the
/// placeholder are still listed by the same owner so the directory is never
/// empty for the lack of an id. Linked-user / sharing / ACL stays deferred
/// (#1373) — `owner_id` is unenforced metadata today.
const String kPlaceholderContactOwnerId = 'user_local';

/// Drives the Contacts tab (#1374): the owner's manual directory of [Contact],
/// backed by Drift via [ContactsDao]. Display source is ALWAYS Drift.
///
/// Owner id is derived from the authenticated user ([authStateProvider]) —
/// `user_<coreId>` — and falls back to [kPlaceholderContactOwnerId] when no
/// session is resolved. Manual CRUD only; the linked-user / sharing / ACL
/// surface is deferred per #1373.
class ContactsController extends StateNotifier<AsyncValue<List<ContactRow>>> {
  ContactsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  ContactsDao get _dao => _ref.read(contactsDaoProvider);

  /// The current owner id: `user_<coreId>` for a signed-in user, otherwise the
  /// single-user placeholder.
  String get ownerId {
    final user = _ref.read(authStateProvider).user;
    return user == null ? kPlaceholderContactOwnerId : 'user_${user.id}';
  }

  /// (Re)load the owner's contacts and publish them. Mounted-guarded so a load
  /// that resolves after the notifier is disposed (e.g. a fast test tear-down)
  /// is dropped instead of throwing.
  Future<void> load() async {
    final next = await AsyncValue.guard(
      () => _dao.listContactsForOwner(ownerId),
    );
    if (mounted) state = next;
  }

  /// Create a contact under the current owner and refresh. A blank display name
  /// is ignored (no-op), matching the Spaces create guard.
  Future<void> createContact({
    required String displayName,
    String notes = '',
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) return;
    await _dao.create(
      ContactsCompanion.insert(
        id: 'contact_local_${_uuid.v4()}',
        ownerId: ownerId,
        displayName: name,
        metadata: Value(_encodeNotes(notes)),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await load();
  }

  /// Update a contact's display name and notes, then refresh. A blank display
  /// name is ignored.
  Future<void> updateContact({
    required String id,
    required String displayName,
    String notes = '',
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) return;
    await _dao.updateContact(
      id,
      ContactsCompanion(
        displayName: Value(name),
        metadata: Value(_encodeNotes(notes)),
      ),
    );
    await load();
  }

  /// Delete a contact and refresh.
  Future<void> deleteContact(String id) async {
    await _dao.deleteContact(id);
    await load();
  }

  /// Minimal `metadata` JSON: a single `notes` field. An empty note round-trips
  /// to the table's `{}` default.
  String _encodeNotes(String notes) {
    final trimmed = notes.trim();
    if (trimmed.isEmpty) return '{}';
    return jsonEncode({'notes': trimmed});
  }
}

/// Reads the optional `notes` field out of a contact's `metadata` JSON blob.
/// Returns an empty string when absent or unparseable, so the edit form and any
/// subtitle never throw on a malformed/legacy blob.
String contactNotes(ContactRow contact) {
  try {
    final decoded = jsonDecode(contact.metadata);
    if (decoded is Map && decoded['notes'] is String) {
      return decoded['notes'] as String;
    }
  } catch (_) {
    // Malformed metadata — treat as no notes.
  }
  return '';
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, AsyncValue<List<ContactRow>>>(
  (ref) => ContactsController(ref),
);
