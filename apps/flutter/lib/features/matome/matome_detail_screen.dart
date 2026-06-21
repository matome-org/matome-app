import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/observability/app_log.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart' show MatomeContactEntry;
import '../../core/db/daos/spaces_dao.dart';
import '../../core/db/matome_card.dart';
import '../../core/db/recording_card.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_card.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import '../home/home_filters.dart' show formatTimestamp;
import 'matome_detail_controller.dart';

/// Matome detail hub (S?, #1371) + triage actions (#1372): the "page" for a
/// Matome — the aggregate that gathers Items (recordings). Header (title, when,
/// sync hint, a contacts slot reserved for W3), the file-into-a-space CTA, the
/// child-Item list (with an add-photo action), the aggregated summary, and
/// editable notes.
///
/// Triage (ADR-0004) = enrich + FILE INTO A SPACE (default = personal). An Inbox
/// Matome surfaces a "File into a space" CTA; once filed it shows its Space and
/// allows re-filing. Tag-contacts / Share are DEFERRED to W3 — surfaced as a
/// disabled "coming soon" row, no model invented here.
///
/// Mirrors [DetailsScreen]: an `embedded` flag drops the Scaffold/AppBar so the
/// screen can later drop into the desktop two-pane (#1378).
///
/// Reachable as `/matome/:id`.
class MatomeDetailScreen extends ConsumerWidget {
  const MatomeDetailScreen({super.key, required this.id, this.embedded = false});

  final String id;

  /// When true the screen is rendered inside a desktop two-pane layout: the
  /// Scaffold/AppBar (and its back affordance) are dropped — there is no route
  /// to pop — and the body keeps its reading-width clamp.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matomeDetailControllerProvider(id));
    final colors = context.colors;

    final title = state.matome?.title ?? '';
    final body = _MatomeDetailBody(id: id);

    if (embedded) {
      return Material(color: colors.background, child: body);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          title.isEmpty ? t.matome.title : title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }
}

/// Reading-width clamp for long-form detail content on wide panes (mirrors the
/// Details screen).
const double _matomeReadingMaxWidth = 720;

class _MatomeDetailBody extends ConsumerWidget {
  const _MatomeDetailBody({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matomeDetailControllerProvider(id));
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    if (state.isLoading) {
      return Center(child: LoadingIndicator(color: colors.accent));
    }
    if (state.notFound || state.matome == null) {
      return Center(
        child: Text(
          t.matome.notFound,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final matome = state.matome!;
    final controller =
        ref.read(matomeDetailControllerProvider(id).notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _matomeReadingMaxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.xs,
            spacing.md,
            spacing.xxl + spacing.xxl,
          ),
          children: [
            _MatomeHeader(matome: matome),
            SizedBox(height: spacing.md),
            _FilingSection(
              matome: matome,
              spaces: state.spaces,
            ),
            SizedBox(height: spacing.lg),
            _RecordingsSection(
              recordings: matome.recordings,
              matomeId: id,
            ),
            SizedBox(height: spacing.lg),
            _SectionLabel(text: t.matome.summary),
            SizedBox(height: spacing.xs),
            _AggregatedSummary(matome: matome, controller: controller),
            SizedBox(height: spacing.lg),
            _NotesSection(
              description: matome.description,
              controller: controller,
            ),
            SizedBox(height: spacing.lg),
            const _DeferredActions(),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _MatomeHeader extends StatelessWidget {
  const _MatomeHeader({required this.matome});

  final MatomeItem matome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final when = formatTimestamp(
      DateTime.fromMillisecondsSinceEpoch(matome.happenedAt),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          matome.title,
          style: typography.title.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: spacing.md,
              color: colors.textMuted,
            ),
            SizedBox(width: spacing.xs),
            Text(
              when,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        // Contact-chips slot (#1375): the attached contacts as role-bearing
        // chips, plus an "Add contact" action that picks from the owner's
        // directory.
        SizedBox(height: spacing.sm),
        _ContactChipsSlot(matomeId: matome.id),
        // Sync chip renders for filed AND inbox matomes (#1407): it shows pure
        // sync state (Synced / Syncing / On device) with no triage suffix —
        // filing is the separate _FilingSection below.
        SizedBox(height: spacing.sm),
        MatomeSyncChip(
          key: const ValueKey('matome-on-device'),
          rollup: matome.syncRollup,
        ),
      ],
    );
  }
}

/// The contact-chips header slot (#1375): renders the Matome's attached
/// contacts as role-bearing chips (each with a detach affordance) and an
/// "Add contact" action that opens a directory picker. Only the local
/// `matome_contacts` edge is touched here — viewing the linked-user PROFILE and
/// SHARING the Matome stay deferred (ADR-0004 / matome-collaboration).
class _ContactChipsSlot extends ConsumerWidget {
  const _ContactChipsSlot({required this.matomeId});

  final String matomeId;

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final controller =
        ref.read(matomeDetailControllerProvider(matomeId).notifier);
    final directory = await controller.directoryContacts();
    if (!context.mounted) return;
    final attachedIds = ref
        .read(matomeDetailControllerProvider(matomeId))
        .contacts
        .map((e) => e.contact.id)
        .toSet();
    final picked = await showAppBottomSheet<ContactRow>(
      context: context,
      builder: (_) => _AddContactSheet(
        contacts: directory,
        attachedIds: attachedIds,
      ),
    );
    if (picked == null) return;
    await controller.attachContact(picked.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final contacts =
        ref.watch(matomeDetailControllerProvider(matomeId)).contacts;
    final controller =
        ref.read(matomeDetailControllerProvider(matomeId).notifier);

    return Column(
      key: const ValueKey('matome-contacts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in contacts)
              _ContactChip(
                entry: entry,
                onDelete: () => controller.detachContact(entry.contact.id),
              ),
            _AddContactButton(onPressed: () => _openPicker(context, ref)),
          ],
        ),
      ],
    );
  }
}

/// One attached contact rendered as a role-bearing chip with a detach
/// affordance.
class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.entry, required this.onDelete});

  final MatomeContactEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: ValueKey('matome-contact-${entry.contact.id}'),
      padding: EdgeInsets.fromLTRB(
        spacing.sm,
        spacing.xxs,
        spacing.xs,
        spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: spacing.md,
            color: colors.textSecondary,
          ),
          SizedBox(width: spacing.xs),
          Text(
            entry.contact.displayName,
            style: typography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(width: spacing.xs),
          Text(
            _roleLabel(entry.role),
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(width: spacing.xxs),
          InkWell(
            key: ValueKey('matome-contact-remove-${entry.contact.id}'),
            onTap: onDelete,
            borderRadius: BorderRadius.circular(radius.pill),
            child: Semantics(
              button: true,
              label: t.matome.removeContact,
              child: Icon(
                Icons.close,
                size: spacing.md,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill that opens the directory picker.
class _AddContactButton extends StatelessWidget {
  const _AddContactButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.pill),
      child: InkWell(
        key: const ValueKey('matome-add-contact'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_outlined,
                size: spacing.md,
                color: colors.accent,
              ),
              SizedBox(width: spacing.xs),
              Text(
                t.matome.addContact,
                style: typography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The directory picker sheet: the owner's contacts; already-attached contacts
/// are flagged (re-tap is a harmless idempotent no-op). Selecting one pops it
/// back to attach with the default 'attendee' role.
class _AddContactSheet extends StatelessWidget {
  const _AddContactSheet({required this.contacts, required this.attachedIds});

  final List<ContactRow> contacts;
  final Set<String> attachedIds;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.matome.addContactSheetTitle,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        if (contacts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Text(
              t.matome.noDirectoryContacts,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          )
        else
          for (final contact in contacts)
            ListTile(
              key: ValueKey('matome-pick-contact-${contact.id}'),
              leading: Icon(Icons.person_outline, color: colors.textSecondary),
              title: Text(contact.displayName),
              trailing: attachedIds.contains(contact.id)
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(contact),
            ),
      ],
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'organizer':
      return t.matome.roleOrganizer;
    case 'speaker':
      return t.matome.roleSpeaker;
    case 'attendee':
    default:
      return t.matome.roleAttendee;
  }
}

// ─── Filing (the core triage action) ─────────────────────────────────────────

/// Surfaces the triage state: an Inbox Matome gets a prominent
/// "File into a space" CTA; a filed Matome shows its Space + a "Refile" action.
/// Both open the [_FileIntoSpaceSheet]; selecting a Space calls
/// [MatomeDetailController.fileIntoSpace], which sets `matome.spaceId`.
class _FilingSection extends ConsumerWidget {
  const _FilingSection({
    required this.matome,
    required this.spaces,
  });

  final MatomeItem matome;
  final List<WorkspaceRow> spaces;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (_) => _FileIntoSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    // Read the controller AFTER the sheet (it can be autoDisposed while the
    // sheet is open) so filing persists and the hub refreshes.
    await ref
        .read(matomeDetailControllerProvider(matome.id).notifier)
        .fileIntoSpace(target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (matome.isInbox) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryButton.icon(
          key: const ValueKey('matome-file-cta'),
          onPressed: () => _openSheet(context, ref),
          icon: Icon(Icons.create_new_folder_outlined, size: spacing.md),
          label: Text(t.matome.fileIntoSpace),
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onAccent,
          ),
        ),
      );
    }

    final spaceName = spaces
        .where((w) => w.id == matome.spaceId)
        .map((w) => w.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return _FiledChip(
      spaceName: spaceName ?? matome.spaceId ?? '',
      onRefile: () => _openSheet(context, ref),
    );
  }
}

class _FiledChip extends StatelessWidget {
  const _FiledChip({required this.spaceName, required this.onRefile});

  final String spaceName;
  final VoidCallback onRefile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('matome-filed'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: spacing.md,
            color: colors.accent,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              t.matome.filedIn(space: spaceName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          AppTextButton(
            key: const ValueKey('matome-refile'),
            onPressed: onRefile,
            child: Text(t.matome.refile),
          ),
        ],
      ),
    );
  }
}

/// The file-into-a-space sheet. The default personal Space (ADR-0004) is the
/// most-prominent option — it is ordered first by the controller and flagged
/// here as the default destination.
class _FileIntoSpaceSheet extends StatelessWidget {
  const _FileIntoSpaceSheet({required this.spaces});

  final List<WorkspaceRow> spaces;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.matome.fileIntoSpaceSheetTitle,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        for (final ws in spaces)
          ListTile(
            key: ValueKey('matome-space-${ws.id}'),
            leading: Icon(
              ws.id == kDefaultPersonalSpaceId
                  ? Icons.person_outline
                  : Icons.folder_outlined,
              color: colors.textSecondary,
            ),
            title: Text(ws.name),
            trailing: ws.id == kDefaultPersonalSpaceId
                ? Text(
                    t.matome.personalSpaceHint,
                    style: typography.label.copyWith(color: colors.textMuted),
                  )
                : null,
            onTap: () => Navigator.of(context).pop(ws),
          ),
      ],
    );
  }
}

// ─── Recordings (child Items) + add photo ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      text,
      style: typography.label.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _RecordingsSection extends ConsumerWidget {
  const _RecordingsSection({
    required this.recordings,
    required this.matomeId,
  });

  final List<RecordingItem> recordings;
  final String matomeId;

  Future<void> _addPhoto(BuildContext context) async {
    // Capture the app-lifetime container BEFORE opening the picker. This
    // widget's element (and the `ref` bound to it) can be disposed while the
    // native dialog is open — `ref.read` then throws "Cannot use ref after the
    // widget was disposed" and the photo is silently lost. The root container
    // outlives the widget; the autoDispose provider is revived on read and
    // `addPhoto` persists to Drift regardless, so the live screen (watching the
    // same family key) refreshes even across a mid-picker dispose.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      AppLog.event(LogCat.action, 'addPhoto: picker opening');
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null) {
        AppLog.event(LogCat.action, 'addPhoto: cancelled (no path)');
        return; // user cancelled the picker
      }
      await container
          .read(matomeDetailControllerProvider(matomeId).notifier)
          .addPhoto(file: File(path), name: result!.files.single.name);
      AppLog.event(LogCat.action, 'addPhoto: imported ${path.split('/').last}');
    } catch (e, st) {
      AppLog.error(LogCat.action, 'addPhoto failed', e, st);
      // Surface the failure instead of swallowing it in an onPressed callback —
      // the picker/durable-copy/insert can throw on desktop and a silent no-op
      // is indistinguishable from "nothing happened".
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add photo failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel(text: t.matome.recordings)),
            AppTextButton.icon(
              key: const ValueKey('matome-add-photo'),
              onPressed: () => _addPhoto(context),
              icon: Icon(Icons.add_photo_alternate_outlined, size: spacing.md),
              label: Text(t.matome.addPhoto),
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (recordings.isEmpty)
          _EmptyHint(text: t.matome.noRecordings)
        else
          ...recordings.map(
            (item) => Padding(
              key: ValueKey('matome-item-${item.id}'),
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: _RecordingTile(item: item, matomeId: matomeId),
            ),
          ),
      ],
    );
  }
}

/// One child Item. Image Items get a media-forward tile; everything else (audio,
/// documents) reuses the shared [AppCard.recording]. Tapping opens the existing
/// recording Details route (reused, scope-tight).
class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.item, required this.matomeId});

  final RecordingItem item;
  final String matomeId;

  bool get _isImage => item.mediaType.startsWith('image');

  void _openRecording(BuildContext context) {
    // The single-recording DetailsScreen, reached from INSIDE the matome hub for
    // one Item (#1378). This is its own non-redirecting route — the old
    // recording-centric deep-links (`/inbox/:id`, `/calendar/:id`,
    // `/spaces/recording/:id`) now redirect back UP to the parent matome, so the
    // hub must use the dedicated `/recording/detail/:id` route to drill DOWN.
    context.push('/recording/detail/${item.id}');
  }

  void _previewImage(BuildContext context) {
    final path = item.filePath;
    if (path == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _ImagePreviewDialog(path: path, title: item.title),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    // Capture the app-lifetime container BEFORE the dialog: this tile's element
    // (and its `ref`) can be disposed while the confirm dialog is open — reading
    // `ref` afterwards throws "Cannot use ref after the widget was disposed" and
    // the removal silently dies (the exact addPhoto failure, one layer over).
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      // Pop via the dialog's OWN context, not the captured tile context: a
      // background rebuild (e.g. the upload waiter publishing a status while the
      // dialog is open) can deactivate the tile element, and `Navigator.of` on a
      // defunct context throws inside the button callback — the pop never runs,
      // the dialog is stuck open, and the app looks frozen.
      builder: (dialogContext) => AppDialog(
        title: Text(t.matome.removeItemTitle),
        content: Text(t.matome.removeItemBody(title: item.title)),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.matome.cancel),
          ),
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.matome.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      AppLog.event(LogCat.action, 'removeItem: cancelled ${item.id}');
      return;
    }
    try {
      AppLog.event(LogCat.action, 'removeItem: confirmed ${item.id}');
      await container
          .read(matomeDetailControllerProvider(matomeId).notifier)
          .removeItem(item.id, filePath: item.filePath);
      AppLog.event(LogCat.action, 'removeItem: done ${item.id}');
    } catch (e, st) {
      AppLog.error(LogCat.action, 'removeItem failed ${item.id}', e, st);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isImage) {
      return _ImageItemTile(
        item: item,
        onTap: () => _previewImage(context),
        onRemove: () => _confirmRemove(context),
      );
    }
    return AppCard.recording(
      card: item,
      relativeTime: formatTimestamp(
        DateTime.tryParse(item.timestamp),
      ),
      onTap: () => _openRecording(context),
    );
  }
}

/// Full-image lightbox for a photo Item.
class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.all(context.spacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: EdgeInsets.all(context.spacing.xl),
              child: Text(
                t.matome.imageUnavailable,
                style: context.typography.bodySmall
                    .copyWith(color: colors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageItemTile extends StatelessWidget {
  const _ImageItemTile({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final RecordingItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final accent = colors.badgeColor(item.badge);
    final path = item.filePath;

    final Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(radius.md),
      child: SizedBox(
        width: spacing.xxl,
        height: spacing.xxl,
        child: path == null
            ? ColoredBox(
                color: accent.withValues(alpha: 0.13),
                child: Icon(Icons.image_outlined, color: accent),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: accent.withValues(alpha: 0.13),
                  child: Icon(Icons.broken_image_outlined, color: accent),
                ),
              ),
      ),
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.lg),
      child: InkWell(
        key: ValueKey('matome-image-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.lg),
        child: Container(
          padding: EdgeInsets.all(spacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              thumb,
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('matome-image-remove-${item.id}'),
                tooltip: t.matome.remove,
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aggregated summary ──────────────────────────────────────────────────────

/// The stored aggregated summary (ADR-0003) plus its regenerate affordance. A
/// "Regenerate summary" action surfaces when the summary is flagged stale (the
/// item set / a child summary changed) OR when there is no summary yet but the
/// Matome already has Items to roll up — either way the deterministic local
/// generator can (re)compose it. Tapping calls the controller and the hub
/// reloads with the fresh summary.
class _AggregatedSummary extends StatelessWidget {
  const _AggregatedSummary({required this.matome, required this.controller});

  final MatomeItem matome;
  final MatomeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final summary = matome.aggregatedSummary;
    final hasSummary = summary != null && summary.trim().isNotEmpty;
    final hasItems = matome.recordings.isNotEmpty;
    // Offer regeneration when explicitly stale, or when nothing is stored yet
    // but there are Items to roll up (the first compose).
    final canRegenerate =
        matome.summaryStale || (!hasSummary && hasItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('matome-summary'),
          width: double.infinity,
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: colors.border),
          ),
          child: hasSummary
              ? MarkdownBody(data: summary)
              : Text(
                  t.matome.noSummary,
                  style:
                      typography.bodySmall.copyWith(color: colors.textMuted),
                ),
        ),
        if (canRegenerate) ...[
          SizedBox(height: spacing.xs),
          Row(
            children: [
              if (matome.summaryStale)
                Expanded(
                  child: Text(
                    t.matome.summaryStale,
                    style: typography.label.copyWith(color: colors.textMuted),
                  ),
                )
              else
                const Spacer(),
              AppTextButton.icon(
                key: const ValueKey('matome-regenerate-summary'),
                onPressed: controller.regenerateSummary,
                icon: Icon(Icons.refresh, size: spacing.md),
                label: Text(t.matome.regenerateSummary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Notes (editable) ────────────────────────────────────────────────────────

/// Notes block with an edit affordance. Tapping "Edit notes" swaps in an
/// [AppTextField]; "Save" persists via [MatomeDetailController.saveNotes] (which
/// marks the summary stale when the notes actually changed).
class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.description, required this.controller});

  final String? description;
  final MatomeDetailController controller;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  bool _editing = false;
  late final TextEditingController _field =
      TextEditingController(text: widget.description ?? '');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _startEdit() {
    _field.text = widget.description ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    await widget.controller.saveNotes(_field.text);
    if (!mounted) return;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final hasNotes =
        widget.description != null && widget.description!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel(text: t.matome.notes)),
            if (!_editing)
              AppTextButton.icon(
                key: const ValueKey('matome-edit-notes'),
                onPressed: _startEdit,
                icon: Icon(Icons.edit_outlined, size: spacing.md),
                label: Text(t.matome.editNotes),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (_editing) ...[
          AppTextField(
            key: const ValueKey('matome-notes-field'),
            controller: _field,
            hint: t.matome.notesHint,
            maxLines: 5,
            minLines: 3,
            textAlignVertical: TextAlignVertical.top,
          ),
          SizedBox(height: spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppTextButton(
                onPressed: () => setState(() => _editing = false),
                child: Text(t.matome.cancel),
              ),
              SizedBox(width: spacing.xs),
              PrimaryButton(
                key: const ValueKey('matome-notes-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onAccent,
                ),
                child: Text(t.matome.save),
              ),
            ],
          ),
        ] else
          Container(
            key: const ValueKey('matome-notes'),
            width: double.infinity,
            padding: EdgeInsets.all(spacing.xxs),
            child: hasNotes
                ? MarkdownBody(data: widget.description!)
                : Text(
                    t.matome.noNotes,
                    style:
                        typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
          ),
      ],
    );
  }
}

// ─── Deferred actions (W3) ───────────────────────────────────────────────────

/// Share is the only remaining DEFERRED affordance (ADR-0004 / the
/// matome-collaboration plan): surfaced as a disabled "coming soon" row so it
/// stays discoverable without inventing a sharing model. (Tag-contacts shipped
/// in #1375 — it is now the real header contact slot.)
class _DeferredActions extends StatelessWidget {
  const _DeferredActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeferredActionRow(
          key: const ValueKey('matome-share'),
          icon: Icons.ios_share_outlined,
          label: t.matome.share,
        ),
      ],
    );
  }
}

class _DeferredActionRow extends StatelessWidget {
  const _DeferredActionRow({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Opacity(
      opacity: 0.5,
      child: Row(
        children: [
          Icon(icon, size: spacing.md, color: colors.textMuted),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          SizedBox(width: spacing.xs),
          Text(
            '· ${t.matome.comingSoon}',
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      text,
      style: typography.bodySmall.copyWith(color: colors.textMuted),
    );
  }
}
