import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import 'contacts_controller.dart';

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

  /// Tapping a contact opens its detail screen at `/contacts/:id` (DR-004,
  /// #1464) — editing now lives behind the detail's Edit affordance.
  void _open(BuildContext context, ContactRow contact) {
    context.push('/contacts/${contact.id}');
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

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        backgroundColor: colors.primary,
        tooltip: t.contacts.createTitle,
        child: Icon(Icons.add, color: colors.onAccent),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
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
                  isWide: isWide,
                  onRefresh: () =>
                      ref.read(contactsControllerProvider.notifier).load(),
                  onTap: (c) => _open(context, c),
                  onLongPress: (c) => _confirmDelete(context, ref, c),
                ),
              ),
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
      return _ContactTile(
        contact: contact,
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  final ContactRow contact;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final notes = contactNotes(contact);

    return Semantics(
      button: true,
      label: 'Contact: ${contact.displayName}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        child: InkWell(
          key: ValueKey('contact-tile-${contact.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius.lg),
          child: Container(
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: spacing.xl + spacing.xs,
                  height: spacing.xl + spacing.xs,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(radius.md),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: typography.title.fontSize,
                    color: color,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        SizedBox(height: spacing.xxs),
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: spacing.md + spacing.xxs,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
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
