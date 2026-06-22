// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:matome_widgetbook/foundations_stories.dart'
    as _matome_widgetbook_foundations_stories;
import 'package:matome_widgetbook/widgetbook.dart'
    as _matome_widgetbook_widgetbook;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Foundations',
    children: [
      _widgetbook.WidgetbookComponent(
        name: 'AppTypography',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Typography',
            builder: _matome_widgetbook_foundations_stories.typographyUseCase,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'Icons',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Icons',
            builder: _matome_widgetbook_foundations_stories.iconsUseCase,
          ),
        ],
      ),
      _widgetbook.WidgetbookComponent(
        name: 'MatomeColors',
        useCases: [
          _widgetbook.WidgetbookUseCase(
            name: 'Colors',
            builder: _matome_widgetbook_foundations_stories.colorsUseCase,
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Widgets',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Auth',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AuthScaffold',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Scaffold (form column + back)',
                builder: _matome_widgetbook_widgetbook.authScaffoldUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Contact detail',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ContactDetail',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — desktop',
                builder:
                    _matome_widgetbook_widgetbook.contactDetailDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — mobile',
                builder:
                    _matome_widgetbook_widgetbook.contactDetailMobileUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — sparse (minimal info)',
                builder:
                    _matome_widgetbook_widgetbook.contactDetailSparseUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Design system',
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
              _widgetbook.WidgetbookComponent(
                name: 'AuthField',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Field (labeled + obscured)',
                    builder: _matome_widgetbook_widgetbook.authFieldUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'AuthSubmitButton',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Submit button (idle · loading · disabled)',
                    builder:
                        _matome_widgetbook_widgetbook.authSubmitButtonUseCase,
                  ),
                ],
              ),
            ],
          ),
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
                    builder:
                        _matome_widgetbook_widgetbook.appTextButtonsUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'PrimaryButton',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Primary states',
                    builder:
                        _matome_widgetbook_widgetbook.primaryButtonsUseCase,
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
                    builder:
                        _matome_widgetbook_widgetbook.appCardCalendarUseCase,
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
                    builder: _matome_widgetbook_widgetbook
                        .appCardPendingUploadUseCase,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'Processing',
                    builder:
                        _matome_widgetbook_widgetbook.appCardProcessingUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'Details',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'AudioPlayerBar',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Player — playing (12:04)',
                    builder: _matome_widgetbook_widgetbook
                        .audioPlayerBarPlayingUseCase,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'Player — unavailable',
                    builder: _matome_widgetbook_widgetbook
                        .audioPlayerBarUnavailableUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'FileActionsMenu',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'File overflow menu (delete-only)',
                    builder: _matome_widgetbook_widgetbook
                        .detailsFileActionsMenuUseCase,
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
                    builder:
                        _matome_widgetbook_widgetbook.loadingIndicatorUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'File view',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'FileTypeChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Document media header',
                    builder: _matome_widgetbook_widgetbook.fileTypeChipUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'Files chrome',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'FileActionsMenu',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Per-file overflow menu',
                    builder: _matome_widgetbook_widgetbook
                        .filesFileActionsMenuUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'FilesBulkBar',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Bulk bar (selection active)',
                    builder: _matome_widgetbook_widgetbook.filesBulkBarUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'FilesEmptyState',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Empty state (no files)',
                    builder:
                        _matome_widgetbook_widgetbook.filesEmptyStateUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'FilesMutedDash',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Muted dash (absent value)',
                    builder:
                        _matome_widgetbook_widgetbook.filesMutedDashUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'FilesUndoBar',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Undo bar (after delete)',
                    builder: _matome_widgetbook_widgetbook.filesUndoBarUseCase,
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
            name: 'Matome',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'MatomeActionsMenu',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Matome overflow menu',
                    builder:
                        _matome_widgetbook_widgetbook.matomeActionsMenuUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'MatomeAddFab',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Add FAB',
                    builder: _matome_widgetbook_widgetbook.matomeAddFabUseCase,
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
                    builder:
                        _matome_widgetbook_widgetbook.appBottomSheetUseCase,
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
            name: 'Panel atoms',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'MatomePanelAddRow',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Add row (accent affordance)',
                    builder:
                        _matome_widgetbook_widgetbook.matomePanelAddRowUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'MatomePanelRow',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Item row (icon + meta + sync chip)',
                    builder:
                        _matome_widgetbook_widgetbook.matomePanelRowUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'MatomePanelSection',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Section (label + divider)',
                    builder:
                        _matome_widgetbook_widgetbook.matomePanelSectionUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'Relations',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'MatomeChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Matome chip (filled · Unfiled)',
                    builder: _matome_widgetbook_widgetbook.matomeChipUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'PeopleCluster',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'People cluster (overlap · +N overflow)',
                    builder: _matome_widgetbook_widgetbook.peopleClusterUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'RoleChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Role chip (organizer · speaker · attendee)',
                    builder: _matome_widgetbook_widgetbook.roleChipUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'SpaceChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Space chip (outlined · Inbox)',
                    builder: _matome_widgetbook_widgetbook.spaceChipUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'Status',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'MatomeSyncChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Sync chip',
                    builder:
                        _matome_widgetbook_widgetbook.matomeSyncChipUseCase,
                  ),
                ],
              ),
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
      _widgetbook.WidgetbookFolder(
        name: 'File view',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'FileView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Audio — empty',
                builder:
                    _matome_widgetbook_widgetbook.fileViewAudioEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Audio — failed',
                builder:
                    _matome_widgetbook_widgetbook.fileViewAudioFailedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Audio — processing',
                builder: _matome_widgetbook_widgetbook
                    .fileViewAudioProcessingUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Audio — ready (transcript)',
                builder:
                    _matome_widgetbook_widgetbook.fileViewAudioReadyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Image — empty',
                builder:
                    _matome_widgetbook_widgetbook.fileViewImageEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Image — ready (description)',
                builder:
                    _matome_widgetbook_widgetbook.fileViewImageReadyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Notes — empty',
                builder:
                    _matome_widgetbook_widgetbook.fileViewNotesEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Notes — filled',
                builder:
                    _matome_widgetbook_widgetbook.fileViewNotesFilledUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Files',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'FilesGrid',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Grid — desktop',
                builder: _matome_widgetbook_widgetbook.filesGridDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Grid — mobile',
                builder: _matome_widgetbook_widgetbook.filesGridMobileUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'FilesTable',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Table — desktop',
                builder: _matome_widgetbook_widgetbook.filesTableDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — mobile (compact)',
                builder: _matome_widgetbook_widgetbook.filesTableMobileUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Local-first spaces',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'FilesScopeFilter',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Files scope filter (All · Loose · In a space)',
                builder: _matome_widgetbook_widgetbook.filesScopeFilterUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'InboxItemCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Inbox entry (loose item · draft matome)',
                builder: _matome_widgetbook_widgetbook.inboxItemCardUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookFolder(
            name: 'Scenes',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'FilesScopeFilter',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Scene — Files (scope filter)',
                    builder: _matome_widgetbook_widgetbook.sceneFilesUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'InboxItemCard',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Scene — Inbox (loose items + draft matomes)',
                    builder: _matome_widgetbook_widgetbook.sceneInboxUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'SpaceSyncChip',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Scene — Promote to cloud consent',
                    builder: _matome_widgetbook_widgetbook
                        .scenePromoteConsentUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'SpaceSyncChoice',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Scene — New space sheet (local default)',
                    builder:
                        _matome_widgetbook_widgetbook.sceneNewSpaceSheetUseCase,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'SpaceSyncTile',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'Scene — Spaces (local / cloud + promote)',
                    builder: _matome_widgetbook_widgetbook.sceneSpacesUseCase,
                  ),
                ],
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SpaceSyncChip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Sync chip (local · promoting · cloud)',
                builder: _matome_widgetbook_widgetbook.spaceSyncChipUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SpaceSyncChoice',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Create sync choice (local default)',
                builder: _matome_widgetbook_widgetbook.spaceSyncChoiceUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SpaceSyncTile',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Space tile (local + promote · cloud)',
                builder: _matome_widgetbook_widgetbook.spaceSyncTileUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Matome detail',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomeDetailPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Detail panel — filed',
                builder: _matome_widgetbook_widgetbook.detailPanelFiledUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Detail panel — inbox',
                builder: _matome_widgetbook_widgetbook.detailPanelInboxUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Matome table',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomeTable',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Table — compact (mobile)',
                builder:
                    _matome_widgetbook_widgetbook.matomeTableCompactUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — desktop (sortable)',
                builder:
                    _matome_widgetbook_widgetbook.matomeTableDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — empty',
                builder: _matome_widgetbook_widgetbook.matomeTableEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — selection + bulk bar',
                builder:
                    _matome_widgetbook_widgetbook.matomeTableSelectionUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Navigation',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomeBottomDock',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Mobile dock — bare',
                builder: _matome_widgetbook_widgetbook.mobileDockBareUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Mobile dock — in context',
                builder:
                    _matome_widgetbook_widgetbook.mobileDockInContextUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomeSidebar',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop sidebar — collapsed (rail)',
                builder: _matome_widgetbook_widgetbook
                    .desktopSidebarCollapsedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop sidebar — expanded',
                builder:
                    _matome_widgetbook_widgetbook.desktopSidebarExpandedUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Relationship picker',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'RelationshipPicker',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Add anything (mixed · type filter)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerMixedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Add files (multi · search)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerFilesUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Add people (multi · search)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerPeopleUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Add to a matome (Files page · reuse)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerMatomeUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Empty (no candidates yet)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'File into a space (single)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerSpaceUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Pre-filtered (opened from Add person)',
                builder: _matome_widgetbook_widgetbook
                    .relationshipPickerPrefilteredUseCase,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
