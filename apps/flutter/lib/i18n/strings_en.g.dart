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
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
	late final Translations$inbox$en inbox = Translations$inbox$en.internal(_root);
	late final Translations$recording$en recording = Translations$recording$en.internal(_root);
	late final Translations$details$en details = Translations$details$en.internal(_root);
	late final Translations$spaces$en spaces = Translations$spaces$en.internal(_root);
	late final Translations$calendar$en calendar = Translations$calendar$en.internal(_root);
	late final Translations$satori$en satori = Translations$satori$en.internal(_root);
	late final Translations$welcome$en welcome = Translations$welcome$en.internal(_root);
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

	/// en: 'All'
	String get allSpaces => 'All';
}

// Path: satori
class Translations$satori$en {
	Translations$satori$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Satori'
	String get title => 'Satori';
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
			'recording.title' => 'Recording',
			'recording.ready' => 'Ready to Record',
			'recording.startHint' => 'Tap the button to start recording',
			'details.summary' => 'Summary',
			'details.notes' => 'Notes',
			'spaces.title' => 'Spaces',
			'spaces.empty' => 'No spaces yet',
			'spaces.emptyHint' => 'Tap + to create a space and organize your recordings',
			'calendar.title' => 'Calendar',
			'calendar.noRecordings' => 'No recordings for this day',
			'calendar.allSpaces' => 'All',
			'satori.title' => 'Satori',
			'welcome.title' => 'Welcome to Matome',
			'welcome.signIn' => 'Sign in',
			'welcome.signUp' => 'Sign up',
			_ => null,
		};
	}
}
