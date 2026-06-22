// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:matome_widgetbook/proposals/matome_contact_proposal.dart'
    as _matome_widgetbook_proposals_matome_contact_proposal;
import 'package:matome_widgetbook/proposals/matome_files_proposal.dart'
    as _matome_widgetbook_proposals_matome_files_proposal;
import 'package:matome_widgetbook/proposals/matome_letter_proposal.dart'
    as _matome_widgetbook_proposals_matome_letter_proposal;
import 'package:matome_widgetbook/proposals/matome_nav_proposal.dart'
    as _matome_widgetbook_proposals_matome_nav_proposal;
import 'package:matome_widgetbook/proposals/matome_table_proposal.dart'
    as _matome_widgetbook_proposals_matome_table_proposal;
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
        name: 'Matome panel',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomePanelAddRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Add row (accent affordance)',
                builder: _matome_widgetbook_widgetbook.matomePanelAddRowUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomePanelRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Item row (icon + meta + sync chip)',
                builder: _matome_widgetbook_widgetbook.matomePanelRowUseCase,
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
                builder: _matome_widgetbook_widgetbook.matomeSyncChipUseCase,
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
  _widgetbook.WidgetbookCategory(
    name: 'Proposals',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Contact detail',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ContactDetail',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — desktop',
                builder: _matome_widgetbook_proposals_matome_contact_proposal
                    .detailDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — mobile',
                builder: _matome_widgetbook_proposals_matome_contact_proposal
                    .detailMobileUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Detail — sparse (minimal info)',
                builder: _matome_widgetbook_proposals_matome_contact_proposal
                    .detailSparseUseCase,
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
                builder: _matome_widgetbook_proposals_matome_files_proposal
                    .gridDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Grid — mobile',
                builder: _matome_widgetbook_proposals_matome_files_proposal
                    .gridMobileUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'FilesTable',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Table — desktop',
                builder: _matome_widgetbook_proposals_matome_files_proposal
                    .tableDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — mobile (compact)',
                builder: _matome_widgetbook_proposals_matome_files_proposal
                    .tableMobileUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Matome detail',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomeActionsMenu',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Actions menu (…)',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .actionsMenuUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomeDetailPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Detail panel',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .detailPanelUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomeLetterCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Letter + panel (wide)',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .letterWithPanelWideUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Letter — filed & synced',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .letterFiledSyncedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Letter — inbox & syncing',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .letterInboxSyncingUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Letter — on device',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .letterOnDeviceUseCase,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Matome list',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'MatomeListRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Row — states',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .matomeRowStatesUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomeListView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'List — grouped',
                builder: _matome_widgetbook_proposals_matome_letter_proposal
                    .matomeListUseCase,
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
                builder: _matome_widgetbook_proposals_matome_table_proposal
                    .tableCompactUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — desktop (sortable)',
                builder: _matome_widgetbook_proposals_matome_table_proposal
                    .tableDesktopUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — empty',
                builder: _matome_widgetbook_proposals_matome_table_proposal
                    .tableEmptyUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Table — selection + bulk bar',
                builder: _matome_widgetbook_proposals_matome_table_proposal
                    .tableSelectionUseCase,
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
                builder: _matome_widgetbook_proposals_matome_nav_proposal
                    .mobileDockBareUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Mobile dock — in context',
                builder: _matome_widgetbook_proposals_matome_nav_proposal
                    .mobileDockInContextUseCase,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MatomeSidebar',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop sidebar — collapsed (rail)',
                builder: _matome_widgetbook_proposals_matome_nav_proposal
                    .desktopSidebarCollapsedUseCase,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Desktop sidebar — expanded',
                builder: _matome_widgetbook_proposals_matome_nav_proposal
                    .desktopSidebarExpandedUseCase,
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
