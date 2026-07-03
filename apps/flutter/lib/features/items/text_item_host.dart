import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/items_dao.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import 'matome_item_type.dart';

const double _kTextNoteReadingWidth = 720;

/// Plain-text item detail/edit host. This intentionally does not provide a rich
/// editor; it proves the file-less item arc can render and save text offline.
class TextItemHost extends ConsumerStatefulWidget {
  const TextItemHost({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<TextItemHost> createState() => _TextItemHostState();
}

class _TextItemHostState extends ConsumerState<TextItemHost> {
  late final TextEditingController _field;
  Future<MatomeItemWithPayload?>? _load;
  bool _editing = false;

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

  Future<MatomeItemWithPayload?> _loadItem() =>
      ref.read(appDatabaseProvider).itemsDao.getWithPayload(widget.itemId);

  Future<void> _save(int textContentId) async {
    await ref
        .read(appDatabaseProvider)
        .itemsDao
        .updateTextBody(textContentId, _field.text.trim());
    if (!mounted) return;
    setState(() {
      _editing = false;
      _load = _loadItem();
    });
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
      body: FutureBuilder<MatomeItemWithPayload?>(
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
                        onPressed: () => _save(text.id),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
