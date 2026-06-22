import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/role_chip.dart';
import 'contacts_controller.dart';
import 'contacts_screen.dart';
import 'widgets/contact_detail.dart';

/// The reading-width cap for the centred detail card on wide windows — keeps the
/// two-column layout from stretching uncomfortably wide on desktop.
const double _kContactDetailMaxWidth = 920;

/// Loads the full [ContactDetailData] for [contactId] from the local store: the
/// contact row + its `matome_contacts` roles + `space_contacts` memberships +
/// the files reachable via its matomes (MATOME-MEDIATED — there is no direct
/// contact↔file edge, #1461). Returns null when the contact does not exist.
final contactDetailProvider =
    FutureProvider.family<ContactDetailData?, String>((ref, contactId) async {
  final dao = ref.watch(contactsDaoProvider);
  final row = await dao.getById(contactId);
  if (row == null) return null;

  final matomeEntries = await dao.listMatomesForContact(contactId);
  final spaces = await dao.listSpacesForContact(contactId);
  final files = await dao.listFilesForContactViaMatomes(contactId);

  // The contact's index in the owner directory drives the avatar tint so it
  // matches the list tile's colour; fall back to a hash when not found.
  final ownerContacts = await dao.listContactsForOwner(row.ownerId);
  final avatarIndex = () {
    final i = ownerContacts.indexWhere((c) => c.id == contactId);
    return i >= 0 ? i : row.id.hashCode.abs();
  }();

  return ContactDetailData(
    id: row.id,
    name: row.displayName,
    avatarIndex: avatarIndex,
    sync: row.coreId != null
        ? ContactSyncState.synced
        : ContactSyncState.onDevice,
    company: row.company,
    title: row.title,
    email: row.email,
    phone: row.phone,
    notes: () {
      final n = contactNotes(row);
      return n.isEmpty ? null : n;
    }(),
    matomes: [
      for (final e in matomeEntries)
        ContactMatomeRef(
          id: e.matome.id,
          title: e.matome.title,
          role: MatomeContactRole.fromString(e.role),
        ),
    ],
    spaces: [for (final s in spaces) s.name],
    files: [
      for (final f in files)
        ContactFileRef(
          id: f.id,
          name: f.title,
          kind: _fileKind(f),
        ),
    ],
  );
});

ContactFileKind _fileKind(RecordingRow row) {
  switch (row.mediaType) {
    case 'image':
      return ContactFileKind.image;
    case 'document':
      return ContactFileKind.document;
    case 'audio':
    default:
      return ContactFileKind.audio;
  }
}

/// Host for the graduated [ContactDetail] (DR-004, #1464) at `/contacts/:id`.
/// Loads the data via [contactDetailProvider] and wires the presentational
/// widget's callbacks to navigation + the contacts CRUD controller.
class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _openMatomeFile(BuildContext context, String fileId) async {
    // A file is a recording reachable via the contact's matomes. Route by its
    // media type so a document/image never hits the audio-only detail host.
    final container = ProviderScope.containerOf(context, listen: false);
    final row =
        await container.read(recordingsDaoProvider).getRecordingById(fileId);
    if (!context.mounted) return;
    final mediaType = row?.mediaType ?? 'audio';
    final path = switch (mediaType) {
      'image' => '/recording/image/$fileId',
      'document' => '/recording/document/$fileId',
      _ => '/recording/detail/$fileId',
    };
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(contactDetailProvider(id));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          t.contacts.title,
          style: context.typography.title.copyWith(color: colors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => Center(child: LoadingIndicator(color: colors.primary)),
          error: (err, _) => _CenteredMessage(message: err.toString()),
          data: (data) {
            if (data == null) {
              return _CenteredMessage(message: t.contacts.detail.notFound);
            }
            return SingleChildScrollView(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _kContactDetailMaxWidth),
                  child: ContactDetail(
                    contact: data,
                    onEdit: () => _edit(context, ref, data.id),
                    onAction: (action) => _onAction(context, ref, data, action),
                    onOpenMatome: (matomeId) =>
                        context.push('/matome/$matomeId'),
                    onOpenFile: (fileId) => _openMatomeFile(context, fileId),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String contactId) async {
    final row = await ref.read(contactsDaoProvider).getById(contactId);
    if (row == null || !context.mounted) return;
    // Reuse the shared create/edit modal from the list screen.
    final draft = await showContactEditDialog(context, existing: row);
    if (draft == null || draft.name.trim().isEmpty) return;
    await ref.read(contactsControllerProvider.notifier).updateContact(
          id: contactId,
          displayName: draft.name,
          notes: draft.notes,
        );
    ref.invalidate(contactDetailProvider(contactId));
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    ContactDetailData data,
    ContactDetailAction action,
  ) async {
    switch (action) {
      case ContactDetailAction.delete:
        final confirmed = await showContactDeleteDialog(context, data.name);
        if (confirmed != true || !context.mounted) return;
        await ref
            .read(contactsControllerProvider.notifier)
            .deleteContact(data.id);
        if (context.mounted) context.pop();
      case ContactDetailAction.merge:
        // Merge is reserved (DR-004) — no destructive default. The affordance
        // is wired so the menu is complete; behaviour lands with a later task.
        break;
    }
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.typography.bodySmall
              .copyWith(color: context.colors.textMuted),
        ),
      ),
    );
  }
}
