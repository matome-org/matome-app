// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:matome_flutter/widgetbook/widgetbook.dart'
    as _matome_flutter_widgetbook_widgetbook;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Shared widgets',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Auth',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AuthErrorBanner',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Error + loading',
                builder:
                    _matome_flutter_widgetbook_widgetbook.authFeedbackUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AuthField',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Fields + submit',
                builder:
                    _matome_flutter_widgetbook_widgetbook.authFieldsUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Inbox',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'InboxRecordingCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Done',
                builder:
                    _matome_flutter_widgetbook_widgetbook.inboxCardDoneUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Failed',
                builder: _matome_flutter_widgetbook_widgetbook
                    .inboxCardFailedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Pending upload',
                builder: _matome_flutter_widgetbook_widgetbook
                    .inboxCardPendingUploadUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Processing',
                builder: _matome_flutter_widgetbook_widgetbook
                    .inboxCardProcessingUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SyncBadge',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Sync states',
                builder:
                    _matome_flutter_widgetbook_widgetbook.syncBadgesUseCase,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
