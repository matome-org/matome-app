import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../recordings/recording_ids.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/status_badge.dart';

/// The kind of media this file represents. Drives which header is shown and the
/// default umbrella tag under the "Contents" section.
///
/// `doc` and `video` are file-host variants; callers supply their lightweight
/// media headers so no payload table or item_type split is needed.
enum FileMediaKind { audio, image, doc, video }

/// The honest, producer-INDEPENDENT state of a file's read-only Contents body
/// (audio → transcript, image → description, …).
///
/// The host projects Core's explicit processing state and the modality's typed
/// output. It never infers success from output presence or invents an in-flight
/// state for a producer that did not run.
enum ContentsState {
  /// Machine text is present — render it.
  ready,

  /// Core accepted the run but dispatch has not started.
  queued,

  /// The text is actively being generated (transcribing / describing).
  processing,

  /// Generation failed — show the per-type message and a Retry affordance.
  failed,

  /// Core completed only a strict subset of the requested output kinds.
  partial,

  /// Core could not dispatch this modality under current capabilities/policy.
  notAvailable,

  /// Generation is done (or never ran) and there is simply no content.
  empty,
}

/// Presentational view-model for [FileView].
///
/// This is intentionally free of DB rows, providers and navigation: the caller
/// (a screen / controller, wired by the follow-up integration tasks) maps its
/// own state into this shape and supplies the already-built [mediaHeader]
/// widget (e.g. an `AudioPlayerBar`, an image frame, or a doc chip). That keeps
/// [FileView] a pure, reusable composition that widget tests can pump in every
/// media/state variant without a backend.
@immutable
class FileViewData {
  const FileViewData({
    required this.title,
    required this.mediaKind,
    this.place,
    this.syncCoreId,
    this.processingStatus,
    this.mediaHeader,
    this.contentsTag,
    this.contentsText,
    this.contentsState,
    this.errorMessage,
    this.onContentsRetry,
    this.notesText,
  });

  /// File title shown in the header.
  final String title;

  /// What kind of media the file is — selects the media header and the default
  /// per-type tag for the Contents section.
  final FileMediaKind mediaKind;

  /// Optional place/location chip in the meta row (null hides the chip).
  final String? place;

  /// Core id backing the sync chip; null/absent reads as on-device.
  final int? syncCoreId;

  /// Processing status forwarded to the sync chip (e.g. `pending_upload`).
  final String? processingStatus;

  /// Pre-built media header widget for this file (audio player / image frame /
  /// doc chip). Built by the caller so [FileView] stays presentational.
  final Widget? mediaHeader;

  /// Per-type tag rendered next to the umbrella "Contents" label
  /// (e.g. "Transcript" for audio, "Description" for an image). When null a
  /// sensible default is derived from [mediaKind].
  final String? contentsTag;

  /// The machine-produced, read-only contents (audio → transcript, etc.).
  /// Null/empty renders a quiet placeholder rather than a blank section.
  final String? contentsText;

  /// Explicit honest state for the Contents body. When null it is derived from
  /// [contentsText]: present → [ContentsState.ready], otherwise
  /// [ContentsState.empty]. Hosts pass an explicit value to surface
  /// processing / failed without needing a producer to exist.
  final ContentsState? contentsState;

  /// Safe failure copy derived from the bounded persisted error code. It is
  /// rendered in Contents, never in the user-owned Notes field.
  final String? errorMessage;

  /// Retry handler for the [ContentsState.failed] state. When null the failed
  /// body renders without an actionable Retry button.
  final VoidCallback? onContentsRetry;

  /// The user-owned notes seed text. Used only when no external
  /// [FileView.notesController] is supplied.
  final String? notesText;

  /// The Contents state actually rendered: the explicit [contentsState] when
  /// supplied, otherwise derived honestly from whether machine text is present.
  ContentsState get resolvedContentsState {
    final explicit = contentsState;
    if (explicit != null) return explicit;
    final text = contentsText;
    return (text != null && text.trim().isNotEmpty)
        ? ContentsState.ready
        : ContentsState.empty;
  }
}

/// FileView — the token-native, reusable file-detail composition promoted from
/// the approved `[Proposals]/File view` mockup.
///
/// Composition (top → bottom):
///   header (title)
///   meta row (place chip + sync chip)
///   media header (swapped by [FileViewData.mediaKind] — supplied by the caller)
///   "Contents" section (umbrella label + per-type tag, machine, READ-ONLY)
///   "Notes" section (user-owned, EDITABLE)
///
/// This widget is strictly presentational: it reads its theme through
/// `context.colors/spacing/radius/typography` only and never touches a DB,
/// provider or the navigator. Per-file Summary is intentionally absent (removed
/// by design).
///
/// Extension points left for the follow-up integration tasks:
///   * #1438 (image routing): pass an image frame as [FileViewData.mediaHeader]
///     with `mediaKind: FileMediaKind.image` — no change to this widget.
///   * #1439 (remove Summary + default-focus Contents): Summary is already
///     absent here; "default focus" is a screen-level concern (autofocus the
///     notes field / scroll target) handled by the hosting screen.
///   * #1440 (Contents state machine): swap [FileViewData.contentsText] for a
///     richer contents slot / state — the read-only Contents body is isolated
///     in [_ContentsSection] so a state-driven body can replace the Text.
/// Reading-width clamp for the file card (mirrors the matome letter's reading
/// width). A named primitive so it is a reviewed design-system size, not an
/// ad-hoc inline literal.
const double _kFileReadingMaxWidth = 920;

/// Frames file-detail content as a bordered reading CARD — the shared
/// presentation used by BOTH the reading pane and the full-screen file detail,
/// so a file reads as a card (surface, border) consistent with the matome
/// letter card and the ContactDetail card — not an edge-to-edge view.
///
/// [fill] true (the reading pane) lets the card FILL the available width to
/// match the contact pane; false (full screen) clamps + centres it to a reading
/// width.
Widget fileReadingCard(
  BuildContext context, {
  required Widget child,
  bool fill = false,
}) {
  final colors = context.colors;
  final spacing = context.spacing;
  final radius = context.radius;
  final card = Container(
    margin: EdgeInsets.all(spacing.md),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.lg),
      border: Border.all(color: colors.border),
    ),
    child: child,
  );
  // The card hugs its content (its [FileView] child shrink-wraps); the PAGE
  // scrolls, so the card no longer stretches to fill the pane height.
  final framed = fill
      ? card
      : Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kFileReadingMaxWidth),
            child: card,
          ),
        );
  return SingleChildScrollView(child: framed);
}

class FileView extends StatefulWidget {
  const FileView({
    super.key,
    required this.data,
    this.notesController,
    this.onNotesChanged,
    this.notesReadOnly = false,
    this.shrinkWrap = false,
  });

  final FileViewData data;

  /// Optional externally-owned controller for the Notes field. When omitted,
  /// [FileView] owns one seeded from [FileViewData.notesText].
  final TextEditingController? notesController;

  /// Fired on every Notes edit so the host can track dirty state / persist.
  final ValueChanged<String>? onNotesChanged;

  /// Renders the Notes field as read-only (host can toggle edit mode).
  final bool notesReadOnly;

  /// When true the inner list shrink-wraps (and stops scrolling) so a hosting
  /// card hugs the content height instead of filling the viewport.
  final bool shrinkWrap;

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  TextEditingController? _ownedController;

  TextEditingController get _notesController =>
      widget.notesController ?? _ensureOwnedController();

  TextEditingController _ensureOwnedController() {
    return _ownedController ??= TextEditingController(
      text: widget.data.notesText ?? '',
    );
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final data = widget.data;

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.all(spacing.md),
      children: [
        _Header(title: data.title),
        SizedBox(height: spacing.sm),
        _MetaRow(
          place: data.place,
          coreId: data.syncCoreId,
          processingStatus: data.processingStatus,
        ),
        if (data.mediaHeader != null) ...[
          SizedBox(height: spacing.md),
          data.mediaHeader!,
        ],
        SizedBox(height: spacing.lg),
        _ContentsSection(
          tag: data.contentsTag ?? _defaultContentsTag(data.mediaKind),
          mediaKind: data.mediaKind,
          state: data.resolvedContentsState,
          text: data.contentsText,
          errorMessage: data.errorMessage,
          onRetry: data.onContentsRetry,
        ),
        SizedBox(height: spacing.lg),
        _NotesSection(
          controller: _notesController,
          onChanged: widget.onNotesChanged,
          readOnly: widget.notesReadOnly,
        ),
      ],
    );
  }

  String _defaultContentsTag(FileMediaKind kind) {
    final tags = t.fileView.contentsTag;
    return switch (kind) {
      FileMediaKind.audio => tags.transcript,
      FileMediaKind.image => tags.description,
      FileMediaKind.doc => tags.document,
      FileMediaKind.video => 'Video',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      title,
      key: const ValueKey('file-view-title'),
      style: typography.title.copyWith(color: colors.textPrimary),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.place,
    required this.coreId,
    required this.processingStatus,
  });

  final String? place;
  final int? coreId;
  final String? processingStatus;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final place = this.place;

    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (place != null && place.isNotEmpty) _PlaceChip(place: place),
        StatusBadge.sync(coreId: coreId, processingStatus: processingStatus),
        ?_processingBadge(context),
      ],
    );
  }

  Widget? _processingBadge(BuildContext context) {
    final status = processingStatus;
    if (status == null || isUploadQueuePendingStatus(status)) return null;
    final labels = t.fileView.processingState;
    final label = switch (status) {
      'queued' => labels.queued,
      'processing' => labels.processing,
      'succeeded' => labels.succeeded,
      'partial' => labels.partial,
      'failed' => labels.failed,
      'not_available' => labels.notAvailable,
      _ => null,
    };
    if (label == null) return null;
    final color = switch (status) {
      'failed' => context.colors.failed,
      'queued' || 'processing' || 'partial' => context.colors.accent,
      _ => context.colors.textSecondary,
    };
    return StatusBadge.label(
      key: ValueKey('processing-badge-$status'),
      label: label,
      color: color,
      textColor: color,
      semanticLabel: label,
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.place});

  final String place;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('file-view-place'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: typography.label.fontSize,
            color: colors.textSecondary,
          ),
          SizedBox(width: spacing.xxs),
          Text(
            place,
            style: typography.label.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A titled section shell: an uppercase-ish label row (left) with an optional
/// trailing tag, then the section body. Shared by Contents and Notes so the two
/// sections read as a consistent stack.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    this.tag,
    super.key,
  });

  final String label;
  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final tag = this.tag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
            if (tag != null) ...[SizedBox(width: spacing.xs), _Tag(label: tag)],
          ],
        ),
        SizedBox(height: spacing.sm),
        child,
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: Text(
        label,
        style: typography.label.copyWith(color: colors.accentDark),
      ),
    );
  }
}

/// The read-only Contents body as a producer-independent state machine.
///
/// The host hands us a [ContentsState] derived from the recording's own fields;
/// we map (state × [mediaKind]) to honest, token-native copy. Crucially the
/// image path with no description renders the EMPTY state ("No description yet")
/// rather than a fake "Describing…", because its producer is deferred.
class _ContentsSection extends StatelessWidget {
  const _ContentsSection({
    required this.tag,
    required this.mediaKind,
    required this.state,
    required this.text,
    required this.errorMessage,
    required this.onRetry,
  });

  final String tag;
  final FileMediaKind mediaKind;
  final ContentsState state;
  final String? text;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    return _Section(
      key: const ValueKey('file-view-contents'),
      label: t.fileView.contents,
      tag: tag,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: colors.subtleFill,
          borderRadius: BorderRadius.circular(radius.md),
          border: Border.all(color: colors.border),
        ),
        child: _body(context),
      ),
    );
  }

  /// The per-type status copy for the non-ready states. The slang accessor
  /// classes for audio/image/doc are distinct generated types, so we flatten to
  /// a record of the three strings rather than annotate a single return type.
  ({String processing, String failed, String empty}) _status() {
    final status = t.fileView.contentsStatus;
    return switch (mediaKind) {
      FileMediaKind.audio => (
        processing: status.audio.processing,
        failed: status.audio.failed,
        empty: status.audio.empty,
      ),
      FileMediaKind.image => (
        processing: status.image.processing,
        failed: status.image.failed,
        empty: status.image.empty,
      ),
      FileMediaKind.doc => (
        processing: status.doc.processing,
        failed: status.doc.failed,
        empty: status.doc.empty,
      ),
      FileMediaKind.video => (
        processing: status.doc.processing,
        failed: status.doc.failed,
        empty: status.doc.empty,
      ),
    };
  }

  Widget _body(BuildContext context) {
    final text = this.text;
    // A ready state with no text degrades to empty so we never render a blank
    // body claiming to be ready.
    final hasText = text != null && text.trim().isNotEmpty;
    final effective = (state == ContentsState.ready && !hasText)
        ? ContentsState.empty
        : state;
    final status = _status();

    return switch (effective) {
      ContentsState.ready => _ReadyBody(text: text!),
      ContentsState.queued => _ProcessingBody(
        label: t.fileView.processingState.queued,
        priorText: hasText ? text : null,
      ),
      ContentsState.processing => _ProcessingBody(
        label: status.processing,
        priorText: hasText ? text : null,
      ),
      ContentsState.failed => _FailedBody(
        label: errorMessage ?? status.failed,
        onRetry: onRetry,
        priorText: hasText ? text : null,
      ),
      ContentsState.partial => _PartialBody(
        label: t.fileView.processingState.partial,
        text: hasText ? text : null,
        onRetry: onRetry,
      ),
      ContentsState.notAvailable => _FailedBody(
        label: t.fileView.processingState.notAvailable,
        onRetry: onRetry,
      ),
      ContentsState.empty => _EmptyBody(label: status.empty),
    };
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      text,
      key: const ValueKey('file-view-contents-ready'),
      style: typography.body.copyWith(color: colors.textPrimary),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      label,
      key: const ValueKey('file-view-contents-empty'),
      style: typography.body.copyWith(color: colors.textMuted),
    );
  }
}

class _ProcessingBody extends StatelessWidget {
  const _ProcessingBody({required this.label, this.priorText});

  final String label;
  final String? priorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    return Column(
      key: const ValueKey('file-view-contents-processing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LoadingIndicator(
              size: typography.body.fontSize,
              strokeWidth: spacing.xxs,
              color: colors.accent,
            ),
            SizedBox(width: spacing.sm),
            Flexible(
              child: Text(
                label,
                style: typography.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
        if (priorText != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            priorText!,
            style: typography.body.copyWith(color: colors.textPrimary),
          ),
        ],
      ],
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({
    required this.label,
    required this.onRetry,
    this.priorText,
  });

  final String label;
  final VoidCallback? onRetry;
  final String? priorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final onRetry = this.onRetry;

    return Column(
      key: const ValueKey('file-view-contents-failed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline,
              size: typography.body.fontSize,
              color: colors.failed,
            ),
            SizedBox(width: spacing.sm),
            Flexible(
              child: Text(
                label,
                style: typography.body.copyWith(color: colors.failed),
              ),
            ),
          ],
        ),
        if (priorText != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            priorText!,
            style: typography.body.copyWith(color: colors.textPrimary),
          ),
        ],
        if (onRetry != null) ...[
          SizedBox(height: spacing.sm),
          AppTextButton.icon(
            key: const ValueKey('file-view-contents-retry'),
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: typography.body.fontSize),
            label: Text(t.common.retry),
          ),
        ],
      ],
    );
  }
}

class _PartialBody extends StatelessWidget {
  const _PartialBody({
    required this.label,
    required this.text,
    required this.onRetry,
  });

  final String label;
  final String? text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    return Column(
      key: const ValueKey('file-view-contents-partial'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: typography.label.copyWith(color: colors.accent)),
        if (text != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            text!,
            style: typography.body.copyWith(color: colors.textPrimary),
          ),
        ],
        if (onRetry != null) ...[
          SizedBox(height: spacing.sm),
          AppTextButton.icon(
            key: const ValueKey('file-view-contents-retry'),
            onPressed: onRetry,
            icon: Icon(Icons.refresh, size: typography.body.fontSize),
            label: Text(t.common.retry),
          ),
        ],
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.controller,
    required this.onChanged,
    required this.readOnly,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return _Section(
      key: const ValueKey('file-view-notes'),
      label: t.fileView.notes,
      child: AppTextField(
        controller: controller,
        hint: t.fileView.notesHint,
        enabled: !readOnly,
        onChanged: onChanged,
        minLines: 4,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
      ),
    );
  }
}
