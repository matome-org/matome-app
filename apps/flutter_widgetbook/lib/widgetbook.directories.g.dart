// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:matome_widgetbook/widgetbook.dart'
    as _matome_widgetbook_widgetbook;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Catalog',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Avatars',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'Avatar',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Icon + initials',
                builder: _matome_widgetbook_widgetbook.avatarsUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Buttons',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppTextButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Text actions',
                builder: _matome_widgetbook_widgetbook.appTextButtonsUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'PrimaryButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Primary states',
                builder: _matome_widgetbook_widgetbook.primaryButtonsUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Cards',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Calendar row',
                builder: _matome_widgetbook_widgetbook.appCardCalendarUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Done',
                builder: _matome_widgetbook_widgetbook.appCardDoneUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Failed',
                builder: _matome_widgetbook_widgetbook.appCardFailedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Pending upload',
                builder:
                    _matome_widgetbook_widgetbook.appCardPendingUploadUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Processing',
                builder: _matome_widgetbook_widgetbook.appCardProcessingUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Feedback',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'EmptyState',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Centered message',
                builder: _matome_widgetbook_widgetbook.emptyStateUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'LoadingIndicator',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Spinner sizes',
                builder: _matome_widgetbook_widgetbook.loadingIndicatorUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Inputs',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppTextField',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Labeled states',
                builder: _matome_widgetbook_widgetbook.appTextFieldsUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Overlays',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppBottomSheet',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Action list',
                builder: _matome_widgetbook_widgetbook.appBottomSheetUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppDialog',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Confirmation',
                builder: _matome_widgetbook_widgetbook.appDialogUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Status',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'StatusBadge',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Sync states',
                builder: _matome_widgetbook_widgetbook.statusBadgesUseCase,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Shared widgets',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Auth',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppTextField',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Fields + submit',
                builder: _matome_widgetbook_widgetbook.authFieldsUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AuthErrorBanner',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Error + loading',
                builder: _matome_widgetbook_widgetbook.authFeedbackUseCase,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
