/// A SINGLE, generic surface for the "add a relationship" job that today is
/// hand-rolled three different ways on the Matome detail panel (an anchored
/// dropdown for Items, a bottom-sheet list for People, another bottom-sheet
/// list for Space). It is deliberately entity-agnostic so the SAME widget backs
/// every "pick existing thing(s) of type X and link them here" flow — People,
/// Spaces, Matomes, Files — across the Matome panel AND the future Files /
/// Contacts pages.
///
/// Two operations live behind one consistent surface:
///   • LINK existing — a searchable, optionally multi-select list of
///     [RelationshipCandidate]s (already-linked ones shown + locked), with an
///     optional "Create new …" escape hatch and a teaching empty state.
///   • CREATE / source — the same surface with only [RelationshipAction] rows
///     (e.g. "Add item" → Record audio · Add photo · Add file). No list.
///
/// It is strictly presentation-only — no providers, no DB, no i18n. Every
/// user-facing string is supplied by the caller via [RelationshipPickerData], so
/// the feature layer owns wiring + localization (mirrors `MatomeDetailPanel`).
/// It lives in `lib/ui` (design-system surface, source-guard exempt) so the
/// Widgetbook use cases render the SAME widget the app will eventually open.
///
/// Presentation is frame-agnostic: the body lays out in a min-size [Column] with
/// a height-capped, scrollable candidate list, so it drops unchanged into a
/// bottom sheet (mobile) OR an anchored popover / side panel (desktop). The
/// [showRelationshipPicker] helper picks the surface by width — adaptive, one
/// component, two presentations.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_button.dart' show PrimaryButton;

/// How the candidate list resolves a choice.
enum RelationshipSelectMode {
  /// Tapping a candidate picks it and dismisses immediately — for at-most-one
  /// relations (e.g. "File into a space").
  single,

  /// Candidates toggle on/off and the user commits a batch with the confirm
  /// button — for many-valued relations (e.g. "Add people").
  multi,
}

/// A filterable entity type for the unified picker (e.g. Contacts · Files ·
/// Spaces). Supplied by the caller so the component stays entity-agnostic — it
/// never hardcodes the app's entity kinds, and the host simply omits its OWN
/// type (open the picker on a matome → pass Contacts/Files/Spaces, not Matomes).
/// When two or more types are present the picker renders a filter chip row;
/// fewer than two → no chips (the single-type flows stay unchanged).
class RelationshipType {
  const RelationshipType({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// A create/source affordance rendered ABOVE the candidate list. Either a
/// "Create new …" escape hatch for link flows, or a content source for the
/// "Add item" case (Record audio · Add photo · Add file). Tapping fires
/// [RelationshipPicker.onAction] with [id].
class RelationshipAction {
  const RelationshipAction({
    required this.id,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.tooltip,
  });

  final String id;
  final String label;
  final IconData icon;

  /// When false the row renders muted and is non-tapping — a deferred/"coming
  /// soon" affordance (e.g. Record audio before its flow ships). [tooltip]
  /// explains why on hover/long-press.
  final bool enabled;
  final String? tooltip;
}

/// One existing entity that can be linked to the host. [leading] (an avatar /
/// thumbnail) overrides [icon] when supplied. [linked] entities are shown,
/// pre-checked and LOCKED — they communicate "already related" without offering
/// a redundant re-link (detach lives on the host row, not here).
class RelationshipCandidate {
  const RelationshipCandidate({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon = Icons.circle_outlined,
    this.leading,
    this.linked = false,
    this.typeId,
  });

  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? leading;
  final bool linked;

  /// The [RelationshipType.id] this candidate belongs to, for the type filter.
  /// Null in single-type pickers (no filter row).
  final String? typeId;
}

/// Presentational data for a [RelationshipPicker]. Plain props — no providers —
/// so both the catalog (static fixtures) and the live feature layer (mapped
/// from controller state) drive the same widget.
class RelationshipPickerData {
  const RelationshipPickerData({
    required this.title,
    this.actions = const [],
    this.candidates = const [],
    this.types = const [],
    this.mode = RelationshipSelectMode.single,
    this.searchHint,
    this.emptyLabel = 'Nothing here yet',
    this.confirmLabel = 'Add',
    this.allLabel = 'All',
    this.initialTypeId,
  });

  /// The surface heading (e.g. "Add people", "File into a space", "Add item").
  final String title;

  /// Create/source rows shown above the list (may be empty).
  final List<RelationshipAction> actions;

  /// Existing entities to link (may be empty — e.g. the "Add item" sources case).
  final List<RelationshipCandidate> candidates;

  /// The filterable types present in [candidates] (Contacts · Files · Spaces …).
  /// Two or more → a filter chip row is shown and search spans every type; the
  /// host omits its OWN type. Fewer than two → no chips (single-type flows).
  final List<RelationshipType> types;

  /// Single- vs multi-select. Multi shows checkboxes + a confirm button.
  final RelationshipSelectMode mode;

  /// When non-null a search field filters [candidates] by title/subtitle. Null
  /// hides the field (short lists / source-only surfaces don't need it).
  final String? searchHint;

  /// Teaching copy shown when there are no (matching) candidates.
  final String emptyLabel;

  /// The multi-select confirm button label; the live count is appended.
  final String confirmLabel;

  /// Label for the leading "show every type" filter chip.
  final String allLabel;

  /// Pre-selects a type filter when the picker opens (e.g. open from "Add
  /// person" → contacts already filtered). Null → the "All" chip. Ignored when
  /// there is no type filter.
  final String? initialTypeId;

  bool get hasSearch => searchHint != null;
  bool get isMulti => mode == RelationshipSelectMode.multi;
  bool get hasTypeFilter => types.length > 1;
}

/// The standard relationship picker. Stateful for the search query + the
/// multi-select set; everything else is driven by [data] and the callbacks.
class RelationshipPicker extends StatefulWidget {
  const RelationshipPicker({
    super.key,
    required this.data,
    this.onAction,
    this.onPick,
    this.onConfirm,
    this.onClose,
    this.maxListHeight = 320,
  });

  final RelationshipPickerData data;

  /// Fired with a [RelationshipAction.id] when a create/source row is tapped.
  final ValueChanged<String>? onAction;

  /// Fired with a candidate id in [RelationshipSelectMode.single] (the caller
  /// dismisses the surface).
  final ValueChanged<String>? onPick;

  /// Fired with the chosen candidate ids in [RelationshipSelectMode.multi] when
  /// the confirm button is pressed.
  final ValueChanged<List<String>>? onConfirm;

  /// Optional close affordance in the header.
  final VoidCallback? onClose;

  /// Caps the scrollable candidate list so the surface stays sheet-sized.
  final double maxListHeight;

  @override
  State<RelationshipPicker> createState() => _RelationshipPickerState();
}

class _RelationshipPickerState extends State<RelationshipPicker> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  /// Active type filter id; null = the "All" chip (every type).
  String? _activeType;

  @override
  void initState() {
    super.initState();
    // Open pre-filtered when the caller asks (e.g. "Add person" → contacts) and
    // the type exists in the filter set.
    final initial = widget.data.initialTypeId;
    if (initial != null && widget.data.types.any((t) => t.id == initial)) {
      _activeType = initial;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  RelationshipPickerData get _data => widget.data;

  List<RelationshipCandidate> get _filtered {
    final q = _query.trim().toLowerCase();
    return _data.candidates.where((c) {
      if (_activeType != null && c.typeId != _activeType) return false;
      if (q.isEmpty) return true;
      final hay = '${c.title} ${c.subtitle ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _toggle(RelationshipCandidate c) {
    if (c.linked) return; // already related — locked
    setState(() {
      if (!_selected.add(c.id)) _selected.remove(c.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final data = _data;
    final filtered = _filtered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header — title + optional close.
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
              ),
              // Create-new affordance: a "+" that reveals the create/source
              // actions in a menu, so the body stays a clean link-existing list.
              if (data.actions.isNotEmpty) ...[
                _CreateActionsButton(
                  actions: data.actions,
                  onAction: widget.onAction,
                ),
                SizedBox(width: spacing.sm),
              ],
              if (widget.onClose != null)
                InkWell(
                  key: const ValueKey('relationship-picker-close'),
                  onTap: widget.onClose,
                  mouseCursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.close,
                    size: spacing.md,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ),

        // Search.
        if (data.hasSearch)
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
            child: _SearchField(
              controller: _search,
              hint: data.searchHint!,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

        // Type filter — search every type, or narrow to one.
        if (data.hasTypeFilter)
          _FilterChips(
            types: data.types,
            allLabel: data.allLabel,
            activeId: _activeType,
            onSelect: (id) => setState(() => _activeType = id),
          ),

        // Candidate list (link existing), or the teaching empty state. Create
        // actions live behind the header "+", so the body is always the list.
        if (filtered.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.lg,
            ),
            child: Text(
              data.emptyLabel,
              textAlign: TextAlign.center,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxListHeight),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: spacing.xxs),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                return _CandidateRow(
                  candidate: c,
                  multi: data.isMulti,
                  selected: _selected.contains(c.id),
                  onTap: () => data.isMulti
                      ? _toggle(c)
                      : (c.linked ? null : widget.onPick?.call(c.id)),
                );
              },
            ),
          ),

        // Multi-select confirm.
        if (data.isMulti)
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.sm,
              spacing.lg,
              spacing.lg,
            ),
            child: PrimaryButton(
              key: const ValueKey('relationship-picker-confirm'),
              onPressed: _selected.isEmpty
                  ? null
                  : () => widget.onConfirm?.call(_selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onAccent,
              ),
              child: Text(
                _selected.isEmpty
                    ? data.confirmLabel
                    : '${data.confirmLabel} (${_selected.length})',
              ),
            ),
          )
        else
          SizedBox(height: spacing.sm),
      ],
    );
  }
}

/// A compact themed search field (leading glyph + hint). Inlined rather than
/// reusing `AppTextField` so the picker stays a self-contained design-system
/// primitive with a search-specific affordance.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return TextField(
      key: const ValueKey('relationship-picker-search'),
      controller: controller,
      onChanged: onChanged,
      style: typography.bodySmall.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: typography.bodySmall.copyWith(color: colors.textMuted),
        prefixIcon: Icon(
          Icons.search,
          size: spacing.md,
          color: colors.textMuted,
        ),
        filled: true,
        fillColor: colors.subtleFill,
        contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: BorderSide(color: colors.accent),
        ),
      ),
    );
  }
}

/// The type filter row: a horizontally scrollable strip of selectable pills —
/// an "All" pill plus one per [RelationshipType]. The active pill is filled
/// accent; the rest are outlined. Picking one narrows the candidate list (and
/// the search) to that type.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.types,
    required this.allLabel,
    required this.activeId,
    required this.onSelect,
  });

  final List<RelationshipType> types;
  final String allLabel;
  final String? activeId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return SizedBox(
      height: spacing.xl + spacing.xs,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.sm),
        children: [
          _FilterChip(
            label: allLabel,
            selected: activeId == null,
            onTap: () => onSelect(null),
          ),
          for (final type in types) ...[
            SizedBox(width: spacing.xs),
            _FilterChip(
              icon: type.icon,
              label: type.label,
              selected: activeId == type.id,
              onTap: () => onSelect(type.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// One filter pill.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final fg = selected ? colors.onAccent : colors.textSecondary;

    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(radius.pill),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(radius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.pill),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: spacing.md, color: fg),
                SizedBox(width: spacing.xxs),
              ],
              Text(label, style: typography.label.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header "+" create-actions affordance: an accent "+" that opens a menu of
/// the create/source [RelationshipAction]s, so the picker body stays a clean
/// link-existing list. Each menu entry keeps the `relationship-action-<id>` key;
/// the trigger carries `relationship-create-menu`. Deferred actions
/// ([RelationshipAction.enabled] == false) render disabled with a tooltip.
class _CreateActionsButton extends StatelessWidget {
  const _CreateActionsButton({required this.actions, required this.onAction});

  final List<RelationshipAction> actions;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius.md),
            side: BorderSide(color: colors.border),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: spacing.xs),
        ),
      ),
      builder: (context, controller, child) => InkWell(
        key: const ValueKey('relationship-create-menu'),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(radius.pill),
        child: Semantics(
          button: true,
          label: 'Create new',
          child: Icon(Icons.add, size: spacing.md, color: colors.accent),
        ),
      ),
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            key: ValueKey('relationship-action-${action.id}'),
            leadingIcon: Icon(
              action.icon,
              size: spacing.md,
              color: action.enabled ? colors.textSecondary : colors.textMuted,
            ),
            onPressed: action.enabled ? () => onAction?.call(action.id) : null,
            child: Tooltip(
              message: action.enabled ? '' : (action.tooltip ?? ''),
              child: Text(
                action.label,
                style: typography.bodySmall.copyWith(
                  color: action.enabled ? colors.textPrimary : colors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One candidate row: leading avatar/icon · title + subtitle · a trailing
/// selection affordance. Linked candidates render a muted, locked check;
/// multi-select rows toggle a filled/empty check; single-select rows just route
/// the tap.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.multi,
    required this.selected,
    required this.onTap,
  });

  final RelationshipCandidate candidate;
  final bool multi;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final c = candidate;

    final Widget trailing;
    if (c.linked) {
      trailing = Icon(
        Icons.check_circle,
        size: spacing.md,
        color: colors.textMuted,
      );
    } else if (multi) {
      trailing = Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: spacing.md,
        color: selected ? colors.accent : colors.textMuted,
      );
    } else {
      trailing = Icon(
        Icons.chevron_right,
        size: spacing.md,
        color: colors.textMuted,
      );
    }

    return InkWell(
      key: ValueKey('relationship-candidate-${c.id}'),
      onTap: c.linked ? null : onTap,
      child: Semantics(
        selected: multi ? selected : null,
        button: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              c.leading ??
                  Icon(c.icon, size: spacing.md, color: colors.textSecondary),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (c.subtitle != null && c.subtitle!.isNotEmpty)
                      Text(
                        c.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.label.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Adaptive presenter: a bottom sheet on narrow viewports, a centered dialog
/// card on wide ones — one component, two surfaces. Returns the chosen
/// candidate id (single), the chosen ids (multi), or the action id, depending on
/// which path the user took; null if dismissed. The caller maps the result back
/// onto its controller.
///
/// Not yet wired into the app — provided so the eventual feature integration has
/// a single documented entry point.
Future<RelationshipPickerResult?> showRelationshipPicker({
  required BuildContext context,
  required RelationshipPickerData data,
  double wideBreakpoint = 720,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= wideBreakpoint;

  RelationshipPicker buildPicker(BuildContext ctx) => RelationshipPicker(
    data: data,
    onAction: (id) =>
        Navigator.of(ctx).pop(RelationshipPickerResult.action(id)),
    onPick: (id) =>
        Navigator.of(ctx).pop(RelationshipPickerResult.picked([id])),
    onConfirm: (ids) =>
        Navigator.of(ctx).pop(RelationshipPickerResult.picked(ids)),
    onClose: () => Navigator.of(ctx).pop(),
  );

  if (isWide) {
    final colors = context.colors;
    final radius = context.radius;
    return showDialog<RelationshipPickerResult>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.lg),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: buildPicker(ctx),
        ),
      ),
    );
  }

  return showModalBottomSheet<RelationshipPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(child: buildPicker(ctx)),
  );
}

/// The outcome of [showRelationshipPicker].
class RelationshipPickerResult {
  const RelationshipPickerResult._({this.actionId, this.candidateIds});

  /// The user tapped a create/source [RelationshipAction].
  const RelationshipPickerResult.action(String id) : this._(actionId: id);

  /// The user chose one or more candidates.
  const RelationshipPickerResult.picked(List<String> ids)
    : this._(candidateIds: ids);

  final String? actionId;
  final List<String>? candidateIds;

  bool get isAction => actionId != null;
}
