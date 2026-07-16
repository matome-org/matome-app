import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/items_dao.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import '../home/inbox_sync.dart';
import '../recordings/recording.dart';
import '../recordings/recording_result_waiter.dart';
import 'matome_item_type.dart';

const double _kTextNoteReadingWidth = 720;

/// Plain-text item detail/edit host. This intentionally does not provide a rich
/// editor; it proves the file-less item arc can render and save text offline.
class TextItemHost extends ConsumerStatefulWidget {
  const TextItemHost({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<TextItemHost> createState() => _TextItemHostState();
}

class _TextItemHostState extends ConsumerState<TextItemHost> {
  late final TextEditingController _field;
  Future<ItemWithPayload?>? _load;
  bool _editing = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<ItemWithPayload?> _loadItem() {
    final ownerId = ref.read(currentOwnerIdProvider);
    if (ownerId == null) return Future.value(null);
    return ref.read(itemsDaoProvider).getById(widget.itemId, ownerId);
  }

  Future<void> _save() async {
    final ownerId = ref.read(currentOwnerIdProvider);
    if (ownerId == null) return;
    final dao = ref.read(itemsDaoProvider);
    await dao.updateTextBody(widget.itemId, ownerId, _field.text.trim());
    if (!mounted) return;
    setState(() {
      _editing = false;
      _load = dao.getById(widget.itemId, ownerId);
    });
  }

  Future<void> _retry(ItemWithPayload item) async {
    final coreId = item.coreId;
    final ownerId = ref.read(currentOwnerIdProvider);
    if (coreId == null || ownerId == null || _retrying) return;
    final repository = ref.read(recordingsRepositoryProvider);
    final dao = ref.read(itemsDaoProvider);
    final pollInterval = ref.read(systemPolicyProvider).pollInterval;
    setState(() => _retrying = true);
    try {
      final accepted = await repository.enqueueProcessing(coreId);
      await _applyProcessing(dao, ownerId, accepted);
      final runId = accepted.processing.runId;
      if (runId != null && accepted.processing.state.isInFlight) {
        final waiter = RecordingResultWaiter(
          recordingId: coreId,
          runId: runId,
          poll: () => repository.fetchRecording(coreId),
          initialPollInterval: pollInterval,
        );
        final RecordingResult result;
        try {
          result = await waiter.wait();
        } finally {
          waiter.cancel();
        }
        final terminal = result.recording;
        if (terminal != null) {
          await _applyProcessing(dao, ownerId, terminal, expectedRunId: runId);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
          _load = dao.getById(widget.itemId, ownerId);
        });
      }
    }
  }

  Future<void> _applyProcessing(
    ItemsDao dao,
    String ownerId,
    Recording remote, {
    String? expectedRunId,
  }) async {
    if (expectedRunId != null && remote.processing.runId != expectedRunId) {
      return;
    }
    final current = await dao.getById(widget.itemId, ownerId);
    if (current == null) return;
    await dao.updateItem(
      widget.itemId,
      ownerId,
      itemProcessingUpdate(remote, existing: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    _load ??= _loadItem();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: const Text('Text note'),
      ),
      body: FutureBuilder<ItemWithPayload?>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: LoadingIndicator(color: colors.accent));
          }

          final item = snapshot.data;
          if (item == null || item.type != MatomeItemType.text) {
            return Center(
              child: Text(
                'Text note not found',
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            );
          }

          final text = item.text!;
          if (_editing && _field.text.isEmpty) _field.text = text.body;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _kTextNoteReadingWidth,
              ),
              child: ListView(
                padding: EdgeInsets.all(spacing.md),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Text note',
                          style: typography.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (!_editing)
                        AppTextButton(
                          key: const ValueKey('text-item-edit'),
                          onPressed: () {
                            setState(() {
                              _field.text = text.body;
                              _editing = true;
                            });
                          },
                          child: const Text('Edit'),
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  if (_editing) ...[
                    AppTextField(
                      key: const ValueKey('text-item-field'),
                      controller: _field,
                      autofocus: true,
                      minLines: 8,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                    ),
                    SizedBox(height: spacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PrimaryButton(
                        key: const ValueKey('text-item-save'),
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ] else
                    SelectableText(
                      text.body,
                      style: typography.body.copyWith(
                        color: colors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  if (!_editing) ...[
                    if (item.summary case final summary?) ...[
                      SizedBox(height: spacing.lg),
                      Text(
                        t.details.summary,
                        style: typography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      SelectableText(
                        summary,
                        key: const ValueKey('text-item-processing-summary'),
                        style: typography.body.copyWith(
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (item.processingState != ProcessingState.notRequested)
                      _TextProcessingStatus(
                        state: item.processingState,
                        retrying: _retrying,
                        onRetry: () => _retry(item),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TextProcessingStatus extends StatelessWidget {
  const _TextProcessingStatus({
    required this.state,
    required this.retrying,
    required this.onRetry,
  });

  final ProcessingState state;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final labels = t.fileView.processingState;
    final label = switch (state) {
      ProcessingState.queued => labels.queued,
      ProcessingState.processing => labels.processing,
      ProcessingState.succeeded => labels.succeeded,
      ProcessingState.partial => labels.partial,
      ProcessingState.failed => labels.failed,
      ProcessingState.notAvailable => labels.notAvailable,
      ProcessingState.notRequested || ProcessingState.unknown => '',
    };
    final retryable =
        state == ProcessingState.failed ||
        state == ProcessingState.partial ||
        state == ProcessingState.notAvailable;
    return Padding(
      padding: EdgeInsets.only(top: spacing.md),
      child: Row(
        children: [
          if (state.isInFlight || retrying) ...[
            LoadingIndicator(
              size: typography.body.fontSize,
              color: colors.accent,
            ),
            SizedBox(width: spacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              style: typography.label.copyWith(
                color: state == ProcessingState.failed
                    ? colors.failed
                    : colors.textSecondary,
              ),
            ),
          ),
          if (retryable)
            AppTextButton.icon(
              key: const ValueKey('text-item-processing-retry'),
              onPressed: retrying ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.common.retry),
            ),
        ],
      ),
    );
  }
}
