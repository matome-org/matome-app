///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$a11y$en a11y = Translations$a11y$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
	late final Translations$nav$en nav = Translations$nav$en.internal(_root);
	late final Translations$inbox$en inbox = Translations$inbox$en.internal(_root);
	late final Translations$cardStatus$en cardStatus = Translations$cardStatus$en.internal(_root);
	late final Translations$recording$en recording = Translations$recording$en.internal(_root);
	late final Translations$details$en details = Translations$details$en.internal(_root);
	late final Translations$fileView$en fileView = Translations$fileView$en.internal(_root);
	late final Translations$matome$en matome = Translations$matome$en.internal(_root);
	late final Translations$files$en files = Translations$files$en.internal(_root);
	late final Translations$spaces$en spaces = Translations$spaces$en.internal(_root);
	late final Translations$calendar$en calendar = Translations$calendar$en.internal(_root);
	late final Translations$contacts$en contacts = Translations$contacts$en.internal(_root);
	late final Translations$satori$en satori = Translations$satori$en.internal(_root);
	late final Translations$welcome$en welcome = Translations$welcome$en.internal(_root);
	late final Translations$auth$en auth = Translations$auth$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';
}

// Path: a11y
class Translations$a11y$en {
	Translations$a11y$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get openSettings => 'Settings';

	/// en: 'Play'
	String get play => 'Play';

	/// en: 'Pause'
	String get pause => 'Pause';
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get title => 'Settings';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Theme'
	String get theme => 'Theme';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'Account'
	String get account => 'Account';

	/// en: 'Sign out'
	String get signOut => 'Sign out';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'System'
	String get themeSystem => 'System';

	/// en: 'English'
	String get langEn => 'English';

	/// en: '日本語'
	String get langJa => '日本語';

	/// en: 'Default views'
	String get views => 'Default views';

	/// en: 'Matome list'
	String get viewsMatome => 'Matome list';

	/// en: 'Files'
	String get viewsFiles => 'Files';

	/// en: 'Cards'
	String get viewCards => 'Cards';

	/// en: 'Table'
	String get viewTableMatome => 'Table';

	/// en: 'Grid'
	String get viewGrid => 'Grid';

	/// en: 'Table'
	String get viewTableFiles => 'Table';
}

// Path: nav
class Translations$nav$en {
	Translations$nav$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New'
	String get createNew => 'New';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Record audio'
	String get recordAudio => 'Record audio';

	/// en: 'Record meeting'
	String get recordMeeting => 'Record meeting';

	/// en: 'Import file'
	String get importFile => 'Import file';

	/// en: 'Add photo'
	String get addPhoto => 'Add photo';

	/// en: 'Add file'
	String get addFile => 'Add file';

	/// en: 'Collapse'
	String get collapse => 'Collapse';

	/// en: 'Expand'
	String get expand => 'Expand';
}

// Path: inbox
class Translations$inbox$en {
	Translations$inbox$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Inbox'
	String get title => 'Inbox';

	/// en: 'Search transcripts, tags, spaces…'
	String get searchPlaceholder => 'Search transcripts, tags, spaces…';

	/// en: 'No recordings found'
	String get noResults => 'No recordings found';

	/// en: 'recordings'
	String get recordings => 'recordings';

	/// en: '$n matomes'
	String matomeCount({required Object n}) => '${n} matomes';

	/// en: 'Search matomes'
	String get searchHint => 'Search matomes';

	/// en: 'No matomes yet'
	String get empty => 'No matomes yet';

	/// en: 'Matomes you capture or upload will show up here.'
	String get emptyHint => 'Matomes you capture or upload will show up here.';

	/// en: 'No matching matomes'
	String get noMatches => 'No matching matomes';

	/// en: 'Try a different search term.'
	String get noMatchesHint => 'Try a different search term.';

	/// en: 'Couldn't load matomes'
	String get loadFailed => 'Couldn\'t load matomes';

	/// en: 'Select a matome to preview'
	String get selectHint => 'Select a matome to preview';
}

// Path: cardStatus
class Translations$cardStatus$en {
	Translations$cardStatus$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Saved on device · waiting to upload'
	String get pendingUpload => 'Saved on device · waiting to upload';

	/// en: 'Transcribing…'
	String get processing => 'Transcribing…';

	/// en: 'Upload failed'
	String get failed => 'Upload failed';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'On device'
	String get onDevice => 'On device';

	/// en: 'Synced'
	String get cloud => 'Synced';

	/// en: 'Syncing'
	String get syncing => 'Syncing';

	/// en: 'Sync state'
	String get syncState => 'Sync state';
}

// Path: recording
class Translations$recording$en {
	Translations$recording$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Recording'
	String get title => 'Recording';

	/// en: 'Ready to Record'
	String get ready => 'Ready to Record';

	/// en: 'Tap the button to start recording'
	String get startHint => 'Tap the button to start recording';

	/// en: 'Tap to pause'
	String get stopHint => 'Tap to pause';

	/// en: 'Paused'
	String get paused => 'Paused';

	/// en: 'Tap to resume'
	String get resumeHint => 'Tap to resume';

	/// en: 'Saving…'
	String get processing => 'Saving…';

	/// en: 'You can leave this open or continue in the Inbox — we'll keep saving in the background.'
	String get processingHint => 'You can leave this open or continue in the Inbox — we\'ll keep saving in the background.';

	/// en: 'Continue in Inbox'
	String get processingBackground => 'Continue in Inbox';

	/// en: 'Loading…'
	String get loading => 'Loading…';

	/// en: 'Transcribing…'
	String get transcribing => 'Transcribing…';

	/// en: 'Transcription failed'
	String get transcriptionFailed => 'Transcription failed';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Resume'
	String get resume => 'Resume';

	/// en: 'Finish'
	String get finish => 'Finish';

	/// en: 'Discard recording?'
	String get discardConfirmTitle => 'Discard recording?';

	/// en: 'This recording hasn't been saved. If you leave now, the audio will be lost.'
	String get discardConfirmBody => 'This recording hasn\'t been saved. If you leave now, the audio will be lost.';

	/// en: 'Keep recording'
	String get discardConfirmKeep => 'Keep recording';

	/// en: 'Discard'
	String get discardConfirmDiscard => 'Discard';

	/// en: 'Resume recording?'
	String get draftFound => 'Resume recording?';

	/// en: 'We found an unfinished recording. Resume where you left off, or discard it.'
	String get draftHint => 'We found an unfinished recording. Resume where you left off, or discard it.';

	/// en: 'Resume'
	String get draftResume => 'Resume';

	/// en: 'Discard'
	String get draftDiscard => 'Discard';

	/// en: 'Couldn't start recording.'
	String get startFailed => 'Couldn\'t start recording.';

	/// en: 'Couldn't pause recording.'
	String get pauseFailed => 'Couldn\'t pause recording.';

	/// en: 'Couldn't resume recording.'
	String get resumeFailed => 'Couldn\'t resume recording.';

	/// en: 'Couldn't save recording.'
	String get saveFailed => 'Couldn\'t save recording.';

	/// en: 'Microphone unavailable'
	String get unsupportedTitle => 'Microphone unavailable';

	/// en: 'Audio capture isn't available on this device. Try the mobile app to record.'
	String get unsupportedHint => 'Audio capture isn\'t available on this device. Try the mobile app to record.';
}

// Path: details
class Translations$details$en {
	Translations$details$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Summary'
	String get summary => 'Summary';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'Transcript'
	String get transcript => 'Transcript';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Preview'
	String get preview => 'Preview';

	/// en: 'No summary yet.'
	String get noSummary => 'No summary yet.';

	/// en: 'No notes yet. Tap Edit to add some.'
	String get noNotes => 'No notes yet. Tap Edit to add some.';

	/// en: 'Write notes in markdown…'
	String get notesPlaceholder => 'Write notes in markdown…';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Move to space'
	String get moveToSpace => 'Move to space';

	/// en: 'More actions'
	String get moreActions => 'More actions';

	/// en: 'Delete recording'
	String get deleteConfirmTitle => 'Delete recording';

	/// en: 'This recording will be permanently removed. Continue?'
	String get deleteConfirmBody => 'This recording will be permanently removed. Continue?';

	/// en: 'Unsaved changes'
	String get unsavedTitle => 'Unsaved changes';

	/// en: 'You have unsaved changes. Do you want to discard them?'
	String get unsavedBody => 'You have unsaved changes. Do you want to discard them?';

	/// en: 'Keep editing'
	String get keepEditing => 'Keep editing';

	/// en: 'Discard'
	String get discard => 'Discard';

	/// en: 'Recording not found'
	String get notFound => 'Recording not found';

	/// en: 'Notes saved'
	String get saved => 'Notes saved';

	/// en: 'Couldn't save notes'
	String get saveFailed => 'Couldn\'t save notes';

	/// en: 'Couldn't play audio'
	String get audioFailed => 'Couldn\'t play audio';

	/// en: 'Audio unavailable'
	String get audioUnavailable => 'Audio unavailable';
}

// Path: fileView
class Translations$fileView$en {
	Translations$fileView$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Contents'
	String get contents => 'Contents';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'Write your own notes…'
	String get notesHint => 'Write your own notes…';

	/// en: 'View fullscreen'
	String get viewFullscreen => 'View fullscreen';

	late final Translations$fileView$fileChip$en fileChip = Translations$fileView$fileChip$en.internal(_root);
	late final Translations$fileView$contentsTag$en contentsTag = Translations$fileView$contentsTag$en.internal(_root);
	late final Translations$fileView$contentsStatus$en contentsStatus = Translations$fileView$contentsStatus$en.internal(_root);
}

// Path: matome
class Translations$matome$en {
	Translations$matome$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Matome'
	String get title => 'Matome';

	/// en: 'Matome not found'
	String get notFound => 'Matome not found';

	/// en: 'Items'
	String get recordings => 'Items';

	/// en: 'No items yet'
	String get noRecordings => 'No items yet';

	/// en: 'Summary'
	String get summary => 'Summary';

	/// en: 'No summary yet'
	String get noSummary => 'No summary yet';

	/// en: 'Inbox'
	String get placeInbox => 'Inbox';

	/// en: 'Regenerate summary'
	String get regenerateSummary => 'Regenerate summary';

	/// en: 'Items changed — summary may be out of date'
	String get summaryStale => 'Items changed — summary may be out of date';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'No notes yet'
	String get noNotes => 'No notes yet';

	/// en: 'File into a space'
	String get fileIntoSpace => 'File into a space';

	/// en: 'File into a space'
	String get fileIntoSpaceSheetTitle => 'File into a space';

	/// en: 'Filed in $space'
	String filedIn({required Object space}) => 'Filed in ${space}';

	/// en: 'Refile'
	String get refile => 'Refile';

	/// en: 'Default'
	String get personalSpaceHint => 'Default';

	/// en: 'Add photo'
	String get addPhoto => 'Add photo';

	/// en: 'Add file'
	String get addFile => 'Add file';

	/// en: 'Add file failed: $error'
	String addFileFailed({required Object error}) => 'Add file failed: ${error}';

	/// en: '"$name" is too large (max $max MB)'
	String fileTooLarge({required Object name, required Object max}) => '"${name}" is too large (max ${max} MB)';

	/// en: 'Edit notes'
	String get editNotes => 'Edit notes';

	/// en: 'Add notes about this matome…'
	String get notesHint => 'Add notes about this matome…';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Tag contacts'
	String get tagContacts => 'Tag contacts';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'Coming soon'
	String get comingSoon => 'Coming soon';

	/// en: 'Contacts'
	String get contacts => 'Contacts';

	/// en: 'Add contact'
	String get addContact => 'Add contact';

	/// en: 'No contacts attached'
	String get noContacts => 'No contacts attached';

	/// en: 'Add a contact'
	String get addContactSheetTitle => 'Add a contact';

	/// en: 'No contacts in your directory yet'
	String get noDirectoryContacts => 'No contacts in your directory yet';

	/// en: 'Remove contact'
	String get removeContact => 'Remove contact';

	/// en: 'Attendee'
	String get roleAttendee => 'Attendee';

	/// en: 'Organizer'
	String get roleOrganizer => 'Organizer';

	/// en: 'Speaker'
	String get roleSpeaker => 'Speaker';

	/// en: '$n items'
	String itemCount({required Object n}) => '${n} items';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Remove item'
	String get removeItemTitle => 'Remove item';

	/// en: 'Remove "$title" from this matome?'
	String removeItemBody({required Object title}) => 'Remove "${title}" from this matome?';

	/// en: 'Image unavailable'
	String get imageUnavailable => 'Image unavailable';

	/// en: 'Show more'
	String get showMore => 'Show more';

	/// en: 'Show less'
	String get showLess => 'Show less';

	/// en: 'Details'
	String get detailPanelTitle => 'Details';

	/// en: 'Files'
	String get filesLabel => 'Files';

	/// en: 'People'
	String get peopleLabel => 'People';

	/// en: 'Space'
	String get spaceLabel => 'Space';

	/// en: 'Status'
	String get statusLabel => 'Status';

	/// en: '+$n'
	String filesPreviewMore({required Object n}) => '+${n}';

	/// en: 'No items yet'
	String get noFiles => 'No items yet';

	/// en: 'No people yet'
	String get noPeople => 'No people yet';

	late final Translations$matome$actions$en actions = Translations$matome$actions$en.internal(_root);
	late final Translations$matome$table$en table = Translations$matome$table$en.internal(_root);
}

// Path: files
class Translations$files$en {
	Translations$files$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unfiled'
	String get unfiled => 'Unfiled';

	/// en: 'Files'
	String get title => 'Files';

	/// en: 'Name'
	String get colName => 'Name';

	/// en: 'Matome'
	String get colMatome => 'Matome';

	/// en: 'Space'
	String get colSpace => 'Space';

	/// en: 'People'
	String get colPeople => 'People';

	/// en: 'When'
	String get colWhen => 'When';

	/// en: 'Size'
	String get colSize => 'Size';

	/// en: 'Sync'
	String get colSync => 'Sync';

	/// en: '$n selected'
	String selected({required Object n}) => '${n} selected';

	/// en: 'Move to matome'
	String get moveToMatome => 'Move to matome';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Sort'
	String get sortBy => 'Sort';

	/// en: 'Select file'
	String get selectFile => 'Select file';

	/// en: 'File actions'
	String get fileActions => 'File actions';

	/// en: '—'
	String get noSize => '—';

	/// en: 'Grid'
	String get viewGrid => 'Grid';

	/// en: 'Table'
	String get viewTable => 'Table';

	/// en: 'No files'
	String get emptyTitle => 'No files';

	/// en: 'Files you capture or import appear here, in or out of a matome.'
	String get emptyBody => 'Files you capture or import appear here, in or out of a matome.';

	/// en: 'Delete files?'
	String get deleteTitle => 'Delete files?';

	/// en: 'Delete $n file(s)? You can undo this.'
	String deleteBody({required Object n}) => 'Delete ${n} file(s)? You can undo this.';

	/// en: 'Deleted $n'
	String deletedMsg({required Object n}) => 'Deleted ${n}';

	/// en: 'Download isn't available yet'
	String get downloadUnavailable => 'Download isn\'t available yet';
}

// Path: spaces
class Translations$spaces$en {
	Translations$spaces$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Spaces'
	String get title => 'Spaces';

	/// en: 'No spaces yet'
	String get empty => 'No spaces yet';

	/// en: 'Tap + to create a space and organize your recordings'
	String get emptyHint => 'Tap + to create a space and organize your recordings';

	/// en: '$n recordings'
	String count({required Object n}) => '${n} recordings';

	/// en: 'New space'
	String get createTitle => 'New space';

	/// en: 'Space name'
	String get createHint => 'Space name';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete space?'
	String get deleteTitle => 'Delete space?';

	/// en: 'Recordings in this space will move back to the Inbox.'
	String get deleteBody => 'Recordings in this space will move back to the Inbox.';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'No recordings in this space yet'
	String get detailEmpty => 'No recordings in this space yet';

	/// en: 'No matomes in this space yet'
	String get detailEmptyMatomes => 'No matomes in this space yet';

	/// en: '$n matomes'
	String matomeCount({required Object n}) => '${n} matomes';
}

// Path: calendar
class Translations$calendar$en {
	Translations$calendar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Calendar'
	String get title => 'Calendar';

	/// en: 'No recordings for this day'
	String get noRecordings => 'No recordings for this day';

	/// en: 'No matomes for this day'
	String get noMatomes => 'No matomes for this day';

	/// en: '$n matomes'
	String matomeCount({required Object n}) => '${n} matomes';

	/// en: 'All'
	String get allSpaces => 'All';
}

// Path: contacts
class Translations$contacts$en {
	Translations$contacts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Contacts'
	String get title => 'Contacts';

	/// en: '$n contacts'
	String count({required Object n}) => '${n} contacts';

	/// en: 'No contacts yet'
	String get empty => 'No contacts yet';

	/// en: 'Tap + to add people to your directory'
	String get emptyHint => 'Tap + to add people to your directory';

	/// en: 'New contact'
	String get createTitle => 'New contact';

	/// en: 'Edit contact'
	String get editTitle => 'Edit contact';

	/// en: 'Name'
	String get nameLabel => 'Name';

	/// en: 'Display name'
	String get nameHint => 'Display name';

	/// en: 'Notes'
	String get notesLabel => 'Notes';

	/// en: 'Email, phone, or other details'
	String get notesHint => 'Email, phone, or other details';

	/// en: 'Add'
	String get create => 'Add';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete contact?'
	String get deleteTitle => 'Delete contact?';

	/// en: 'This contact will be removed from your directory.'
	String get deleteBody => 'This contact will be removed from your directory.';

	/// en: 'Delete'
	String get delete => 'Delete';

	late final Translations$contacts$detail$en detail = Translations$contacts$detail$en.internal(_root);
}

// Path: satori
class Translations$satori$en {
	Translations$satori$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Satori'
	String get title => 'Satori';

	/// en: '悟 · your AI assistant'
	String get subtitle => '悟 · your AI assistant';

	/// en: 'SOON'
	String get soon => 'SOON';

	/// en: 'UNDER CONSTRUCTION'
	String get underConstruction => 'UNDER CONSTRUCTION';

	/// en: 'Satori is '
	String get headlinePrefix => 'Satori is ';

	/// en: 'almost'
	String get headlineAccent => 'almost';

	/// en: ' awake.'
	String get headlineSuffix => ' awake.';

	/// en: 'Your recordings, searched and understood. Ask questions, draft follow-ups, surface what matters. Ship target: next release.'
	String get body => 'Your recordings, searched and understood. Ask questions, draft follow-ups, surface what matters. Ship target: next release.';

	/// en: 'WHAT'S COMING'
	String get roadmapLabel => 'WHAT\'S COMING';

	/// en: 'Full-text search across recordings'
	String get roadmapSearchTitle => 'Full-text search across recordings';

	/// en: 'v0.8 · shipped'
	String get roadmapSearchDetail => 'v0.8 · shipped';

	/// en: 'Ask questions of your transcripts'
	String get roadmapQuestionsTitle => 'Ask questions of your transcripts';

	/// en: 'in progress'
	String get roadmapQuestionsDetail => 'in progress';

	/// en: 'Draft emails + follow-ups from calls'
	String get roadmapEmailsTitle => 'Draft emails + follow-ups from calls';

	/// en: 'next up'
	String get roadmapEmailsDetail => 'next up';

	/// en: 'Cross-space insights & trends'
	String get roadmapInsightsTitle => 'Cross-space insights & trends';

	/// en: 'later'
	String get roadmapInsightsDetail => 'later';

	/// en: 'Notify me when it's ready'
	String get notify => 'Notify me when it\'s ready';
}

// Path: welcome
class Translations$welcome$en {
	Translations$welcome$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Welcome to Matome'
	String get title => 'Welcome to Matome';

	/// en: 'Sign in'
	String get signIn => 'Sign in';

	/// en: 'Sign up'
	String get signUp => 'Sign up';

	/// en: 'Your voice.'
	String get headlineLine1 => 'Your voice.';

	/// en: 'Your life.'
	String get headlineLine2 => 'Your life.';

	/// en: 'Finally organized.'
	String get headlineAccent => 'Finally organized.';

	/// en: 'Record, transcribe, and organize your thoughts — with Satori, your AI that actually listens.'
	String get subheadline => 'Record, transcribe, and organize your thoughts — with Satori, your AI that actually listens.';

	/// en: 'ワンタップ capture'
	String get featureCaptureTitle => 'ワンタップ capture';

	/// en: 'Tap once. We handle the rest.'
	String get featureCaptureSubtitle => 'Tap once. We handle the rest.';

	/// en: 'AI summaries + notes'
	String get featureSummariesTitle => 'AI summaries + notes';

	/// en: 'Every recording becomes a usable artifact.'
	String get featureSummariesSubtitle => 'Every recording becomes a usable artifact.';

	/// en: 'Spaces that scale'
	String get featureSpacesTitle => 'Spaces that scale';

	/// en: 'Personal or enterprise — bring your own structure.'
	String get featureSpacesSubtitle => 'Personal or enterprise — bring your own structure.';

	/// en: 'Have an account? '
	String get haveAccount => 'Have an account? ';
}

// Path: auth
class Translations$auth$en {
	Translations$auth$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Email'
	String get email => 'Email';

	/// en: 'Enter your email'
	String get emailPlaceholder => 'Enter your email';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Enter your password'
	String get passwordPlaceholder => 'Enter your password';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Enter your name'
	String get namePlaceholder => 'Enter your name';

	/// en: 'Confirm password'
	String get confirmPassword => 'Confirm password';

	/// en: 'Confirm your password'
	String get confirmPasswordPlaceholder => 'Confirm your password';

	/// en: 'Create account'
	String get createAccount => 'Create account';

	/// en: 'Already have an account? Sign in'
	String get alreadyHaveAccount => 'Already have an account? Sign in';

	/// en: 'Invalid email or password.'
	String get errorInvalidCredentials => 'Invalid email or password.';

	/// en: 'Email and password are required.'
	String get errorRequiredFields => 'Email and password are required.';

	/// en: 'Passwords do not match.'
	String get errorPasswordMismatch => 'Passwords do not match.';

	/// en: 'That email is already registered.'
	String get errorEmailTaken => 'That email is already registered.';

	/// en: 'Something went wrong. Please try again.'
	String get errorGeneric => 'Something went wrong. Please try again.';
}

// Path: fileView.fileChip
class Translations$fileView$fileChip$en {
	Translations$fileView$fileChip$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'soon'
	String get soon => 'soon';

	/// en: '—'
	String get unknownSize => '—';
}

// Path: fileView.contentsTag
class Translations$fileView$contentsTag$en {
	Translations$fileView$contentsTag$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Transcript'
	String get transcript => 'Transcript';

	/// en: 'Description'
	String get description => 'Description';

	/// en: 'Document'
	String get document => 'Document';
}

// Path: fileView.contentsStatus
class Translations$fileView$contentsStatus$en {
	Translations$fileView$contentsStatus$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$fileView$contentsStatus$audio$en audio = Translations$fileView$contentsStatus$audio$en.internal(_root);
	late final Translations$fileView$contentsStatus$image$en image = Translations$fileView$contentsStatus$image$en.internal(_root);
	late final Translations$fileView$contentsStatus$doc$en doc = Translations$fileView$contentsStatus$doc$en.internal(_root);
}

// Path: matome.actions
class Translations$matome$actions$en {
	Translations$matome$actions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'More'
	String get menuTooltip => 'More';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Edit date & time'
	String get editDateTime => 'Edit date & time';

	/// en: 'Regenerate summary'
	String get regenerateSummary => 'Regenerate summary';

	/// en: 'Move to space'
	String get moveToSpace => 'Move to space';

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'soon'
	String get soon => 'soon';

	/// en: 'Copy summary'
	String get copySummary => 'Copy summary';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Summary copied'
	String get summaryCopied => 'Summary copied';

	/// en: 'No summary to copy yet'
	String get noSummaryToCopy => 'No summary to copy yet';

	/// en: 'Archive this matome?'
	String get archiveTitle => 'Archive this matome?';

	/// en: 'It will leave your lists. You can restore it from the archive.'
	String get archiveBody => 'It will leave your lists. You can restore it from the archive.';

	/// en: 'Archive'
	String get archiveConfirm => 'Archive';

	/// en: 'Matome archived'
	String get archived => 'Matome archived';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'This matome is archived'
	String get archivedBanner => 'This matome is archived';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'Rename matome'
	String get renameTitle => 'Rename matome';

	/// en: 'Title'
	String get renameLabel => 'Title';

	/// en: 'Matome title'
	String get renameHint => 'Matome title';

	/// en: 'Save'
	String get renameSave => 'Save';

	/// en: 'Title can't be empty'
	String get renameEmptyError => 'Title can\'t be empty';

	/// en: 'Renamed'
	String get renamed => 'Renamed';

	/// en: 'Edit date & time'
	String get editDateTimeTitle => 'Edit date & time';

	/// en: 'Save'
	String get editDateTimeSave => 'Save';

	/// en: 'Date & time updated'
	String get editDateTimeUpdated => 'Date & time updated';

	/// en: 'Couldn't save — please try again'
	String get editFailed => 'Couldn\'t save — please try again';
}

// Path: matome.table
class Translations$matome$table$en {
	Translations$matome$table$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Matome'
	String get colTitle => 'Matome';

	/// en: 'When'
	String get colWhen => 'When';

	/// en: 'Items'
	String get colItems => 'Items';

	/// en: 'People'
	String get colPeople => 'People';

	/// en: 'Space'
	String get colSpace => 'Space';

	/// en: 'Sync'
	String get colSync => 'Sync';

	/// en: '$n selected'
	String selected({required Object n}) => '${n} selected';

	/// en: 'Move to space'
	String get moveToSpace => 'Move to space';

	/// en: 'Archive'
	String get archive => 'Archive';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Sort'
	String get sortBy => 'Sort';

	/// en: 'Inbox'
	String get inboxLabel => 'Inbox';

	/// en: 'No summary yet'
	String get noSummary => 'No summary yet';

	/// en: 'Nothing to show'
	String get emptyTitle => 'Nothing to show';

	/// en: 'Matomes you capture or file will appear here as rows.'
	String get emptyBody => 'Matomes you capture or file will appear here as rows.';

	/// en: 'Delete matomes?'
	String get deleteTitle => 'Delete matomes?';

	/// en: 'Delete $n matome(s)? You can undo this.'
	String deleteBody({required Object n}) => 'Delete ${n} matome(s)? You can undo this.';

	/// en: 'Archived $n'
	String archivedMsg({required Object n}) => 'Archived ${n}';

	/// en: 'Deleted $n'
	String deletedMsg({required Object n}) => 'Deleted ${n}';

	/// en: 'audio'
	String get audioUnit => 'audio';

	/// en: 'images'
	String get imageUnit => 'images';

	/// en: 'documents'
	String get docUnit => 'documents';

	/// en: 'people'
	String get peopleUnit => 'people';

	/// en: 'Select row'
	String get selectRow => 'Select row';

	/// en: 'Row actions'
	String get rowActions => 'Row actions';

	/// en: 'Cards'
	String get viewCards => 'Cards';

	/// en: 'Table'
	String get viewTable => 'Table';
}

// Path: contacts.detail
class Translations$contacts$detail$en {
	Translations$contacts$detail$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Merge'
	String get merge => 'Merge';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'More'
	String get actions => 'More';

	/// en: 'Contact info'
	String get contactInfo => 'Contact info';

	/// en: 'Notes'
	String get notes => 'Notes';

	/// en: 'No notes yet'
	String get notesEmpty => 'No notes yet';

	/// en: 'Matomes'
	String get matomesLabel => 'Matomes';

	/// en: 'Spaces'
	String get spacesLabel => 'Spaces';

	/// en: 'Files'
	String get filesLabel => 'Files';

	/// en: 'Email'
	String get email => 'Email';

	/// en: 'Phone'
	String get phone => 'Phone';

	/// en: 'Company'
	String get company => 'Company';

	/// en: 'Add'
	String get addInfo => 'Add';

	/// en: 'Synced'
	String get synced => 'Synced';

	/// en: 'On device'
	String get onDevice => 'On device';

	/// en: '—'
	String get empty => '—';

	/// en: 'Contact not found'
	String get notFound => 'Contact not found';
}

// Path: fileView.contentsStatus.audio
class Translations$fileView$contentsStatus$audio$en {
	Translations$fileView$contentsStatus$audio$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Transcribing…'
	String get processing => 'Transcribing…';

	/// en: 'Transcription failed'
	String get failed => 'Transcription failed';

	/// en: 'No transcript yet'
	String get empty => 'No transcript yet';
}

// Path: fileView.contentsStatus.image
class Translations$fileView$contentsStatus$image$en {
	Translations$fileView$contentsStatus$image$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Describing…'
	String get processing => 'Describing…';

	/// en: 'Description failed'
	String get failed => 'Description failed';

	/// en: 'No description yet'
	String get empty => 'No description yet';
}

// Path: fileView.contentsStatus.doc
class Translations$fileView$contentsStatus$doc$en {
	Translations$fileView$contentsStatus$doc$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Processing…'
	String get processing => 'Processing…';

	/// en: 'Processing failed'
	String get failed => 'Processing failed';

	/// en: 'No contents yet'
	String get empty => 'No contents yet';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.cancel' => 'Cancel',
			'common.save' => 'Save',
			'common.retry' => 'Retry',
			'common.today' => 'Today',
			'common.yesterday' => 'Yesterday',
			'a11y.openSettings' => 'Settings',
			'a11y.play' => 'Play',
			'a11y.pause' => 'Pause',
			'settings.title' => 'Settings',
			'settings.appearance' => 'Appearance',
			'settings.theme' => 'Theme',
			'settings.language' => 'Language',
			'settings.account' => 'Account',
			'settings.signOut' => 'Sign out',
			'settings.themeLight' => 'Light',
			'settings.themeDark' => 'Dark',
			'settings.themeSystem' => 'System',
			'settings.langEn' => 'English',
			'settings.langJa' => '日本語',
			'settings.views' => 'Default views',
			'settings.viewsMatome' => 'Matome list',
			'settings.viewsFiles' => 'Files',
			'settings.viewCards' => 'Cards',
			'settings.viewTableMatome' => 'Table',
			'settings.viewGrid' => 'Grid',
			'settings.viewTableFiles' => 'Table',
			'nav.createNew' => 'New',
			'nav.add' => 'Add',
			'nav.recordAudio' => 'Record audio',
			'nav.recordMeeting' => 'Record meeting',
			'nav.importFile' => 'Import file',
			'nav.addPhoto' => 'Add photo',
			'nav.addFile' => 'Add file',
			'nav.collapse' => 'Collapse',
			'nav.expand' => 'Expand',
			'inbox.title' => 'Inbox',
			'inbox.searchPlaceholder' => 'Search transcripts, tags, spaces…',
			'inbox.noResults' => 'No recordings found',
			'inbox.recordings' => 'recordings',
			'inbox.matomeCount' => ({required Object n}) => '${n} matomes',
			'inbox.searchHint' => 'Search matomes',
			'inbox.empty' => 'No matomes yet',
			'inbox.emptyHint' => 'Matomes you capture or upload will show up here.',
			'inbox.noMatches' => 'No matching matomes',
			'inbox.noMatchesHint' => 'Try a different search term.',
			'inbox.loadFailed' => 'Couldn\'t load matomes',
			'inbox.selectHint' => 'Select a matome to preview',
			'cardStatus.pendingUpload' => 'Saved on device · waiting to upload',
			'cardStatus.processing' => 'Transcribing…',
			'cardStatus.failed' => 'Upload failed',
			'cardStatus.retry' => 'Retry',
			'cardStatus.onDevice' => 'On device',
			'cardStatus.cloud' => 'Synced',
			'cardStatus.syncing' => 'Syncing',
			'cardStatus.syncState' => 'Sync state',
			'recording.title' => 'Recording',
			'recording.ready' => 'Ready to Record',
			'recording.startHint' => 'Tap the button to start recording',
			'recording.stopHint' => 'Tap to pause',
			'recording.paused' => 'Paused',
			'recording.resumeHint' => 'Tap to resume',
			'recording.processing' => 'Saving…',
			'recording.processingHint' => 'You can leave this open or continue in the Inbox — we\'ll keep saving in the background.',
			'recording.processingBackground' => 'Continue in Inbox',
			'recording.loading' => 'Loading…',
			'recording.transcribing' => 'Transcribing…',
			'recording.transcriptionFailed' => 'Transcription failed',
			'recording.pause' => 'Pause',
			'recording.resume' => 'Resume',
			'recording.finish' => 'Finish',
			'recording.discardConfirmTitle' => 'Discard recording?',
			'recording.discardConfirmBody' => 'This recording hasn\'t been saved. If you leave now, the audio will be lost.',
			'recording.discardConfirmKeep' => 'Keep recording',
			'recording.discardConfirmDiscard' => 'Discard',
			'recording.draftFound' => 'Resume recording?',
			'recording.draftHint' => 'We found an unfinished recording. Resume where you left off, or discard it.',
			'recording.draftResume' => 'Resume',
			'recording.draftDiscard' => 'Discard',
			'recording.startFailed' => 'Couldn\'t start recording.',
			'recording.pauseFailed' => 'Couldn\'t pause recording.',
			'recording.resumeFailed' => 'Couldn\'t resume recording.',
			'recording.saveFailed' => 'Couldn\'t save recording.',
			'recording.unsupportedTitle' => 'Microphone unavailable',
			'recording.unsupportedHint' => 'Audio capture isn\'t available on this device. Try the mobile app to record.',
			'details.summary' => 'Summary',
			'details.notes' => 'Notes',
			'details.transcript' => 'Transcript',
			'details.edit' => 'Edit',
			'details.preview' => 'Preview',
			'details.noSummary' => 'No summary yet.',
			'details.noNotes' => 'No notes yet. Tap Edit to add some.',
			'details.notesPlaceholder' => 'Write notes in markdown…',
			'details.delete' => 'Delete',
			'details.moveToSpace' => 'Move to space',
			'details.moreActions' => 'More actions',
			'details.deleteConfirmTitle' => 'Delete recording',
			'details.deleteConfirmBody' => 'This recording will be permanently removed. Continue?',
			'details.unsavedTitle' => 'Unsaved changes',
			'details.unsavedBody' => 'You have unsaved changes. Do you want to discard them?',
			'details.keepEditing' => 'Keep editing',
			'details.discard' => 'Discard',
			'details.notFound' => 'Recording not found',
			'details.saved' => 'Notes saved',
			'details.saveFailed' => 'Couldn\'t save notes',
			'details.audioFailed' => 'Couldn\'t play audio',
			'details.audioUnavailable' => 'Audio unavailable',
			'fileView.contents' => 'Contents',
			'fileView.notes' => 'Notes',
			'fileView.notesHint' => 'Write your own notes…',
			'fileView.viewFullscreen' => 'View fullscreen',
			'fileView.fileChip.open' => 'Open',
			'fileView.fileChip.soon' => 'soon',
			'fileView.fileChip.unknownSize' => '—',
			'fileView.contentsTag.transcript' => 'Transcript',
			'fileView.contentsTag.description' => 'Description',
			'fileView.contentsTag.document' => 'Document',
			'fileView.contentsStatus.audio.processing' => 'Transcribing…',
			'fileView.contentsStatus.audio.failed' => 'Transcription failed',
			'fileView.contentsStatus.audio.empty' => 'No transcript yet',
			'fileView.contentsStatus.image.processing' => 'Describing…',
			'fileView.contentsStatus.image.failed' => 'Description failed',
			'fileView.contentsStatus.image.empty' => 'No description yet',
			'fileView.contentsStatus.doc.processing' => 'Processing…',
			'fileView.contentsStatus.doc.failed' => 'Processing failed',
			'fileView.contentsStatus.doc.empty' => 'No contents yet',
			'matome.title' => 'Matome',
			'matome.notFound' => 'Matome not found',
			'matome.recordings' => 'Items',
			'matome.noRecordings' => 'No items yet',
			'matome.summary' => 'Summary',
			'matome.noSummary' => 'No summary yet',
			'matome.placeInbox' => 'Inbox',
			'matome.regenerateSummary' => 'Regenerate summary',
			'matome.summaryStale' => 'Items changed — summary may be out of date',
			'matome.notes' => 'Notes',
			'matome.noNotes' => 'No notes yet',
			'matome.fileIntoSpace' => 'File into a space',
			'matome.fileIntoSpaceSheetTitle' => 'File into a space',
			'matome.filedIn' => ({required Object space}) => 'Filed in ${space}',
			'matome.refile' => 'Refile',
			'matome.personalSpaceHint' => 'Default',
			'matome.addPhoto' => 'Add photo',
			'matome.addFile' => 'Add file',
			'matome.addFileFailed' => ({required Object error}) => 'Add file failed: ${error}',
			'matome.fileTooLarge' => ({required Object name, required Object max}) => '"${name}" is too large (max ${max} MB)',
			'matome.editNotes' => 'Edit notes',
			'matome.notesHint' => 'Add notes about this matome…',
			'matome.save' => 'Save',
			'matome.cancel' => 'Cancel',
			'matome.tagContacts' => 'Tag contacts',
			'matome.share' => 'Share',
			'matome.comingSoon' => 'Coming soon',
			'matome.contacts' => 'Contacts',
			'matome.addContact' => 'Add contact',
			'matome.noContacts' => 'No contacts attached',
			'matome.addContactSheetTitle' => 'Add a contact',
			'matome.noDirectoryContacts' => 'No contacts in your directory yet',
			'matome.removeContact' => 'Remove contact',
			'matome.roleAttendee' => 'Attendee',
			'matome.roleOrganizer' => 'Organizer',
			'matome.roleSpeaker' => 'Speaker',
			'matome.itemCount' => ({required Object n}) => '${n} items',
			'matome.remove' => 'Remove',
			'matome.removeItemTitle' => 'Remove item',
			'matome.removeItemBody' => ({required Object title}) => 'Remove "${title}" from this matome?',
			'matome.imageUnavailable' => 'Image unavailable',
			'matome.showMore' => 'Show more',
			'matome.showLess' => 'Show less',
			'matome.detailPanelTitle' => 'Details',
			'matome.filesLabel' => 'Files',
			'matome.peopleLabel' => 'People',
			'matome.spaceLabel' => 'Space',
			'matome.statusLabel' => 'Status',
			'matome.filesPreviewMore' => ({required Object n}) => '+${n}',
			'matome.noFiles' => 'No items yet',
			'matome.noPeople' => 'No people yet',
			'matome.actions.menuTooltip' => 'More',
			'matome.actions.rename' => 'Rename',
			'matome.actions.editDateTime' => 'Edit date & time',
			'matome.actions.regenerateSummary' => 'Regenerate summary',
			'matome.actions.moveToSpace' => 'Move to space',
			'matome.actions.share' => 'Share',
			'matome.actions.soon' => 'soon',
			'matome.actions.copySummary' => 'Copy summary',
			'matome.actions.archive' => 'Archive',
			'matome.actions.summaryCopied' => 'Summary copied',
			'matome.actions.noSummaryToCopy' => 'No summary to copy yet',
			'matome.actions.archiveTitle' => 'Archive this matome?',
			'matome.actions.archiveBody' => 'It will leave your lists. You can restore it from the archive.',
			'matome.actions.archiveConfirm' => 'Archive',
			'matome.actions.archived' => 'Matome archived',
			'matome.actions.undo' => 'Undo',
			'matome.actions.archivedBanner' => 'This matome is archived',
			'matome.actions.restore' => 'Restore',
			'matome.actions.renameTitle' => 'Rename matome',
			'matome.actions.renameLabel' => 'Title',
			'matome.actions.renameHint' => 'Matome title',
			'matome.actions.renameSave' => 'Save',
			'matome.actions.renameEmptyError' => 'Title can\'t be empty',
			'matome.actions.renamed' => 'Renamed',
			'matome.actions.editDateTimeTitle' => 'Edit date & time',
			'matome.actions.editDateTimeSave' => 'Save',
			'matome.actions.editDateTimeUpdated' => 'Date & time updated',
			'matome.actions.editFailed' => 'Couldn\'t save — please try again',
			'matome.table.colTitle' => 'Matome',
			'matome.table.colWhen' => 'When',
			'matome.table.colItems' => 'Items',
			'matome.table.colPeople' => 'People',
			'matome.table.colSpace' => 'Space',
			'matome.table.colSync' => 'Sync',
			'matome.table.selected' => ({required Object n}) => '${n} selected',
			'matome.table.moveToSpace' => 'Move to space',
			'matome.table.archive' => 'Archive',
			'matome.table.delete' => 'Delete',
			'matome.table.clear' => 'Clear',
			'matome.table.cancel' => 'Cancel',
			'matome.table.undo' => 'Undo',
			'matome.table.open' => 'Open',
			'matome.table.sortBy' => 'Sort',
			'matome.table.inboxLabel' => 'Inbox',
			'matome.table.noSummary' => 'No summary yet',
			'matome.table.emptyTitle' => 'Nothing to show',
			'matome.table.emptyBody' => 'Matomes you capture or file will appear here as rows.',
			'matome.table.deleteTitle' => 'Delete matomes?',
			'matome.table.deleteBody' => ({required Object n}) => 'Delete ${n} matome(s)? You can undo this.',
			'matome.table.archivedMsg' => ({required Object n}) => 'Archived ${n}',
			'matome.table.deletedMsg' => ({required Object n}) => 'Deleted ${n}',
			'matome.table.audioUnit' => 'audio',
			'matome.table.imageUnit' => 'images',
			'matome.table.docUnit' => 'documents',
			'matome.table.peopleUnit' => 'people',
			'matome.table.selectRow' => 'Select row',
			'matome.table.rowActions' => 'Row actions',
			'matome.table.viewCards' => 'Cards',
			'matome.table.viewTable' => 'Table',
			'files.unfiled' => 'Unfiled',
			'files.title' => 'Files',
			'files.colName' => 'Name',
			'files.colMatome' => 'Matome',
			'files.colSpace' => 'Space',
			'files.colPeople' => 'People',
			'files.colWhen' => 'When',
			'files.colSize' => 'Size',
			'files.colSync' => 'Sync',
			'files.selected' => ({required Object n}) => '${n} selected',
			'files.moveToMatome' => 'Move to matome',
			'files.download' => 'Download',
			'files.delete' => 'Delete',
			'files.clear' => 'Clear',
			'files.cancel' => 'Cancel',
			'files.undo' => 'Undo',
			'files.open' => 'Open',
			'files.sortBy' => 'Sort',
			'files.selectFile' => 'Select file',
			'files.fileActions' => 'File actions',
			'files.noSize' => '—',
			'files.viewGrid' => 'Grid',
			'files.viewTable' => 'Table',
			'files.emptyTitle' => 'No files',
			'files.emptyBody' => 'Files you capture or import appear here, in or out of a matome.',
			'files.deleteTitle' => 'Delete files?',
			'files.deleteBody' => ({required Object n}) => 'Delete ${n} file(s)? You can undo this.',
			'files.deletedMsg' => ({required Object n}) => 'Deleted ${n}',
			'files.downloadUnavailable' => 'Download isn\'t available yet',
			'spaces.title' => 'Spaces',
			'spaces.empty' => 'No spaces yet',
			'spaces.emptyHint' => 'Tap + to create a space and organize your recordings',
			'spaces.count' => ({required Object n}) => '${n} recordings',
			'spaces.createTitle' => 'New space',
			'spaces.createHint' => 'Space name',
			'spaces.create' => 'Create',
			'spaces.cancel' => 'Cancel',
			'spaces.deleteTitle' => 'Delete space?',
			'spaces.deleteBody' => 'Recordings in this space will move back to the Inbox.',
			'spaces.delete' => 'Delete',
			'spaces.detailEmpty' => 'No recordings in this space yet',
			'spaces.detailEmptyMatomes' => 'No matomes in this space yet',
			'spaces.matomeCount' => ({required Object n}) => '${n} matomes',
			'calendar.title' => 'Calendar',
			'calendar.noRecordings' => 'No recordings for this day',
			'calendar.noMatomes' => 'No matomes for this day',
			'calendar.matomeCount' => ({required Object n}) => '${n} matomes',
			'calendar.allSpaces' => 'All',
			'contacts.title' => 'Contacts',
			'contacts.count' => ({required Object n}) => '${n} contacts',
			'contacts.empty' => 'No contacts yet',
			'contacts.emptyHint' => 'Tap + to add people to your directory',
			'contacts.createTitle' => 'New contact',
			'contacts.editTitle' => 'Edit contact',
			'contacts.nameLabel' => 'Name',
			'contacts.nameHint' => 'Display name',
			'contacts.notesLabel' => 'Notes',
			'contacts.notesHint' => 'Email, phone, or other details',
			'contacts.create' => 'Add',
			'contacts.save' => 'Save',
			'contacts.cancel' => 'Cancel',
			'contacts.deleteTitle' => 'Delete contact?',
			'contacts.deleteBody' => 'This contact will be removed from your directory.',
			'contacts.delete' => 'Delete',
			'contacts.detail.edit' => 'Edit',
			'contacts.detail.merge' => 'Merge',
			'contacts.detail.delete' => 'Delete',
			'contacts.detail.actions' => 'More',
			'contacts.detail.contactInfo' => 'Contact info',
			'contacts.detail.notes' => 'Notes',
			'contacts.detail.notesEmpty' => 'No notes yet',
			'contacts.detail.matomesLabel' => 'Matomes',
			'contacts.detail.spacesLabel' => 'Spaces',
			'contacts.detail.filesLabel' => 'Files',
			'contacts.detail.email' => 'Email',
			'contacts.detail.phone' => 'Phone',
			'contacts.detail.company' => 'Company',
			'contacts.detail.addInfo' => 'Add',
			'contacts.detail.synced' => 'Synced',
			'contacts.detail.onDevice' => 'On device',
			'contacts.detail.empty' => '—',
			'contacts.detail.notFound' => 'Contact not found',
			'satori.title' => 'Satori',
			'satori.subtitle' => '悟 · your AI assistant',
			'satori.soon' => 'SOON',
			'satori.underConstruction' => 'UNDER CONSTRUCTION',
			'satori.headlinePrefix' => 'Satori is ',
			'satori.headlineAccent' => 'almost',
			'satori.headlineSuffix' => ' awake.',
			'satori.body' => 'Your recordings, searched and understood. Ask questions, draft follow-ups, surface what matters. Ship target: next release.',
			'satori.roadmapLabel' => 'WHAT\'S COMING',
			'satori.roadmapSearchTitle' => 'Full-text search across recordings',
			'satori.roadmapSearchDetail' => 'v0.8 · shipped',
			'satori.roadmapQuestionsTitle' => 'Ask questions of your transcripts',
			'satori.roadmapQuestionsDetail' => 'in progress',
			'satori.roadmapEmailsTitle' => 'Draft emails + follow-ups from calls',
			'satori.roadmapEmailsDetail' => 'next up',
			'satori.roadmapInsightsTitle' => 'Cross-space insights & trends',
			'satori.roadmapInsightsDetail' => 'later',
			'satori.notify' => 'Notify me when it\'s ready',
			'welcome.title' => 'Welcome to Matome',
			'welcome.signIn' => 'Sign in',
			'welcome.signUp' => 'Sign up',
			'welcome.headlineLine1' => 'Your voice.',
			'welcome.headlineLine2' => 'Your life.',
			'welcome.headlineAccent' => 'Finally organized.',
			'welcome.subheadline' => 'Record, transcribe, and organize your thoughts — with Satori, your AI that actually listens.',
			'welcome.featureCaptureTitle' => 'ワンタップ capture',
			'welcome.featureCaptureSubtitle' => 'Tap once. We handle the rest.',
			'welcome.featureSummariesTitle' => 'AI summaries + notes',
			'welcome.featureSummariesSubtitle' => 'Every recording becomes a usable artifact.',
			'welcome.featureSpacesTitle' => 'Spaces that scale',
			'welcome.featureSpacesSubtitle' => 'Personal or enterprise — bring your own structure.',
			'welcome.haveAccount' => 'Have an account? ',
			'auth.email' => 'Email',
			'auth.emailPlaceholder' => 'Enter your email',
			'auth.password' => 'Password',
			'auth.passwordPlaceholder' => 'Enter your password',
			'auth.name' => 'Name',
			'auth.namePlaceholder' => 'Enter your name',
			'auth.confirmPassword' => 'Confirm password',
			'auth.confirmPasswordPlaceholder' => 'Confirm your password',
			'auth.createAccount' => 'Create account',
			'auth.alreadyHaveAccount' => 'Already have an account? Sign in',
			'auth.errorInvalidCredentials' => 'Invalid email or password.',
			'auth.errorRequiredFields' => 'Email and password are required.',
			'auth.errorPasswordMismatch' => 'Passwords do not match.',
			'auth.errorEmailTaken' => 'That email is already registered.',
			'auth.errorGeneric' => 'Something went wrong. Please try again.',
			_ => null,
		};
	}
}
