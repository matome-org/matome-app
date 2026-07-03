import 'package:flutter/material.dart';

import '../../../core/db/matome_card.dart' show MatomeSyncRollup;
import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/app_card.dart' show MatomeSyncChip;
import '../../../ui/avatar.dart';
import '../../../ui/role_chip.dart';
import '../../../ui/space_chip.dart';

/// Graduated from the approved `ContactDetail` proposal (DR-004, #1464) per the
/// DR-000 convergence procedure. PRESENTATIONAL only: it takes a
/// [ContactDetailData] view-model and emits callbacks ([onEdit], [onAction],
/// [onOpenMatome], [onOpenFile]) — NO providers, NO navigation, NO DB. The host
/// screen ([ContactDetailScreen]) builds the data from real providers and wires
/// the callbacks. Copy is slang `t.contacts.detail.*`.
///
/// Layout: a header (avatar, name, company·title, sync chip, ⋯ overflow menu
/// that hosts Edit) over a body that is one column on phones and two on desktop
/// (identity + notes | relationships), splitting at [kContactDetailWideBreakpoint].
///
/// Security: every user-controlled string (name, company, title, email, phone,
/// notes, matome/file/space names) is rendered through Flutter [Text] /
/// [SelectableText], which treats the value as inert text — there is no
/// active-content (HTML/markup) interpretation, so a hostile contact field
/// cannot inject behaviour.

/// A contact's role on a matome — re-exported from the shared [RoleChip] atom so
/// callers building [ContactMatomeRef]s have one role type.
typedef ContactMatomeRole = MatomeContactRole;

/// The contact's sync state shown by the header chip: [synced] (reconciled with
/// Core) or [onDevice] (local-only, no Core id yet).
enum ContactSyncState { synced, onDevice }

/// One matome the contact is tagged in, with the contact's role on it.
class ContactMatomeRef {
  const ContactMatomeRef({
    required this.id,
    required this.title,
    required this.role,
    this.when,
  });

  final String id;
  final String title;
  final ContactMatomeRole role;

  /// An optional relative-time / subtitle label (e.g. "2h"); may be null.
  final String? when;
}

/// One file reachable from the contact. NOTE (data reality, #1461): there is no
/// direct contact↔file edge today — files are MATOME-MEDIATED, surfaced via the
/// recordings of the contact's matomes. [id] routes the open callback.
class ContactFileRef {
  const ContactFileRef({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final ContactFileKind kind;
}

/// The media family of a [ContactFileRef], picking the row's leading glyph.
enum ContactFileKind { audio, image, document, video }

/// The overflow-menu actions the detail can emit.
enum ContactDetailAction { merge, delete }

/// The presentational view-model for [ContactDetail]. The host builds this from
/// the contact row + its `matome_contacts` / `space_contacts` edges + the
/// files reachable via its matomes.
class ContactDetailData {
  const ContactDetailData({
    required this.id,
    required this.name,
    required this.avatarIndex,
    required this.sync,
    this.company,
    this.title,
    this.email,
    this.phone,
    this.notes,
    this.matomes = const [],
    this.spaces = const [],
    this.files = const [],
  });

  final String id;
  final String name;

  /// Picks an avatar tint from the space palette (`colors.spaceColor`).
  final int avatarIndex;
  final ContactSyncState sync;
  final String? company;
  final String? title;
  final String? email;
  final String? phone;
  final String? notes;
  final List<ContactMatomeRef> matomes;
  final List<String> spaces;
  final List<ContactFileRef> files;

  /// Two initials from the display name for the avatar fallback.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

/// Body switches to two columns at/above this width (DR-004: 720dp).
const double kContactDetailWideBreakpoint = 720;

class ContactDetail extends StatelessWidget {
  const ContactDetail({
    super.key,
    required this.contact,
    this.onEdit,
    this.onAction,
    this.onOpenMatome,
    this.onOpenFile,
  });

  final ContactDetailData contact;

  /// Fires from the ⋯ overflow menu's Edit item.
  final VoidCallback? onEdit;

  /// Overflow menu actions (merge / delete).
  final ValueChanged<ContactDetailAction>? onAction;

  /// Open a matome by id from the Matomes section.
  final ValueChanged<String>? onOpenMatome;

  /// Open a file by id from the (matome-mediated) Files section.
  final ValueChanged<String>? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(contact: contact, onEdit: onEdit, onAction: onAction),
            Divider(height: 1, color: colors.border),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= kContactDetailWideBreakpoint;
                final identity = _IdentityColumn(
                  contact: contact,
                  onEditNotes: onEdit,
                );
                final relations = _RelationsColumn(
                  contact: contact,
                  onOpenMatome: onOpenMatome,
                  onOpenFile: onOpenFile,
                );

                if (!wide) {
                  return Padding(
                    padding: EdgeInsets.all(spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [identity, relations],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: identity),
                      SizedBox(width: spacing.xl),
                      Expanded(flex: 6, child: relations),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.contact, this.onEdit, this.onAction});

  final ContactDetailData contact;
  final VoidCallback? onEdit;
  final ValueChanged<ContactDetailAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final subtitleParts = [
      if (contact.title != null && contact.title!.isNotEmpty) contact.title!,
      if (contact.company != null && contact.company!.isNotEmpty)
        contact.company!,
    ];

    final rollup = contact.sync == ContactSyncState.synced
        ? MatomeSyncRollup.cloud
        : MatomeSyncRollup.onDevice;

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: spacing.xxs),
        Text(
          contact.name,
          key: const ValueKey('contact-detail-name'),
          style: typography.title.copyWith(color: colors.textPrimary),
        ),
        if (subtitleParts.isNotEmpty) ...[
          SizedBox(height: spacing.xxs),
          Text(
            subtitleParts.join(' · '),
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
        SizedBox(height: spacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: MatomeSyncChip(rollup: rollup),
        ),
      ],
    );

    // Single overflow (⋯) affordance — it already hosts Edit, so no separate
    // Edit button (that was a duplicate of the menu's Edit item).
    final actions = _ActionsMenu(onEdit: onEdit, onAction: onAction);

    final avatar = Avatar(
      initials: contact.initials,
      size: spacing.xxl + spacing.md,
      backgroundColor: context.colors.spaceColor(contact.avatarIndex),
      foregroundColor: colors.onTextPrimary,
    );

    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      // Below the wide breakpoint the action cluster wraps under the identity so
      // a narrow phone never clips the sync chip / ⋯ menu (the proposal's
      // single-row header overflowed at phone widths).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= kContactDetailWideBreakpoint;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                SizedBox(width: spacing.md),
                Expanded(child: identity),
                SizedBox(width: spacing.sm),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  SizedBox(width: spacing.md),
                  Expanded(child: identity),
                ],
              ),
              SizedBox(height: spacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({this.onEdit, this.onAction});

  final VoidCallback? onEdit;
  final ValueChanged<ContactDetailAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(
      IconData icon,
      String label,
      VoidCallback? onPressed, {
      Color? color,
      Key? key,
    }) => MenuItemButton(
      key: key,
      leadingIcon: Icon(
        icon,
        size: typography.body.fontSize,
        color: color ?? colors.textSecondary,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: typography.bodySmall.copyWith(
          color: color ?? colors.textPrimary,
        ),
      ),
    );

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radius.md),
            side: BorderSide(color: colors.border),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: spacing.xs),
        ),
      ),
      builder: (context, controller, child) => IconButton(
        key: const ValueKey('contact-detail-actions'),
        icon: Icon(Icons.more_horiz, color: colors.textMuted),
        tooltip: t.contacts.detail.actions,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(
          Icons.edit_outlined,
          t.contacts.detail.edit,
          onEdit,
          key: const ValueKey('contact-detail-edit'),
        ),
        item(
          Icons.merge_outlined,
          t.contacts.detail.merge,
          onAction == null ? null : () => onAction!(ContactDetailAction.merge),
        ),
        Divider(height: spacing.sm, color: colors.border),
        item(
          Icons.delete_outline,
          t.contacts.detail.delete,
          onAction == null ? null : () => onAction!(ContactDetailAction.delete),
          color: colors.failed,
        ),
      ],
    );
  }
}

// ─── Identity column (info + notes) ──────────────────────────────────────────

class _IdentityColumn extends StatelessWidget {
  const _IdentityColumn({required this.contact, this.onEditNotes});

  final ContactDetailData contact;
  final VoidCallback? onEditNotes;

  @override
  Widget build(BuildContext context) {
    final hasNotes = contact.notes != null && contact.notes!.isNotEmpty;
    final infoRows = <Widget>[
      if (contact.email != null && contact.email!.isNotEmpty)
        _InfoRow(
          icon: Icons.mail_outline,
          label: t.contacts.detail.email,
          value: contact.email!,
        ),
      if (contact.phone != null && contact.phone!.isNotEmpty)
        _InfoRow(
          icon: Icons.phone_outlined,
          label: t.contacts.detail.phone,
          value: contact.phone!,
        ),
      if (contact.company != null && contact.company!.isNotEmpty)
        _InfoRow(
          icon: Icons.business_outlined,
          label: t.contacts.detail.company,
          value: contact.company!,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          key: const ValueKey('contact-detail-info-section'),
          label: t.contacts.detail.contactInfo,
          child: infoRows.isEmpty
              ? _MutedLine(text: t.contacts.detail.addInfo, icon: Icons.add)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: infoRows,
                ),
        ),
        _Section(
          key: const ValueKey('contact-detail-notes-section'),
          label: t.contacts.detail.notes,
          trailing: hasNotes ? t.contacts.detail.edit : null,
          onTrailing: hasNotes ? onEditNotes : null,
          last: true,
          child: Text(
            hasNotes ? contact.notes! : t.contacts.detail.notesEmpty,
            style: context.typography.bodySmall.copyWith(
              color: hasNotes
                  ? context.colors.textSecondary
                  : context.colors.textMuted,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: typography.body.fontSize, color: colors.textMuted),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: typography.label.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: spacing.xxs),
                SelectableText(
                  value,
                  style: typography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Relations column (matomes + spaces + files) ─────────────────────────────

class _RelationsColumn extends StatelessWidget {
  const _RelationsColumn({
    required this.contact,
    this.onOpenMatome,
    this.onOpenFile,
  });

  final ContactDetailData contact;
  final ValueChanged<String>? onOpenMatome;
  final ValueChanged<String>? onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          key: const ValueKey('contact-detail-matomes-section'),
          label:
              '${t.contacts.detail.matomesLabel} · ${contact.matomes.length}',
          child: contact.matomes.isEmpty
              ? _MutedLine(text: t.contacts.detail.empty)
              : Column(
                  children: [
                    for (final m in contact.matomes)
                      _MatomeRow(
                        ref: m,
                        onTap: onOpenMatome == null
                            ? null
                            : () => onOpenMatome!(m.id),
                      ),
                  ],
                ),
        ),
        _Section(
          key: const ValueKey('contact-detail-spaces-section'),
          label: '${t.contacts.detail.spacesLabel} · ${contact.spaces.length}',
          child: contact.spaces.isEmpty
              ? _MutedLine(text: t.contacts.detail.empty)
              : Wrap(
                  spacing: context.spacing.xs,
                  runSpacing: context.spacing.xs,
                  children: [
                    for (final s in contact.spaces) SpaceChip(space: s),
                  ],
                ),
        ),
        _Section(
          key: const ValueKey('contact-detail-files-section'),
          label: '${t.contacts.detail.filesLabel} · ${contact.files.length}',
          last: true,
          child: contact.files.isEmpty
              ? _MutedLine(text: t.contacts.detail.empty)
              : Column(
                  children: [
                    for (final f in contact.files)
                      _FileRow(
                        ref: f,
                        onTap: onOpenFile == null
                            ? null
                            : () => onOpenFile!(f.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MatomeRow extends StatelessWidget {
  const _MatomeRow({required this.ref, this.onTap});

  final ContactMatomeRef ref;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('contact-detail-matome-${ref.id}'),
        borderRadius: BorderRadius.circular(radius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.workspaces_outlined,
                size: typography.body.fontSize,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  ref.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: spacing.xs),
              RoleChip(role: ref.role),
              if (ref.when != null) ...[
                SizedBox(width: spacing.sm),
                Text(
                  ref.when!,
                  style: typography.label.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.ref, this.onTap});

  final ContactFileRef ref;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final icon = switch (ref.kind) {
      ContactFileKind.audio => Icons.mic_none_rounded,
      ContactFileKind.image => Icons.image_outlined,
      ContactFileKind.document => Icons.description_outlined,
      ContactFileKind.video => Icons.video_file_outlined,
    };

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('contact-detail-file-${ref.id}'),
        borderRadius: BorderRadius.circular(radius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: typography.body.fontSize,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  ref.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small shared pieces ─────────────────────────────────────────────────────

/// A labelled section with a hairline rule between sections.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.onTrailing,
    this.last = false,
  });

  final String label;
  final Widget child;
  final String? trailing;
  final VoidCallback? onTrailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: typography.label.copyWith(
                color: colors.textMuted,
                letterSpacing: 0.6,
                fontSize: 11,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              InkWell(
                onTap: onTrailing,
                child: Text(
                  trailing!,
                  style: typography.label.copyWith(color: colors.accent),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: spacing.sm),
        child,
        if (!last) ...[
          SizedBox(height: spacing.md),
          Divider(height: 1, color: colors.border),
          SizedBox(height: spacing.md),
        ],
      ],
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: typography.bodySmall.fontSize, color: colors.accent),
          SizedBox(width: context.spacing.xxs),
          Text(text, style: typography.label.copyWith(color: colors.accent)),
        ] else
          Text(
            text,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}
