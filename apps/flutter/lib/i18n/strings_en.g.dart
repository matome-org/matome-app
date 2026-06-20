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
	late final Translations$inbox$en inbox = Translations$inbox$en.internal(_root);
	late final Translations$cardStatus$en cardStatus = Translations$cardStatus$en.internal(_root);
	late final Translations$recording$en recording = Translations$recording$en.internal(_root);
	late final Translations$details$en details = Translations$details$en.internal(_root);
	late final Translations$matome$en matome = Translations$matome$en.internal(_root);
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

	/// en: 'Cloud'
	String get cloud => 'Cloud';

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

// Path: matome
class Translations$matome$en {
	Translations$matome$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Matome'
	String get title => 'Matome';

	/// en: 'Matome not found'
	String get notFound => 'Matome not found';

	/// en: 'On device · not filed'
	String get onDevice => 'On device · not filed';

	/// en: 'Items'
	String get recordings => 'Items';

	/// en: 'No items yet'
	String get noRecordings => 'No items yet';

	/// en: 'Summary'
	String get summary => 'Summary';

	/// en: 'No summary yet'
	String get noSummary => 'No summary yet';

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

	/// en: 'On device'
	String get onDeviceShort => 'On device';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Remove item'
	String get removeItemTitle => 'Remove item';

	/// en: 'Remove "$title" from this matome?'
	String removeItemBody({required Object title}) => 'Remove "${title}" from this matome?';

	/// en: 'Image unavailable'
	String get imageUnavailable => 'Image unavailable';
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
			'cardStatus.cloud' => 'Cloud',
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
			'matome.title' => 'Matome',
			'matome.notFound' => 'Matome not found',
			'matome.onDevice' => 'On device · not filed',
			'matome.recordings' => 'Items',
			'matome.noRecordings' => 'No items yet',
			'matome.summary' => 'Summary',
			'matome.noSummary' => 'No summary yet',
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
			'matome.onDeviceShort' => 'On device',
			'matome.remove' => 'Remove',
			'matome.removeItemTitle' => 'Remove item',
			'matome.removeItemBody' => ({required Object title}) => 'Remove "${title}" from this matome?',
			'matome.imageUnavailable' => 'Image unavailable',
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
