import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/settings/reading_pane.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/master_detail_scaffold.dart';
import 'contact_detail_screen.dart';
import 'contacts_controller.dart';
import 'widgets/contact_detail.dart';
import 'widgets/contact_tile.dart';

/// Opens the shared create/edit contact modal, returning the entered
/// [ContactDraft] (or null if dismissed). Shared by the list screen and the
/// detail screen so both edit through the same form.
Future<ContactDraft?> showContactEditDialog(
  BuildContext context, {
  ContactRow? existing,
}) {
  return showDialog<ContactDraft>(
    context: context,
    builder: (_) => _ContactDialog(existing: existing),
  );
}

/// Opens the delete-confirmation modal, returning true when confirmed.
Future<bool?> showContactDeleteDialog(BuildContext context, String name) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DeleteContactDialog(name: name),
  );
}

/// Selected contact for the master-detail reading pane (W4, #1544). On expanded
/// widths with the reading pane on the right, tapping a contact sets this instead
/// of navigating, so the directory stays visible beside the [_ContactsPaneDetail]
/// reading pane (the selected contact's real [ContactDetail]). Narrower widths
/// (and the flag-OFF reality) ignore it and route to `/contacts/:id` as before —
/// the [MasterDetailScaffold.selectsOnTap] predicate in [ContactsScreen._open] is
/// the single source of truth.
final contactsSelectionProvider = StateProvider<String?>((ref) => null);

/// Width past which the contact list reflows into a multi-column grid (desktop /
/// web), mirroring the Spaces tab.
const double _wideBreakpoint = 1000;

/// Contacts tab (#1374). Offline-first directory of the owner's contacts, driven
/// from Drift via [contactsControllerProvider]. The FAB opens a create-contact
/// modal; long-press confirms deletion; tapping a contact opens the edit modal.
///
/// Manual entry only — linked-user linking / sharing / ACL is deferred (#1373).
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showContactEditDialog(context);
    if (result == null || result.name.trim().isEmpty) return;
    await ref.read(contactsControllerProvider.notifier).createContact(
          displayName: result.name,
          notes: result.notes,
        );
  }

  /// Open a contact. W4 (#1544): the unified [MasterDetailScaffold] owns the
  /// layout decision; its [selectsOnTap] predicate is the single source of truth
  /// for whether a tap selects in-pane (pane visible) or navigates full-screen.
  /// When the pane is hidden (flag OFF, narrow width, or pane = off) it opens
  /// the contact's detail screen at `/contacts/:id` (DR-004, #1464) — editing
  /// lives behind the detail's Edit affordance there.
  void _open(BuildContext context, WidgetRef ref, ContactRow contact) {
    if (FeatureFlags.masterDetailLayout &&
        MasterDetailScaffold.selectsOnTap(
          context,
          ref.read(readingPaneModeProvider(ReadingPaneSurface.contacts)),
        )) {
      ref.read(contactsSelectionProvider.notifier).state = contact.id;
      return;
    }
    context.push('/contacts/${contact.id}');
  }

  /// Clear the reading-pane selection so it never points at a contact that is no
  /// longer in the loaded list (deleted, or absent after a reload). Only
  /// meaningful behind the master-detail layout (where the pane is driven by
  /// [contactsSelectionProvider]); a no-op cost otherwise.
  void _clearSelection(WidgetRef ref) {
    if (ref.read(contactsSelectionProvider) != null) {
      ref.read(contactsSelectionProvider.notifier).state = null;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ContactRow contact,
  ) async {
    final confirmed = await showContactDeleteDialog(context, contact.displayName);
    if (confirmed != true) return;
    await ref.read(contactsControllerProvider.notifier).deleteContact(
          contact.id,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contactsControllerProvider);
    final colors = context.colors;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    // When the reading pane CAN be shown (flag ON, expanded width, a non-off
    // mode) the directory is the master column of a master–detail split, so it
    // must stay the proposal's vertical LIST of [ContactTile] — never the wide
    // multi-column grid (which is sized for the full window and would also
    // overflow the narrow master column once the pane opens). The grid path
    // applies ONLY when no pane is ever shown: flag OFF, off mode, or a narrow
    // width. That keys off [MasterDetailScaffold.selectsOnTap] (the single
    // source of truth) rather than whether a contact is currently selected, so
    // an onClick surface with nothing selected yet still shows the list, exactly
    // like the approved `_mdContactsList` proposal scene.
    final mode =
        ref.watch(readingPaneModeProvider(ReadingPaneSurface.contacts));
    final paneCanShow = FeatureFlags.masterDetailLayout &&
        MasterDetailScaffold.selectsOnTap(context, mode);
    final masterIsWide = paneCanShow ? false : isWide;

    // W4 (#1544): never point the reading pane at a contact that has left the
    // loaded list (deleted, or absent after a reload). Reconcile after the frame
    // so we don't mutate a provider mid-build. Only meaningful behind the flag.
    if (FeatureFlags.masterDetailLayout) {
      final selectedId = ref.watch(contactsSelectionProvider);
      final contacts = state.valueOrNull;
      if (selectedId != null &&
          contacts != null &&
          !contacts.any((c) => c.id == selectedId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clearSelection(ref);
        });
      }
    }

    final listColumn = Column(
      children: [
        _Header(total: state.valueOrNull?.length ?? 0),
        Expanded(
          child: state.when(
            loading: () =>
                Center(child: LoadingIndicator(color: colors.primary)),
            error: (err, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(context.spacing.lg),
                child: Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: context.typography.bodySmall.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
            data: (contacts) => _Body(
              contacts: contacts,
              isWide: masterIsWide,
              onRefresh: () =>
                  ref.read(contactsControllerProvider.notifier).load(),
              onTap: (c) => _open(context, ref, c),
              onLongPress: (c) => _confirmDelete(context, ref, c),
            ),
          ),
        ),
      ],
    );

    final Widget body;
    if (FeatureFlags.masterDetailLayout) {
      // W4 (#1544): the Contacts surface renders through the unified
      // [MasterDetailScaffold]. The scaffold owns the layout decision (master
      // full-width vs master + reading pane) from the per-surface
      // [readingPaneModeProvider] and the current width class; tap-vs-navigate
      // is decided by the same [selectsOnTap] predicate in [_open], so the two
      // can never drift. The pane is the selected contact's real [ContactDetail].
      final selectedId = ref.watch(contactsSelectionProvider);
      body = MasterDetailScaffold(
        master: listColumn,
        detail: selectedId != null
            ? _ContactsPaneDetail(key: ValueKey(selectedId), contactId: selectedId)
            : null,
        emptyState: const _ContactPaneEmptyState(),
        mode: mode,
      );
    } else {
      // Shipped behaviour (flag OFF): the directory, byte-for-byte unchanged.
      body = listColumn;
    }

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        // Unique hero tag: the nav shell keeps every visited branch alive in an
        // IndexedStack, so a default-tagged FAB here collides with the Spaces
        // branch's FAB and throws on the next route/dialog hero transition
        // (which silently aborted the Add-anything picker open).
        heroTag: 'contacts-create-fab',
        onPressed: () => _create(context, ref),
        backgroundColor: colors.primary,
        tooltip: t.contacts.createTitle,
        child: Icon(Icons.add, color: colors.onAccent),
      ),
      body: SafeArea(bottom: false, child: body),
    );
  }
}

/// The reading-pane detail for a selected contact (W4, #1544). Renders the SAME
/// presentational [ContactDetail] the routed [ContactDetailScreen] uses, fed off
/// the SAME data source ([contactDetailProvider]) — NOT the routed Scaffold.
/// There is no Scaffold/AppBar here: the pane is embedded beside the master, so
/// it owns no chrome. Tapping a matome/file routes the same as the routed detail;
/// the ⋯ overflow menu hosts Edit / delete (delete pops back to the empty pane).
class _ContactsPaneDetail extends ConsumerWidget {
  const _ContactsPaneDetail({super.key, required this.contactId});

  final String contactId;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final row = await ref.read(contactsDaoProvider).getById(contactId);
    if (row == null || !context.mounted) return;
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
        if (confirmed != true) return;
        await ref
            .read(contactsControllerProvider.notifier)
            .deleteContact(data.id);
        // The list re-reads from Drift; the build's post-frame reconcile clears
        // the now-stale selection so the pane falls back to its empty state.
      case ContactDetailAction.merge:
        // Merge is reserved (DR-004) — no destructive default.
        break;
    }
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref, String fileId) async {
    final row = await ref.read(recordingsDaoProvider).getRecordingById(fileId);
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
    final spacing = context.spacing;
    final typography = context.typography;
    final async = ref.watch(contactDetailProvider(contactId));

    return ColoredBox(
      color: colors.background,
      child: async.when(
        loading: () => Center(child: LoadingIndicator(color: colors.primary)),
        error: (err, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ),
        ),
        data: (data) {
          if (data == null) return const _ContactPaneEmptyState();
          return SingleChildScrollView(
            padding: EdgeInsets.all(spacing.lg),
            child: ContactDetail(
              contact: data,
              onEdit: () => _edit(context, ref),
              onAction: (action) => _onAction(context, ref, data, action),
              onOpenMatome: (matomeId) => context.push('/matome/$matomeId'),
              onOpenFile: (fileId) => _openFile(context, ref, fileId),
            ),
          );
        },
      ),
    );
  }
}

/// The "select a contact to preview" teaching placeholder shown in the reading
/// pane when nothing is selected.
class _ContactPaneEmptyState extends StatelessWidget {
  const _ContactPaneEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: spacing.xxl,
              color: colors.textMuted,
            ),
            SizedBox(height: spacing.sm),
            Text(
              t.contacts.selectHint,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'マトメ',
            style: typography.label.copyWith(
              letterSpacing: 2,
              color: colors.textSecondary,
            ),
          ),
          Text(
            t.contacts.title,
            style: typography.display.copyWith(
              color: colors.textPrimary,
            ),
          ),
          if (total > 0)
            Text(
              t.contacts.count(n: total),
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.contacts,
    required this.isWide,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  final List<ContactRow> contacts;
  final bool isWide;
  final Future<void> Function() onRefresh;
  final ValueChanged<ContactRow> onTap;
  final ValueChanged<ContactRow> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            EmptyState(
              icon: Icons.contacts_outlined,
              title: t.contacts.empty,
              message: t.contacts.emptyHint,
            ),
          ],
        ),
      );
    }

    final padding = EdgeInsets.fromLTRB(
      spacing.md,
      spacing.sm,
      spacing.md,
      spacing.xxl + spacing.xxl,
    );

    Widget tile(int index) {
      final contact = contacts[index];
      return ContactTile(
        key: ValueKey('contact-tile-${contact.id}'),
        name: contact.displayName,
        notes: contactNotes(contact),
        color: colors.spaceColor(index),
        onTap: () => onTap(contact),
        onLongPress: () => onLongPress(contact),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      child: isWide
          ? GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: spacing.xxl + spacing.lg,
                crossAxisSpacing: spacing.sm,
                mainAxisSpacing: spacing.sm,
              ),
              itemCount: contacts.length,
              itemBuilder: (context, index) => tile(index),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: contacts.length,
              separatorBuilder: (_, _) => SizedBox(height: spacing.xs),
              itemBuilder: (context, index) => tile(index),
            ),
    );
  }
}

/// The form result: the trimmed-or-raw display name plus its notes blob.
class ContactDraft {
  const ContactDraft({required this.name, required this.notes});

  final String name;
  final String notes;
}

/// Shared create / edit modal. When [existing] is non-null it pre-fills the
/// fields and titles itself as "Edit contact".
class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.existing});

  final ContactRow? existing;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.displayName ?? '');
    _notes = TextEditingController(
      text: existing == null ? '' : contactNotes(existing),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(
        ContactDraft(name: _name.text, notes: _notes.text),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final isEdit = widget.existing != null;

    return AppDialog(
      backgroundColor: colors.surface,
      title: Text(isEdit ? t.contacts.editTitle : t.contacts.createTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _name,
            label: t.contacts.nameLabel,
            hint: t.contacts.nameHint,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            controller: _notes,
            label: t.contacts.notesLabel,
            hint: t.contacts.notesHint,
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.contacts.cancel),
        ),
        PrimaryButton(
          key: const ValueKey('save-contact-confirm'),
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          child: Text(isEdit ? t.contacts.save : t.contacts.create),
        ),
      ],
    );
  }
}

class _DeleteContactDialog extends StatelessWidget {
  const _DeleteContactDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialog(
      backgroundColor: colors.surface,
      title: Text(t.contacts.deleteTitle),
      content: Text('$name\n\n${t.contacts.deleteBody}'),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.contacts.cancel),
        ),
        PrimaryButton(
          key: const ValueKey('delete-contact-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.failed),
          child: Text(t.contacts.delete),
        ),
      ],
    );
  }
}
