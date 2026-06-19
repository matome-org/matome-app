import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/spaces_dao.dart';
import '../../core/db/matome_card.dart';
import '../../core/db/recording_card.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
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
              controller: controller,
            ),
            SizedBox(height: spacing.lg),
            _RecordingsSection(
              recordings: matome.recordings,
              controller: controller,
            ),
            SizedBox(height: spacing.lg),
            _SectionLabel(text: t.matome.summary),
            SizedBox(height: spacing.xs),
            _AggregatedSummary(summary: matome.aggregatedSummary),
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
        // Contact-chips slot — contacts land in W3 (#1378 nav reframe). Render
        // nothing rather than invent a contacts model; the slot is reserved.
        const _ContactChipsSlot(),
        if (matome.isInbox) ...[
          SizedBox(height: spacing.sm),
          _OnDeviceHint(localOnly: matome.isLocalOnly),
        ],
      ],
    );
  }
}

/// Placeholder for the contact chips that arrive in W3. Intentionally renders
/// nothing today — kept as a named widget so the slot is discoverable.
class _ContactChipsSlot extends StatelessWidget {
  const _ContactChipsSlot();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _OnDeviceHint extends StatelessWidget {
  const _OnDeviceHint({required this.localOnly});

  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('matome-on-device'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            localOnly ? Icons.cloud_off_outlined : Icons.inbox_outlined,
            size: spacing.md,
            color: colors.textMuted,
          ),
          SizedBox(width: spacing.xs),
          Text(
            t.matome.onDevice,
            style: typography.label.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Filing (the core triage action) ─────────────────────────────────────────

/// Surfaces the triage state: an Inbox Matome gets a prominent
/// "File into a space" CTA; a filed Matome shows its Space + a "Refile" action.
/// Both open the [_FileIntoSpaceSheet]; selecting a Space calls
/// [MatomeDetailController.fileIntoSpace], which sets `matome.spaceId`.
class _FilingSection extends StatelessWidget {
  const _FilingSection({
    required this.matome,
    required this.spaces,
    required this.controller,
  });

  final MatomeItem matome;
  final List<WorkspaceRow> spaces;
  final MatomeDetailController controller;

  Future<void> _openSheet(BuildContext context) async {
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (_) => _FileIntoSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    await controller.fileIntoSpace(target.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (matome.isInbox) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryButton.icon(
          key: const ValueKey('matome-file-cta'),
          onPressed: () => _openSheet(context),
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
      onRefile: () => _openSheet(context),
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

class _RecordingsSection extends StatelessWidget {
  const _RecordingsSection({
    required this.recordings,
    required this.controller,
  });

  final List<RecordingItem> recordings;
  final MatomeDetailController controller;

  Future<void> _addPhoto(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    await controller.addPhoto(
      file: File(path),
      name: result!.files.single.name,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: _RecordingTile(item: item),
            ),
          ),
      ],
    );
  }
}

/// One child Item. Image Items get a media-forward tile; everything else (audio,
/// documents) reuses the shared [AppCard.recording]. Tapping opens the existing
/// recording Details route (reused, scope-tight).
class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.item});

  final RecordingItem item;

  bool get _isImage => item.mediaType.startsWith('image');

  void _open(BuildContext context) {
    // Reuse the existing recording detail route. `/inbox/:id` resolves the
    // single-recording DetailsScreen regardless of the active tab.
    context.go('/inbox/${item.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return _ImageItemTile(item: item, onTap: () => _open(context));
    }
    return AppCard.recording(
      card: item,
      relativeTime: formatTimestamp(
        DateTime.tryParse(item.timestamp),
      ),
      onTap: () => _open(context),
    );
  }
}

class _ImageItemTile extends StatelessWidget {
  const _ImageItemTile({required this.item, required this.onTap});

  final RecordingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final accent = colors.badgeColor(item.badge);

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
              Container(
                width: spacing.xxl,
                height: spacing.xxl,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(radius.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  size: spacing.lg,
                  color: accent,
                ),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aggregated summary ──────────────────────────────────────────────────────

class _AggregatedSummary extends StatelessWidget {
  const _AggregatedSummary({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final hasSummary = summary != null && summary!.trim().isNotEmpty;

    return Container(
      key: const ValueKey('matome-summary'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: hasSummary
          ? MarkdownBody(data: summary!)
          : Text(
              t.matome.noSummary,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
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

/// Tag-contacts and Share are DEFERRED to W3 / the collaboration plan
/// (ADR-0004). Surfaced as disabled "coming soon" rows so the affordance is
/// discoverable without inventing a contacts/share model.
class _DeferredActions extends StatelessWidget {
  const _DeferredActions();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeferredActionRow(
          key: const ValueKey('matome-tag-contacts'),
          icon: Icons.person_add_alt_outlined,
          label: t.matome.tagContacts,
        ),
        SizedBox(height: spacing.xs),
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
