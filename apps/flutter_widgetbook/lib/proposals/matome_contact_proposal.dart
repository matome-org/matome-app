// Proposal use-cases for the **Contact detail** view — mobile + desktop. No
// contact detail screen exists today (the Contacts feature is list + inline
// edit/delete only), so this is the first design pass.
//
// A contact carries an identity (name, and — via the extensible metadata JSON —
// company / title / email / phone / notes) plus three relationships the schema
// already models:
//   * Matomes  — role-bearing edge (organizer / attendee / speaker)
//   * Spaces   — binary membership
//   * Files    — the file↔contact tie we just added to the Files view
//
// Layout: a header (avatar, name, company·title, sync, actions) over a body that
// is one column on phones and two on desktop (identity + notes | relationships).
// Identity fields beyond name/notes are PROPOSED (they'd live in metadata) and
// are flagged in review. Static provider-free mockup. Copy switches with the
// Widgetbook Localization addon (en / ja).

import 'package:flutter/material.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ─── Model ───────────────────────────────────────────────────────────────────

enum ContactRole { organizer, attendee, speaker }

enum ContactSync { synced, onDevice }

enum _FileKind { audio, image, document }

class _MatomeRef {
  const _MatomeRef(this.title, this.when, this.role);
  final String title;
  final String when;
  final ContactRole role;
}

class _FileRef {
  const _FileRef(this.name, this.kind);
  final String name;
  final _FileKind kind;
}

class _Contact {
  const _Contact({
    required this.name,
    required this.avatarIndex,
    required this.sync,
    required this.matomes,
    required this.spaces,
    required this.files,
    this.company,
    this.title,
    this.email,
    this.phone,
    this.notes,
  });

  final String name;
  final int avatarIndex; // picks an avatar tint from the space palette
  final ContactSync sync;
  final List<_MatomeRef> matomes;
  final List<String> spaces;
  final List<_FileRef> files;
  final String? company;
  final String? title;
  final String? email;
  final String? phone;
  final String? notes;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.take(1).toString();
    return (parts.first.characters.take(1).toString() +
            parts.last.characters.take(1).toString())
        .toUpperCase();
  }
}

// ─── Localized copy ──────────────────────────────────────────────────────────

class _Copy {
  const _Copy({
    required this.edit,
    required this.merge,
    required this.delete,
    required this.actions,
    required this.contactInfo,
    required this.notes,
    required this.notesEmpty,
    required this.matomesLabel,
    required this.spacesLabel,
    required this.filesLabel,
    required this.email,
    required this.phone,
    required this.company,
    required this.addInfo,
    required this.synced,
    required this.onDevice,
    required this.organizer,
    required this.attendee,
    required this.speaker,
    required this.contact,
    required this.sparse,
  });

  final String edit;
  final String merge;
  final String delete;
  final String actions;
  final String contactInfo;
  final String notes;
  final String notesEmpty;
  final String matomesLabel;
  final String spacesLabel;
  final String filesLabel;
  final String email;
  final String phone;
  final String company;
  final String addInfo;
  final String synced;
  final String onDevice;
  final String organizer;
  final String attendee;
  final String speaker;
  final _Contact contact;
  final _Contact sparse;

  String roleLabel(ContactRole r) => switch (r) {
        ContactRole.organizer => organizer,
        ContactRole.attendee => attendee,
        ContactRole.speaker => speaker,
      };
  String syncLabel(ContactSync s) =>
      s == ContactSync.synced ? synced : onDevice;

  static const en = _Copy(
    edit: 'Edit',
    merge: 'Merge',
    delete: 'Delete',
    actions: 'More',
    contactInfo: 'Contact info',
    notes: 'Notes',
    notesEmpty: 'No notes yet',
    matomesLabel: 'Matomes',
    spacesLabel: 'Spaces',
    filesLabel: 'Files',
    email: 'Email',
    phone: 'Phone',
    company: 'Company',
    addInfo: 'Add',
    synced: 'Synced',
    onDevice: 'On device',
    organizer: 'Organizer',
    attendee: 'Attendee',
    speaker: 'Speaker',
    contact: _contactEn,
    sparse: _sparseEn,
  );

  static const ja = _Copy(
    edit: '編集',
    merge: '統合',
    delete: '削除',
    actions: 'その他',
    contactInfo: '連絡先情報',
    notes: 'メモ',
    notesEmpty: 'メモはまだありません',
    matomesLabel: 'まとめ',
    spacesLabel: 'スペース',
    filesLabel: 'ファイル',
    email: 'メール',
    phone: '電話',
    company: '会社',
    addInfo: '追加',
    synced: '同期済み',
    onDevice: '端末のみ',
    organizer: '主催者',
    attendee: '出席者',
    speaker: '登壇者',
    contact: _contactJa,
    sparse: _sparseJa,
  );
}

const _contactEn = _Contact(
  name: 'Ana Ribeiro',
  avatarIndex: 2,
  sync: ContactSync.synced,
  company: 'Acme Inc.',
  title: 'Product Lead',
  email: 'ana.ribeiro@acme.com',
  phone: '+55 11 99876-5432',
  notes: 'Met at the Q2 offsite. Owns the billing roadmap; loops in Ken for '
      'anything pricing-related. Prefers async updates.',
  matomes: [
    _MatomeRef('Client X — weekly sync', '2h', ContactRole.organizer),
    _MatomeRef('Sales call — Acme', '1d', ContactRole.attendee),
    _MatomeRef('Roadmap review', '3d', ContactRole.speaker),
  ],
  spaces: ['Marketing', 'Sales'],
  files: [
    _FileRef('Q3 roadmap.pdf', _FileKind.document),
    _FileRef('Design sync.m4a', _FileKind.audio),
    _FileRef('whiteboard.jpg', _FileKind.image),
  ],
);

const _contactJa = _Contact(
  name: '田中 美香',
  avatarIndex: 2,
  sync: ContactSync.synced,
  company: 'Acme 株式会社',
  title: 'プロダクトリード',
  email: 'mika.tanaka@acme.co.jp',
  phone: '+81 90-9876-5432',
  notes: 'Q2 のオフサイトで会った。請求まわりのロードマップ担当。価格の件は Ken に'
      '連携。非同期の更新を好む。',
  matomes: [
    _MatomeRef('クライアントX 定例会議', '2時間前', ContactRole.organizer),
    _MatomeRef('商談 — Acme', '昨日', ContactRole.attendee),
    _MatomeRef('ロードマップ確認', '3日前', ContactRole.speaker),
  ],
  spaces: ['マーケ', '営業'],
  files: [
    _FileRef('Q3ロードマップ.pdf', _FileKind.document),
    _FileRef('デザイン定例.m4a', _FileKind.audio),
    _FileRef('ホワイトボード.jpg', _FileKind.image),
  ],
);

const _sparseEn = _Contact(
  name: 'Leo',
  avatarIndex: 5,
  sync: ContactSync.onDevice,
  matomes: [
    _MatomeRef('Sales call — Acme', '1d', ContactRole.attendee),
  ],
  spaces: [],
  files: [],
);

const _sparseJa = _Contact(
  name: '高橋',
  avatarIndex: 5,
  sync: ContactSync.onDevice,
  matomes: [
    _MatomeRef('商談 — Acme', '昨日', ContactRole.attendee),
  ],
  spaces: [],
  files: [],
);

_Copy _copyOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja' ? _Copy.ja : _Copy.en;

Color _avatarColor(BuildContext context, int index) =>
    context.colors.spaceColor(index);

IconData _fileIcon(_FileKind k) => switch (k) {
      _FileKind.audio => Icons.mic_none_rounded,
      _FileKind.image => Icons.image_outlined,
      _FileKind.document => Icons.description_outlined,
    };

/// Body switches to two columns at/above this width.
const double _kWideBreakpoint = 720;

// ─── Use cases ───────────────────────────────────────────────────────────────

@widgetbook.UseCase(
  name: 'Detail — desktop',
  type: ContactDetail,
  path: '[Proposals]/Contact detail',
)
Widget detailDesktopUseCase(BuildContext context) {
  return _Surface(
    width: 920,
    child: ContactDetail(contact: _copyOf(context).contact),
  );
}

@widgetbook.UseCase(
  name: 'Detail — mobile',
  type: ContactDetail,
  path: '[Proposals]/Contact detail',
)
Widget detailMobileUseCase(BuildContext context) {
  return _Surface(
    width: 380,
    child: ContactDetail(contact: _copyOf(context).contact),
  );
}

@widgetbook.UseCase(
  name: 'Detail — sparse (minimal info)',
  type: ContactDetail,
  path: '[Proposals]/Contact detail',
)
Widget detailSparseUseCase(BuildContext context) {
  return _Surface(
    width: 920,
    child: ContactDetail(contact: _copyOf(context).sparse),
  );
}

// ─── The detail view ─────────────────────────────────────────────────────────

class ContactDetail extends StatelessWidget {
  const ContactDetail({super.key, required this.contact});

  final _Contact contact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;
    final c = _copyOf(context);

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
            _Header(contact: contact, copy: c),
            Divider(height: 1, color: colors.border),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _kWideBreakpoint;
                final identity = _IdentityColumn(contact: contact, copy: c);
                final relations = _RelationsColumn(contact: contact, copy: c);

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
  const _Header({required this.contact, required this.copy});

  final _Contact contact;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final subtitleParts = [
      if (contact.title != null) contact.title!,
      if (contact.company != null) contact.company!,
    ];

    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            initials: contact.initials,
            size: 64,
            backgroundColor: _avatarColor(context, contact.avatarIndex),
            foregroundColor: colors.onTextPrimary,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: spacing.xxs),
                Text(
                  contact.name,
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  SizedBox(height: spacing.xxs),
                  Text(
                    subtitleParts.join(' · '),
                    style: typography.bodySmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
                SizedBox(height: spacing.sm),
                _SyncChip(sync: contact.sync, copy: copy),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          // Primary action + overflow.
          _EditButton(label: copy.edit),
          _ActionsMenu(copy: copy),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      color: colors.subtleFill,
      borderRadius: BorderRadius.circular(radius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: colors.textPrimary),
              SizedBox(width: spacing.xs),
              Text(
                label,
                style: typography.label.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.copy});
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(IconData icon, String label, {Color? color}) => MenuItemButton(
          leadingIcon:
              Icon(icon, size: 18, color: color ?? colors.textSecondary),
          onPressed: () {},
          child: Text(
            label,
            style: typography.bodySmall
                .copyWith(color: color ?? colors.textPrimary),
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
        padding:
            WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: spacing.xs)),
      ),
      builder: (context, controller, child) => IconButton(
        icon: Icon(Icons.more_horiz, color: colors.textMuted),
        tooltip: copy.actions,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(Icons.edit_outlined, copy.edit),
        item(Icons.merge_outlined, copy.merge),
        Divider(height: spacing.sm, color: colors.border),
        item(Icons.delete_outline, copy.delete, color: colors.failed),
      ],
    );
  }
}

// ─── Identity column (info + notes) ──────────────────────────────────────────

class _IdentityColumn extends StatelessWidget {
  const _IdentityColumn({required this.contact, required this.copy});

  final _Contact contact;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final c = copy;
    final infoRows = <Widget>[
      if (contact.email != null)
        _InfoRow(icon: Icons.mail_outline, label: c.email, value: contact.email!),
      if (contact.phone != null)
        _InfoRow(
            icon: Icons.phone_outlined, label: c.phone, value: contact.phone!),
      if (contact.company != null)
        _InfoRow(
            icon: Icons.business_outlined,
            label: c.company,
            value: contact.company!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: c.contactInfo,
          child: infoRows.isEmpty
              ? _MutedLine(text: c.addInfo, icon: Icons.add)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: infoRows,
                ),
        ),
        _Section(
          label: c.notes,
          trailing: contact.notes != null ? c.edit : null,
          child: Text(
            contact.notes ?? c.notesEmpty,
            style: context.typography.bodySmall.copyWith(
              color: contact.notes != null
                  ? context.colors.textSecondary
                  : context.colors.textMuted,
              fontStyle:
                  contact.notes != null ? FontStyle.normal : FontStyle.italic,
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
          Icon(icon, size: 18, color: colors.textMuted),
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
                SizedBox(height: 2),
                SelectableText(
                  value,
                  style:
                      typography.bodySmall.copyWith(color: colors.textPrimary),
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
  const _RelationsColumn({required this.contact, required this.copy});

  final _Contact contact;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final c = copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: '${c.matomesLabel} · ${contact.matomes.length}',
          child: Column(
            children: [
              for (final m in contact.matomes) _MatomeRow(ref: m, copy: c),
            ],
          ),
        ),
        _Section(
          label: '${c.spacesLabel} · ${contact.spaces.length}',
          child: contact.spaces.isEmpty
              ? _MutedLine(text: '—')
              : Wrap(
                  spacing: context.spacing.xs,
                  runSpacing: context.spacing.xs,
                  children: [
                    for (final s in contact.spaces) _SpaceChip(name: s),
                  ],
                ),
        ),
        _Section(
          label: '${c.filesLabel} · ${contact.files.length}',
          last: true,
          child: contact.files.isEmpty
              ? _MutedLine(text: '—')
              : Column(
                  children: [
                    for (final f in contact.files) _FileRow(ref: f),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MatomeRow extends StatelessWidget {
  const _MatomeRow({required this.ref, required this.copy});

  final _MatomeRef ref;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.workspaces_outlined,
                  size: 18, color: colors.textSecondary),
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
              _RoleChip(role: ref.role, copy: copy),
              SizedBox(width: spacing.sm),
              Text(
                ref.when,
                style: typography.label.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.ref});
  final _FileRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Icon(_fileIcon(ref.kind), size: 18, color: colors.textSecondary),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  ref.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      typography.bodySmall.copyWith(color: colors.textPrimary),
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
    required this.label,
    required this.child,
    this.trailing,
    this.last = false,
  });

  final String label;
  final Widget child;
  final String? trailing;
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
              Text(
                trailing!,
                style: typography.label.copyWith(color: colors.accent),
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
          Icon(icon, size: 16, color: colors.accent),
          SizedBox(width: context.spacing.xxs),
          Text(text, style: typography.label.copyWith(color: colors.accent)),
        ] else
          Text(text, style: typography.bodySmall.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.copy});

  final ContactRole role;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final color = switch (role) {
      ContactRole.organizer => colors.accentDark,
      ContactRole.speaker => colors.badgeIdeas,
      ContactRole.attendee => colors.textSecondary,
    };

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Text(
        copy.roleLabel(role),
        style: typography.label.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _SpaceChip extends StatelessWidget {
  const _SpaceChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 13, color: colors.textSecondary),
          SizedBox(width: spacing.xxs),
          Text(name,
              style: typography.label.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.sync, required this.copy});

  final ContactSync sync;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final (IconData icon, Color color) = sync == ContactSync.synced
        ? (Icons.cloud_done_outlined, colors.badgePersonal)
        : (Icons.cloud_off_outlined, colors.textMuted);

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: spacing.xxs),
          Text(copy.syncLabel(sync),
              style: typography.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.width = 920});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
      ),
    );
  }
}
