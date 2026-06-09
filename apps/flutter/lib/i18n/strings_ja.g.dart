///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsJa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsJa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsJa _root = this; // ignore: unused_field

	@override 
	TranslationsJa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsJa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ja common = _Translations$common$ja._(_root);
	@override late final _Translations$settings$ja settings = _Translations$settings$ja._(_root);
	@override late final _Translations$inbox$ja inbox = _Translations$inbox$ja._(_root);
	@override late final _Translations$recording$ja recording = _Translations$recording$ja._(_root);
	@override late final _Translations$details$ja details = _Translations$details$ja._(_root);
	@override late final _Translations$spaces$ja spaces = _Translations$spaces$ja._(_root);
	@override late final _Translations$calendar$ja calendar = _Translations$calendar$ja._(_root);
	@override late final _Translations$satori$ja satori = _Translations$satori$ja._(_root);
	@override late final _Translations$welcome$ja welcome = _Translations$welcome$ja._(_root);
	@override late final _Translations$auth$ja auth = _Translations$auth$ja._(_root);
}

// Path: common
class _Translations$common$ja extends Translations$common$en {
	_Translations$common$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'キャンセル';
	@override String get save => '保存';
	@override String get retry => '再試行';
	@override String get today => '今日';
	@override String get yesterday => '昨日';
}

// Path: settings
class _Translations$settings$ja extends Translations$settings$en {
	_Translations$settings$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get appearance => '外観';
	@override String get theme => 'テーマ';
	@override String get language => '言語';
	@override String get account => 'アカウント';
	@override String get signOut => 'サインアウト';
	@override String get themeLight => 'ライト';
	@override String get themeDark => 'ダーク';
	@override String get themeSystem => 'システム';
	@override String get langEn => 'English';
	@override String get langJa => '日本語';
}

// Path: inbox
class _Translations$inbox$ja extends Translations$inbox$en {
	_Translations$inbox$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '受信箱';
	@override String get searchPlaceholder => 'トランスクリプト、タグ、スペースを検索...';
	@override String get noResults => '録音が見つかりません';
	@override String get recordings => '件の録音';
}

// Path: recording
class _Translations$recording$ja extends Translations$recording$en {
	_Translations$recording$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '録音中';
	@override String get ready => '録音準備完了';
	@override String get startHint => 'ボタンを押して録音を開始してください';
	@override String get stopHint => 'タップして一時停止';
	@override String get paused => '一時停止中';
	@override String get resumeHint => 'タップして再開';
	@override String get processing => '保存中…';
	@override String get loading => '読み込み中…';
	@override String get transcribing => '文字起こし中…';
	@override String get transcriptionFailed => '文字起こしに失敗しました';
	@override String get pause => '一時停止';
	@override String get resume => '再開';
	@override String get finish => '完了';
	@override String get draftFound => '録音を再開しますか？';
	@override String get draftHint => '未完了の録音が見つかりました。続きから再開するか、破棄してください。';
	@override String get draftResume => '再開';
	@override String get draftDiscard => '破棄';
	@override String get startFailed => '録音を開始できませんでした。';
	@override String get pauseFailed => '録音を一時停止できませんでした。';
	@override String get resumeFailed => '録音を再開できませんでした。';
	@override String get saveFailed => '録音を保存できませんでした。';
	@override String get unsupportedTitle => 'マイクを利用できません';
	@override String get unsupportedHint => 'このデバイスでは音声録音を利用できません。録音するにはモバイルアプリをご利用ください。';
}

// Path: details
class _Translations$details$ja extends Translations$details$en {
	_Translations$details$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get summary => '要約';
	@override String get notes => 'メモ';
	@override String get transcript => 'トランスクリプト';
	@override String get edit => '編集';
	@override String get preview => 'プレビュー';
	@override String get noSummary => 'まだ要約はありません。';
	@override String get noNotes => 'まだメモはありません。編集をタップして追加してください。';
	@override String get notesPlaceholder => 'マークダウンでメモを書く…';
	@override String get delete => '削除';
	@override String get moveToSpace => 'スペースへ移動';
	@override String get deleteConfirmTitle => '録音を削除';
	@override String get deleteConfirmBody => 'この録音は完全に削除されます。続行しますか？';
	@override String get unsavedTitle => '未保存の変更';
	@override String get unsavedBody => '未保存の変更があります。破棄しますか？';
	@override String get keepEditing => '編集を続ける';
	@override String get discard => '破棄';
	@override String get notFound => '録音が見つかりません';
	@override String get saved => 'メモを保存しました';
	@override String get saveFailed => 'メモを保存できませんでした';
	@override String get audioFailed => '音声を再生できませんでした';
}

// Path: spaces
class _Translations$spaces$ja extends Translations$spaces$en {
	_Translations$spaces$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スペース';
	@override String get empty => 'スペースがありません';
	@override String get emptyHint => '+ をタップしてスペースを作成し、録音を整理しましょう';
}

// Path: calendar
class _Translations$calendar$ja extends Translations$calendar$en {
	_Translations$calendar$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'カレンダー';
	@override String get noRecordings => 'この日の録音はありません';
	@override String get allSpaces => 'すべて';
}

// Path: satori
class _Translations$satori$ja extends Translations$satori$en {
	_Translations$satori$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '悟り';
}

// Path: welcome
class _Translations$welcome$ja extends Translations$welcome$en {
	_Translations$welcome$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Matomeへようこそ';
	@override String get signIn => 'サインイン';
	@override String get signUp => 'サインアップ';
	@override String get headlineLine1 => 'あなたの声を。';
	@override String get headlineLine2 => 'あなたの生活を。';
	@override String get headlineAccent => 'ついに整理。';
	@override String get subheadline => '録音、文字起こし、そして思考の整理を — 本当に聞いてくれるAI、Satoriとともに。';
	@override String get featureCaptureTitle => 'ワンタップ capture';
	@override String get featureCaptureSubtitle => 'ワンタップ。あとはお任せください。';
	@override String get featureSummariesTitle => 'AI要約 + メモ';
	@override String get featureSummariesSubtitle => 'すべての録音が使える成果物になります。';
	@override String get featureSpacesTitle => '拡張できるスペース';
	@override String get featureSpacesSubtitle => '個人でも企業でも — 自分の構造を持ち込めます。';
	@override String get haveAccount => 'アカウントをお持ちですか？ ';
}

// Path: auth
class _Translations$auth$ja extends Translations$auth$en {
	_Translations$auth$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get email => 'メールアドレス';
	@override String get emailPlaceholder => 'メールアドレスを入力してください';
	@override String get password => 'パスワード';
	@override String get passwordPlaceholder => 'パスワードを入力してください';
	@override String get name => '名前';
	@override String get namePlaceholder => '名前を入力してください';
	@override String get confirmPassword => 'パスワードを確認';
	@override String get confirmPasswordPlaceholder => 'パスワードを再入力してください';
	@override String get createAccount => 'アカウント作成';
	@override String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？サインイン';
	@override String get errorInvalidCredentials => 'メールアドレスまたはパスワードが正しくありません。';
	@override String get errorRequiredFields => 'メールアドレスとパスワードを入力してください。';
	@override String get errorPasswordMismatch => 'パスワードが一致しません。';
	@override String get errorEmailTaken => 'そのメールアドレスは既に登録されています。';
	@override String get errorGeneric => '問題が発生しました。もう一度お試しください。';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsJa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.cancel' => 'キャンセル',
			'common.save' => '保存',
			'common.retry' => '再試行',
			'common.today' => '今日',
			'common.yesterday' => '昨日',
			'settings.title' => '設定',
			'settings.appearance' => '外観',
			'settings.theme' => 'テーマ',
			'settings.language' => '言語',
			'settings.account' => 'アカウント',
			'settings.signOut' => 'サインアウト',
			'settings.themeLight' => 'ライト',
			'settings.themeDark' => 'ダーク',
			'settings.themeSystem' => 'システム',
			'settings.langEn' => 'English',
			'settings.langJa' => '日本語',
			'inbox.title' => '受信箱',
			'inbox.searchPlaceholder' => 'トランスクリプト、タグ、スペースを検索...',
			'inbox.noResults' => '録音が見つかりません',
			'inbox.recordings' => '件の録音',
			'recording.title' => '録音中',
			'recording.ready' => '録音準備完了',
			'recording.startHint' => 'ボタンを押して録音を開始してください',
			'recording.stopHint' => 'タップして一時停止',
			'recording.paused' => '一時停止中',
			'recording.resumeHint' => 'タップして再開',
			'recording.processing' => '保存中…',
			'recording.loading' => '読み込み中…',
			'recording.transcribing' => '文字起こし中…',
			'recording.transcriptionFailed' => '文字起こしに失敗しました',
			'recording.pause' => '一時停止',
			'recording.resume' => '再開',
			'recording.finish' => '完了',
			'recording.draftFound' => '録音を再開しますか？',
			'recording.draftHint' => '未完了の録音が見つかりました。続きから再開するか、破棄してください。',
			'recording.draftResume' => '再開',
			'recording.draftDiscard' => '破棄',
			'recording.startFailed' => '録音を開始できませんでした。',
			'recording.pauseFailed' => '録音を一時停止できませんでした。',
			'recording.resumeFailed' => '録音を再開できませんでした。',
			'recording.saveFailed' => '録音を保存できませんでした。',
			'recording.unsupportedTitle' => 'マイクを利用できません',
			'recording.unsupportedHint' => 'このデバイスでは音声録音を利用できません。録音するにはモバイルアプリをご利用ください。',
			'details.summary' => '要約',
			'details.notes' => 'メモ',
			'details.transcript' => 'トランスクリプト',
			'details.edit' => '編集',
			'details.preview' => 'プレビュー',
			'details.noSummary' => 'まだ要約はありません。',
			'details.noNotes' => 'まだメモはありません。編集をタップして追加してください。',
			'details.notesPlaceholder' => 'マークダウンでメモを書く…',
			'details.delete' => '削除',
			'details.moveToSpace' => 'スペースへ移動',
			'details.deleteConfirmTitle' => '録音を削除',
			'details.deleteConfirmBody' => 'この録音は完全に削除されます。続行しますか？',
			'details.unsavedTitle' => '未保存の変更',
			'details.unsavedBody' => '未保存の変更があります。破棄しますか？',
			'details.keepEditing' => '編集を続ける',
			'details.discard' => '破棄',
			'details.notFound' => '録音が見つかりません',
			'details.saved' => 'メモを保存しました',
			'details.saveFailed' => 'メモを保存できませんでした',
			'details.audioFailed' => '音声を再生できませんでした',
			'spaces.title' => 'スペース',
			'spaces.empty' => 'スペースがありません',
			'spaces.emptyHint' => '+ をタップしてスペースを作成し、録音を整理しましょう',
			'calendar.title' => 'カレンダー',
			'calendar.noRecordings' => 'この日の録音はありません',
			'calendar.allSpaces' => 'すべて',
			'satori.title' => '悟り',
			'welcome.title' => 'Matomeへようこそ',
			'welcome.signIn' => 'サインイン',
			'welcome.signUp' => 'サインアップ',
			'welcome.headlineLine1' => 'あなたの声を。',
			'welcome.headlineLine2' => 'あなたの生活を。',
			'welcome.headlineAccent' => 'ついに整理。',
			'welcome.subheadline' => '録音、文字起こし、そして思考の整理を — 本当に聞いてくれるAI、Satoriとともに。',
			'welcome.featureCaptureTitle' => 'ワンタップ capture',
			'welcome.featureCaptureSubtitle' => 'ワンタップ。あとはお任せください。',
			'welcome.featureSummariesTitle' => 'AI要約 + メモ',
			'welcome.featureSummariesSubtitle' => 'すべての録音が使える成果物になります。',
			'welcome.featureSpacesTitle' => '拡張できるスペース',
			'welcome.featureSpacesSubtitle' => '個人でも企業でも — 自分の構造を持ち込めます。',
			'welcome.haveAccount' => 'アカウントをお持ちですか？ ',
			'auth.email' => 'メールアドレス',
			'auth.emailPlaceholder' => 'メールアドレスを入力してください',
			'auth.password' => 'パスワード',
			'auth.passwordPlaceholder' => 'パスワードを入力してください',
			'auth.name' => '名前',
			'auth.namePlaceholder' => '名前を入力してください',
			'auth.confirmPassword' => 'パスワードを確認',
			'auth.confirmPasswordPlaceholder' => 'パスワードを再入力してください',
			'auth.createAccount' => 'アカウント作成',
			'auth.alreadyHaveAccount' => 'すでにアカウントをお持ちですか？サインイン',
			'auth.errorInvalidCredentials' => 'メールアドレスまたはパスワードが正しくありません。',
			'auth.errorRequiredFields' => 'メールアドレスとパスワードを入力してください。',
			'auth.errorPasswordMismatch' => 'パスワードが一致しません。',
			'auth.errorEmailTaken' => 'そのメールアドレスは既に登録されています。',
			'auth.errorGeneric' => '問題が発生しました。もう一度お試しください。',
			_ => null,
		};
	}
}
