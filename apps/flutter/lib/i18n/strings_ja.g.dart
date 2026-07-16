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
	@override late final _Translations$a11y$ja a11y = _Translations$a11y$ja._(_root);
	@override late final _Translations$settings$ja settings = _Translations$settings$ja._(_root);
	@override late final _Translations$nav$ja nav = _Translations$nav$ja._(_root);
	@override late final _Translations$inbox$ja inbox = _Translations$inbox$ja._(_root);
	@override late final _Translations$cardStatus$ja cardStatus = _Translations$cardStatus$ja._(_root);
	@override late final _Translations$recording$ja recording = _Translations$recording$ja._(_root);
	@override late final _Translations$details$ja details = _Translations$details$ja._(_root);
	@override late final _Translations$fileView$ja fileView = _Translations$fileView$ja._(_root);
	@override late final _Translations$matome$ja matome = _Translations$matome$ja._(_root);
	@override late final _Translations$files$ja files = _Translations$files$ja._(_root);
	@override late final _Translations$spaces$ja spaces = _Translations$spaces$ja._(_root);
	@override late final _Translations$calendar$ja calendar = _Translations$calendar$ja._(_root);
	@override late final _Translations$contacts$ja contacts = _Translations$contacts$ja._(_root);
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

// Path: a11y
class _Translations$a11y$ja extends Translations$a11y$en {
	_Translations$a11y$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get openSettings => '設定';
	@override String get play => '再生';
	@override String get pause => '一時停止';
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
	@override String get views => 'デフォルト表示';
	@override String get viewsMatome => 'マトメ一覧';
	@override String get viewsFiles => 'ファイル';
	@override String get viewCards => 'カード';
	@override String get viewTableMatome => 'テーブル';
	@override String get viewGrid => 'グリッド';
	@override String get viewTableFiles => 'テーブル';
	@override String get layout => 'レイアウト';
	@override String get readingPane => '読み取りペイン';
	@override String get readingPaneAlways => '常に表示';
	@override String get readingPaneOnClick => 'クリック時';
	@override String get readingPaneOff => 'オフ';
	@override String get readingPaneInbox => '受信トレイ';
	@override String get readingPaneFiles => 'ファイル';
	@override String get readingPaneSpaces => 'スペース';
	@override String get readingPaneContacts => '連絡先';
}

// Path: nav
class _Translations$nav$ja extends Translations$nav$en {
	_Translations$nav$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get createNew => '新規';
	@override String get add => '追加';
	@override String get recordAudio => '音声を録音';
	@override String get recordMeeting => '会議を録音';
	@override String get importFile => 'ファイルを取り込む';
	@override String get addPhoto => '写真を追加';
	@override String get addVideo => '動画を追加';
	@override String get addFile => 'ファイルを追加';
	@override String get collapse => '折りたたむ';
	@override String get expand => '広げる';
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
	@override String matomeCount({required Object n}) => '${n} 件のマトメ';
	@override String get searchHint => 'マトメを検索';
	@override String get empty => 'マトメがありません';
	@override String get emptyHint => '録音やアップロードしたマトメがここに表示されます。';
	@override String get noMatches => '一致するマトメがありません';
	@override String get noMatchesHint => '別の検索語をお試しください。';
	@override String get loadFailed => 'マトメを読み込めませんでした';
	@override String get selectHint => 'プレビューするマトメを選択';
	@override String get looseTag => '未整理';
	@override String get draftTag => '下書き';
	@override String get fileAction => '整理';
	@override String get organizeAction => '整理';
	@override String looseMeta({required Object type, required Object time}) => '${type} · ${time}';
	@override String draftMeta({required Object n}) => '${n} 件';
	@override String get fileIntoSpaceTitle => 'スペースに整理';
	@override String get fileSearchHint => 'スペースを検索';
	@override String get fileEmpty => 'スペースがありません';
	@override String get groupIntoMatomeTitle => 'マトメにまとめる';
	@override String get groupSearchHint => 'マトメを検索';
	@override String get groupEmpty => 'マトメがありません';
}

// Path: cardStatus
class _Translations$cardStatus$ja extends Translations$cardStatus$en {
	_Translations$cardStatus$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get pendingUpload => '端末に保存済み · アップロード待ち';
	@override String get processing => '文字起こし中…';
	@override String get failed => 'アップロードに失敗しました';
	@override String get processingFailed => '処理に失敗しました';
	@override String get processingTimedOut => '処理がタイムアウトしました';
	@override String get retry => '再試行';
	@override String get onDevice => '端末内';
	@override String get cloud => '同期済み';
	@override String get syncing => '同期中';
	@override String get syncState => '同期状態';
	@override String get local => 'ローカル';
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
	@override String get processingHint => 'このまま開いたままでも、受信トレイに戻っても構いません。バックグラウンドで保存を続けます。';
	@override String get processingBackground => '受信トレイで続ける';
	@override String get loading => '読み込み中…';
	@override String get transcribing => '文字起こし中…';
	@override String get transcriptionFailed => '文字起こしに失敗しました';
	@override String get pause => '一時停止';
	@override String get resume => '再開';
	@override String get finish => '完了';
	@override String get discardConfirmTitle => '録音を破棄しますか？';
	@override String get discardConfirmBody => 'この録音はまだ保存されていません。今ここを離れると音声は失われます。';
	@override String get discardConfirmKeep => '録音を続ける';
	@override String get discardConfirmDiscard => '破棄';
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
	@override String get moreActions => 'その他の操作';
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
	@override String get audioUnavailable => '音声を利用できません';
}

// Path: fileView
class _Translations$fileView$ja extends Translations$fileView$en {
	_Translations$fileView$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get contents => 'コンテンツ';
	@override String get notes => 'メモ';
	@override String get notesHint => '自分用のメモを書く…';
	@override String get viewFullscreen => '全画面で表示';
	@override late final _Translations$fileView$fileChip$ja fileChip = _Translations$fileView$fileChip$ja._(_root);
	@override late final _Translations$fileView$contentsTag$ja contentsTag = _Translations$fileView$contentsTag$ja._(_root);
	@override late final _Translations$fileView$processingState$ja processingState = _Translations$fileView$processingState$ja._(_root);
	@override late final _Translations$fileView$contentsStatus$ja contentsStatus = _Translations$fileView$contentsStatus$ja._(_root);
}

// Path: matome
class _Translations$matome$ja extends Translations$matome$en {
	_Translations$matome$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'まとめ';
	@override String get notFound => 'まとめが見つかりません';
	@override String get recordings => 'アイテム';
	@override String get noRecordings => 'アイテムはまだありません';
	@override String get summary => '要約';
	@override String get noSummary => '要約はまだありません';
	@override String get placeInbox => '受信箱';
	@override String get regenerateSummary => '要約を再生成';
	@override String get summaryStale => 'アイテムが変更されました — 要約が古い可能性があります';
	@override String get notes => 'メモ';
	@override String get noNotes => 'メモはまだありません';
	@override String get fileIntoSpace => 'スペースに整理';
	@override String get fileIntoSpaceSheetTitle => 'スペースに整理';
	@override String filedIn({required Object space}) => '${space} に整理済み';
	@override String get refile => '再整理';
	@override String get personalSpaceHint => 'デフォルト';
	@override String get addItem => '項目を追加';
	@override String get addPhoto => '写真を追加';
	@override String get addVideo => '動画を追加';
	@override String get addFile => 'ファイルを追加';
	@override String addFileFailed({required Object error}) => 'ファイルの追加に失敗しました: ${error}';
	@override String fileTooLarge({required Object name, required Object max}) => '「${name}」は大きすぎます（最大 ${max} MB）';
	@override String get edit => '編集';
	@override String get editNotes => 'メモを編集';
	@override String get notesHint => 'このまとめについてのメモ…';
	@override String get save => '保存';
	@override String get cancel => 'キャンセル';
	@override String get tagContacts => '連絡先をタグ付け';
	@override String get share => '共有';
	@override String get comingSoon => '近日公開';
	@override String get contacts => '連絡先';
	@override String get addContact => '人を追加';
	@override String get noContacts => '連絡先は追加されていません';
	@override String get addContactSheetTitle => '連絡先を追加';
	@override String get noDirectoryContacts => 'ディレクトリに連絡先がありません';
	@override String get removeContact => '連絡先を削除';
	@override String get roleAttendee => '参加者';
	@override String get roleOrganizer => '主催者';
	@override String get roleSpeaker => '発表者';
	@override String itemCount({required Object n}) => '${n} 件のアイテム';
	@override String get remove => '削除';
	@override String get removeItemTitle => 'アイテムを削除';
	@override String removeItemBody({required Object title}) => '「${title}」をこのまとめから削除しますか？';
	@override String get imageUnavailable => '画像を表示できません';
	@override String get showMore => 'もっと見る';
	@override String get showLess => '閉じる';
	@override String get detailPanelTitle => '詳細';
	@override String get filesLabel => '添付';
	@override String get peopleLabel => '関係者';
	@override String get spaceLabel => '保存先';
	@override String get statusLabel => '状態';
	@override String filesPreviewMore({required Object n}) => '他${n}件';
	@override String get noFiles => '項目はまだありません';
	@override String get noPeople => '関係者はまだいません';
	@override late final _Translations$matome$relationPicker$ja relationPicker = _Translations$matome$relationPicker$ja._(_root);
	@override late final _Translations$matome$actions$ja actions = _Translations$matome$actions$ja._(_root);
	@override late final _Translations$matome$table$ja table = _Translations$matome$table$ja._(_root);
}

// Path: files
class _Translations$files$ja extends Translations$files$en {
	_Translations$files$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get unfiled => '未整理';
	@override String get title => 'ファイル';
	@override String get colName => '名前';
	@override String get colMatome => 'まとめ';
	@override String get colSpace => '保存先';
	@override String get colPeople => '関係者';
	@override String get colWhen => '日時';
	@override String get colSize => 'サイズ';
	@override String get colSync => '同期';
	@override String selected({required Object n}) => '${n} 件選択中';
	@override String get moveToMatome => 'まとめへ移動';
	@override String get download => 'ダウンロード';
	@override String get delete => '削除';
	@override String get clear => '解除';
	@override String get cancel => 'キャンセル';
	@override String get undo => '元に戻す';
	@override String get open => '開く';
	@override String get sortBy => '並び替え';
	@override String get selectFile => 'ファイルを選択';
	@override String get fileActions => 'ファイルの操作';
	@override String get noSize => '—';
	@override String get viewGrid => 'グリッド';
	@override String get viewTable => 'テーブル';
	@override String get emptyTitle => 'ファイルがありません';
	@override String get emptyBody => '取り込んだファイルは、まとめの有無に関わらずここに表示されます。';
	@override String get deleteTitle => 'ファイルを削除しますか？';
	@override String deleteBody({required Object n}) => '${n} 件のファイルを削除します。元に戻せます。';
	@override String deletedMsg({required Object n}) => '${n} 件を削除しました';
	@override String get downloadUnavailable => 'ダウンロードはまだ利用できません';
	@override String get moveSheetTitle => 'まとめに移動';
	@override String get moveUnfiled => '未整理';
	@override String get moveUnfiledHint => 'まとめなし';
	@override String movedMsg({required Object n}) => '${n} 件を移動しました';
	@override String get moveNoTargets => '移動先のまとめがまだありません';
	@override String get scopeAll => 'すべて';
	@override String get scopeLoose => '未整理';
	@override String get scopeInSpace => 'スペース内';
	@override String get fileIntoSpace => 'スペースに整理';
	@override String get fileIntoSpaceInbox => '受信トレイ';
	@override String get fileIntoSpaceInboxHint => 'スペースなし';
	@override String get fileNoSpaces => '整理先のスペースがまだありません';
	@override String filedMsg({required Object n}) => '${n} 件を整理しました';
	@override String get selectHint => 'ファイルを選択するとここに表示されます';
}

// Path: spaces
class _Translations$spaces$ja extends Translations$spaces$en {
	_Translations$spaces$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スペース';
	@override String get empty => 'スペースがありません';
	@override String get emptyHint => '+ をタップしてスペースを作成し、録音を整理しましょう';
	@override String count({required Object n}) => '${n} 件の録音';
	@override String get createTitle => '新しいスペース';
	@override String get createHint => 'スペース名';
	@override String get create => '作成';
	@override String get cancel => 'キャンセル';
	@override String get deleteTitle => 'スペースを削除しますか？';
	@override String get deleteBody => 'このスペースの録音は受信トレイに戻ります。';
	@override String get delete => '削除';
	@override String get detailEmpty => 'このスペースにはまだ録音がありません';
	@override String get detailEmptyMatomes => 'このスペースにはまだマトメがありません';
	@override String matomeCount({required Object n}) => '${n} 件のマトメ';
	@override String get selectHint => 'スペースを選択するとマトメが表示されます';
	@override String get turnOnSync => '同期をオンにする';
	@override String get local => 'ローカル';
	@override String get cloud => 'クラウド';
}

// Path: calendar
class _Translations$calendar$ja extends Translations$calendar$en {
	_Translations$calendar$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'カレンダー';
	@override String get noRecordings => 'この日の録音はありません';
	@override String get noMatomes => 'この日のマトメはありません';
	@override String matomeCount({required Object n}) => '${n} 件のマトメ';
	@override String get allSpaces => 'すべて';
}

// Path: contacts
class _Translations$contacts$ja extends Translations$contacts$en {
	_Translations$contacts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '連絡先';
	@override String count({required Object n}) => '${n} 件の連絡先';
	@override String get empty => '連絡先がありません';
	@override String get emptyHint => '+ をタップして連絡先を追加しましょう';
	@override String get selectHint => '連絡先を選択するとプレビューが表示されます';
	@override String get createTitle => '新しい連絡先';
	@override String get editTitle => '連絡先を編集';
	@override String get nameLabel => '名前';
	@override String get nameHint => '表示名';
	@override String get notesLabel => 'メモ';
	@override String get notesHint => 'メール、電話番号、その他の詳細';
	@override String get create => '追加';
	@override String get save => '保存';
	@override String get cancel => 'キャンセル';
	@override String get deleteTitle => '連絡先を削除しますか？';
	@override String get deleteBody => 'この連絡先はディレクトリから削除されます。';
	@override String get delete => '削除';
	@override late final _Translations$contacts$detail$ja detail = _Translations$contacts$detail$ja._(_root);
}

// Path: satori
class _Translations$satori$ja extends Translations$satori$en {
	_Translations$satori$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '悟り';
	@override String get subtitle => '悟 · あなたのAIアシスタント';
	@override String get soon => '近日公開';
	@override String get underConstruction => '開発中';
	@override String get headlinePrefix => 'Satori はもうすぐ';
	@override String get headlineAccent => '目覚め';
	@override String get headlineSuffix => 'ます。';
	@override String get body => 'あなたの録音を検索し、理解します。質問したり、フォローアップを下書きしたり、重要なことを浮かび上がらせたり。リリース目標：次回リリース。';
	@override String get roadmapLabel => '今後の予定';
	@override String get roadmapSearchTitle => '録音全体の全文検索';
	@override String get roadmapSearchDetail => 'v0.8 · 提供開始';
	@override String get roadmapQuestionsTitle => 'トランスクリプトに質問する';
	@override String get roadmapQuestionsDetail => '進行中';
	@override String get roadmapEmailsTitle => '通話からメール・フォローアップを下書き';
	@override String get roadmapEmailsDetail => '次の予定';
	@override String get roadmapInsightsTitle => 'スペース横断のインサイトと傾向';
	@override String get roadmapInsightsDetail => '後ほど';
	@override String get notify => '準備ができたら通知する';
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
	@override String get forgotPassword => 'パスワードをお忘れですか？';
	@override String get forgotPasswordTitle => 'パスワードをリセット';
	@override String get forgotPasswordSubtitle => 'メールアドレスを入力すると、リセット用のリンクをお送りします。';
	@override String get forgotPasswordSubmit => 'リセットリンクを送信';
	@override String get forgotPasswordSent => 'そのメールアドレスのアカウントが存在する場合、リセットリンクを送信しました。受信トレイをご確認ください。';
	@override String get backToSignIn => 'サインインに戻る';
	@override String get resetPasswordTitle => '新しいパスワードを設定';
	@override String get resetPasswordSubtitle => 'メールに記載されたコードを貼り付け、新しいパスワードを設定してください。';
	@override String get resetToken => 'リセットコード';
	@override String get resetTokenPlaceholder => 'メールのコードを貼り付けてください';
	@override String get newPassword => '新しいパスワード';
	@override String get resetPasswordSubmit => 'パスワードを更新';
	@override String get resetPasswordSuccess => 'パスワードを更新しました。サインインできます。';
	@override String get errorInvalidCredentials => 'メールアドレスまたはパスワードが正しくありません。';
	@override String get errorRequiredFields => 'メールアドレスとパスワードを入力してください。';
	@override String get errorPasswordMismatch => 'パスワードが一致しません。';
	@override String get errorEmailTaken => 'そのメールアドレスは既に登録されています。';
	@override String get errorResetTokenInvalid => 'そのリセットコードは無効か、有効期限が切れています。';
	@override String get errorGeneric => '問題が発生しました。もう一度お試しください。';
}

// Path: fileView.fileChip
class _Translations$fileView$fileChip$ja extends Translations$fileView$fileChip$en {
	_Translations$fileView$fileChip$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get open => '開く';
	@override String get soon => '近日対応';
	@override String get unknownSize => '—';
}

// Path: fileView.contentsTag
class _Translations$fileView$contentsTag$ja extends Translations$fileView$contentsTag$en {
	_Translations$fileView$contentsTag$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get transcript => 'トランスクリプト';
	@override String get description => '説明';
	@override String get document => 'ドキュメント';
}

// Path: fileView.processingState
class _Translations$fileView$processingState$ja extends Translations$fileView$processingState$en {
	_Translations$fileView$processingState$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get queued => '待機中';
	@override String get processing => '処理中';
	@override String get succeeded => '完了';
	@override String get partial => '一部完了';
	@override String get failed => '失敗';
	@override String get notAvailable => '利用できません';
}

// Path: fileView.contentsStatus
class _Translations$fileView$contentsStatus$ja extends Translations$fileView$contentsStatus$en {
	_Translations$fileView$contentsStatus$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$fileView$contentsStatus$audio$ja audio = _Translations$fileView$contentsStatus$audio$ja._(_root);
	@override late final _Translations$fileView$contentsStatus$image$ja image = _Translations$fileView$contentsStatus$image$ja._(_root);
	@override late final _Translations$fileView$contentsStatus$doc$ja doc = _Translations$fileView$contentsStatus$doc$ja._(_root);
}

// Path: matome.relationPicker
class _Translations$matome$relationPicker$ja extends Translations$matome$relationPicker$en {
	_Translations$matome$relationPicker$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get addToThisMatome => 'このまとめに追加';
	@override String get search => '連絡先・ファイル・スペースを検索';
	@override String get typeContacts => '連絡先';
	@override String get typeFiles => 'ファイル';
	@override String get typeSpaces => 'スペース';
	@override String get labelContact => '連絡先';
	@override String get labelFile => 'ファイル';
	@override String get labelSpace => 'スペース';
	@override String get recordAudio => '録音';
	@override String get createContact => '連絡先を作成';
	@override String get newSpace => '新しいスペース';
	@override String get createContactTitle => '新しい連絡先';
	@override String get createContactHint => '連絡先の名前';
	@override String get newSpaceTitle => '新しいスペース';
	@override String get newSpaceHint => 'スペース名';
	@override String get empty => '一致なし。上の作成アクションを使ってください。';
	@override String get add => '追加';
}

// Path: matome.actions
class _Translations$matome$actions$ja extends Translations$matome$actions$en {
	_Translations$matome$actions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get menuTooltip => 'その他';
	@override String get rename => '名前を変更';
	@override String get editDateTime => '日時を編集';
	@override String get regenerateSummary => '要約を再生成';
	@override String get moveToSpace => 'スペースへ移動';
	@override String get share => '共有';
	@override String get soon => '近日';
	@override String get copySummary => '要約をコピー';
	@override String get archive => 'アーカイブ';
	@override String get summaryCopied => '要約をコピーしました';
	@override String get noSummaryToCopy => 'コピーできる要約がまだありません';
	@override String get archiveTitle => 'このまとめをアーカイブしますか？';
	@override String get archiveBody => 'リストから外れます。アーカイブから復元できます。';
	@override String get archiveConfirm => 'アーカイブ';
	@override String get archived => 'まとめをアーカイブしました';
	@override String get undo => '元に戻す';
	@override String get archivedBanner => 'このまとめはアーカイブされています';
	@override String get restore => '復元';
	@override String get renameTitle => 'まとめの名前を変更';
	@override String get renameLabel => 'タイトル';
	@override String get renameHint => 'まとめのタイトル';
	@override String get renameSave => '保存';
	@override String get renameEmptyError => 'タイトルを入力してください';
	@override String get renamed => '名前を変更しました';
	@override String get editDateTimeTitle => '日時を編集';
	@override String get editDateTimeSave => '保存';
	@override String get editDateTimeUpdated => '日時を更新しました';
	@override String get editFailed => '保存できませんでした — もう一度お試しください';
}

// Path: matome.table
class _Translations$matome$table$ja extends Translations$matome$table$en {
	_Translations$matome$table$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get colTitle => 'まとめ';
	@override String get colWhen => '日時';
	@override String get colItems => '項目';
	@override String get colPeople => '関係者';
	@override String get colSpace => '保存先';
	@override String get colSync => '同期';
	@override String selected({required Object n}) => '${n} 件選択中';
	@override String get moveToSpace => '空間へ移動';
	@override String get archive => 'アーカイブ';
	@override String get delete => '削除';
	@override String get clear => '解除';
	@override String get cancel => 'キャンセル';
	@override String get undo => '元に戻す';
	@override String get open => '開く';
	@override String get sortBy => '並び替え';
	@override String get inboxLabel => '受信箱';
	@override String get noSummary => '要約はまだありません';
	@override String get emptyTitle => '表示する項目がありません';
	@override String get emptyBody => '取り込んだまとめや整理したまとめがここに行として表示されます。';
	@override String get deleteTitle => 'まとめを削除しますか？';
	@override String deleteBody({required Object n}) => '${n} 件のまとめを削除します。元に戻せます。';
	@override String archivedMsg({required Object n}) => '${n} 件をアーカイブしました';
	@override String deletedMsg({required Object n}) => '${n} 件を削除しました';
	@override String get audioUnit => '音声';
	@override String get imageUnit => '画像';
	@override String get docUnit => '書類';
	@override String get peopleUnit => '人';
	@override String get selectRow => '行を選択';
	@override String get rowActions => '行の操作';
	@override String get viewCards => 'カード';
	@override String get viewTable => 'テーブル';
}

// Path: contacts.detail
class _Translations$contacts$detail$ja extends Translations$contacts$detail$en {
	_Translations$contacts$detail$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get edit => '編集';
	@override String get merge => '統合';
	@override String get delete => '削除';
	@override String get actions => 'その他';
	@override String get contactInfo => '連絡先情報';
	@override String get notes => 'メモ';
	@override String get notesEmpty => 'メモはまだありません';
	@override String get matomesLabel => 'まとめ';
	@override String get spacesLabel => 'スペース';
	@override String get filesLabel => 'ファイル';
	@override String get email => 'メール';
	@override String get phone => '電話';
	@override String get company => '会社';
	@override String get addInfo => '追加';
	@override String get synced => '同期済み';
	@override String get onDevice => '端末のみ';
	@override String get empty => '—';
	@override String get notFound => '連絡先が見つかりません';
}

// Path: fileView.contentsStatus.audio
class _Translations$fileView$contentsStatus$audio$ja extends Translations$fileView$contentsStatus$audio$en {
	_Translations$fileView$contentsStatus$audio$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get processing => '文字起こし中…';
	@override String get failed => '文字起こしに失敗しました';
	@override String get empty => 'トランスクリプトはまだありません';
}

// Path: fileView.contentsStatus.image
class _Translations$fileView$contentsStatus$image$ja extends Translations$fileView$contentsStatus$image$en {
	_Translations$fileView$contentsStatus$image$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get processing => '説明を生成中…';
	@override String get failed => '説明の生成に失敗しました';
	@override String get empty => '説明はまだありません';
}

// Path: fileView.contentsStatus.doc
class _Translations$fileView$contentsStatus$doc$ja extends Translations$fileView$contentsStatus$doc$en {
	_Translations$fileView$contentsStatus$doc$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get processing => '処理中…';
	@override String get failed => '処理に失敗しました';
	@override String get empty => 'コンテンツはまだありません';
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
			'a11y.openSettings' => '設定',
			'a11y.play' => '再生',
			'a11y.pause' => '一時停止',
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
			'settings.views' => 'デフォルト表示',
			'settings.viewsMatome' => 'マトメ一覧',
			'settings.viewsFiles' => 'ファイル',
			'settings.viewCards' => 'カード',
			'settings.viewTableMatome' => 'テーブル',
			'settings.viewGrid' => 'グリッド',
			'settings.viewTableFiles' => 'テーブル',
			'settings.layout' => 'レイアウト',
			'settings.readingPane' => '読み取りペイン',
			'settings.readingPaneAlways' => '常に表示',
			'settings.readingPaneOnClick' => 'クリック時',
			'settings.readingPaneOff' => 'オフ',
			'settings.readingPaneInbox' => '受信トレイ',
			'settings.readingPaneFiles' => 'ファイル',
			'settings.readingPaneSpaces' => 'スペース',
			'settings.readingPaneContacts' => '連絡先',
			'nav.createNew' => '新規',
			'nav.add' => '追加',
			'nav.recordAudio' => '音声を録音',
			'nav.recordMeeting' => '会議を録音',
			'nav.importFile' => 'ファイルを取り込む',
			'nav.addPhoto' => '写真を追加',
			'nav.addVideo' => '動画を追加',
			'nav.addFile' => 'ファイルを追加',
			'nav.collapse' => '折りたたむ',
			'nav.expand' => '広げる',
			'inbox.title' => '受信箱',
			'inbox.searchPlaceholder' => 'トランスクリプト、タグ、スペースを検索...',
			'inbox.noResults' => '録音が見つかりません',
			'inbox.recordings' => '件の録音',
			'inbox.matomeCount' => ({required Object n}) => '${n} 件のマトメ',
			'inbox.searchHint' => 'マトメを検索',
			'inbox.empty' => 'マトメがありません',
			'inbox.emptyHint' => '録音やアップロードしたマトメがここに表示されます。',
			'inbox.noMatches' => '一致するマトメがありません',
			'inbox.noMatchesHint' => '別の検索語をお試しください。',
			'inbox.loadFailed' => 'マトメを読み込めませんでした',
			'inbox.selectHint' => 'プレビューするマトメを選択',
			'inbox.looseTag' => '未整理',
			'inbox.draftTag' => '下書き',
			'inbox.fileAction' => '整理',
			'inbox.organizeAction' => '整理',
			'inbox.looseMeta' => ({required Object type, required Object time}) => '${type} · ${time}',
			'inbox.draftMeta' => ({required Object n}) => '${n} 件',
			'inbox.fileIntoSpaceTitle' => 'スペースに整理',
			'inbox.fileSearchHint' => 'スペースを検索',
			'inbox.fileEmpty' => 'スペースがありません',
			'inbox.groupIntoMatomeTitle' => 'マトメにまとめる',
			'inbox.groupSearchHint' => 'マトメを検索',
			'inbox.groupEmpty' => 'マトメがありません',
			'cardStatus.pendingUpload' => '端末に保存済み · アップロード待ち',
			'cardStatus.processing' => '文字起こし中…',
			'cardStatus.failed' => 'アップロードに失敗しました',
			'cardStatus.processingFailed' => '処理に失敗しました',
			'cardStatus.processingTimedOut' => '処理がタイムアウトしました',
			'cardStatus.retry' => '再試行',
			'cardStatus.onDevice' => '端末内',
			'cardStatus.cloud' => '同期済み',
			'cardStatus.syncing' => '同期中',
			'cardStatus.syncState' => '同期状態',
			'cardStatus.local' => 'ローカル',
			'recording.title' => '録音中',
			'recording.ready' => '録音準備完了',
			'recording.startHint' => 'ボタンを押して録音を開始してください',
			'recording.stopHint' => 'タップして一時停止',
			'recording.paused' => '一時停止中',
			'recording.resumeHint' => 'タップして再開',
			'recording.processing' => '保存中…',
			'recording.processingHint' => 'このまま開いたままでも、受信トレイに戻っても構いません。バックグラウンドで保存を続けます。',
			'recording.processingBackground' => '受信トレイで続ける',
			'recording.loading' => '読み込み中…',
			'recording.transcribing' => '文字起こし中…',
			'recording.transcriptionFailed' => '文字起こしに失敗しました',
			'recording.pause' => '一時停止',
			'recording.resume' => '再開',
			'recording.finish' => '完了',
			'recording.discardConfirmTitle' => '録音を破棄しますか？',
			'recording.discardConfirmBody' => 'この録音はまだ保存されていません。今ここを離れると音声は失われます。',
			'recording.discardConfirmKeep' => '録音を続ける',
			'recording.discardConfirmDiscard' => '破棄',
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
			'details.moreActions' => 'その他の操作',
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
			'details.audioUnavailable' => '音声を利用できません',
			'fileView.contents' => 'コンテンツ',
			'fileView.notes' => 'メモ',
			'fileView.notesHint' => '自分用のメモを書く…',
			'fileView.viewFullscreen' => '全画面で表示',
			'fileView.fileChip.open' => '開く',
			'fileView.fileChip.soon' => '近日対応',
			'fileView.fileChip.unknownSize' => '—',
			'fileView.contentsTag.transcript' => 'トランスクリプト',
			'fileView.contentsTag.description' => '説明',
			'fileView.contentsTag.document' => 'ドキュメント',
			'fileView.processingState.queued' => '待機中',
			'fileView.processingState.processing' => '処理中',
			'fileView.processingState.succeeded' => '完了',
			'fileView.processingState.partial' => '一部完了',
			'fileView.processingState.failed' => '失敗',
			'fileView.processingState.notAvailable' => '利用できません',
			'fileView.contentsStatus.audio.processing' => '文字起こし中…',
			'fileView.contentsStatus.audio.failed' => '文字起こしに失敗しました',
			'fileView.contentsStatus.audio.empty' => 'トランスクリプトはまだありません',
			'fileView.contentsStatus.image.processing' => '説明を生成中…',
			'fileView.contentsStatus.image.failed' => '説明の生成に失敗しました',
			'fileView.contentsStatus.image.empty' => '説明はまだありません',
			'fileView.contentsStatus.doc.processing' => '処理中…',
			'fileView.contentsStatus.doc.failed' => '処理に失敗しました',
			'fileView.contentsStatus.doc.empty' => 'コンテンツはまだありません',
			'matome.title' => 'まとめ',
			'matome.notFound' => 'まとめが見つかりません',
			'matome.recordings' => 'アイテム',
			'matome.noRecordings' => 'アイテムはまだありません',
			'matome.summary' => '要約',
			'matome.noSummary' => '要約はまだありません',
			'matome.placeInbox' => '受信箱',
			'matome.regenerateSummary' => '要約を再生成',
			'matome.summaryStale' => 'アイテムが変更されました — 要約が古い可能性があります',
			'matome.notes' => 'メモ',
			'matome.noNotes' => 'メモはまだありません',
			'matome.fileIntoSpace' => 'スペースに整理',
			'matome.fileIntoSpaceSheetTitle' => 'スペースに整理',
			'matome.filedIn' => ({required Object space}) => '${space} に整理済み',
			'matome.refile' => '再整理',
			'matome.personalSpaceHint' => 'デフォルト',
			'matome.addItem' => '項目を追加',
			'matome.addPhoto' => '写真を追加',
			'matome.addVideo' => '動画を追加',
			'matome.addFile' => 'ファイルを追加',
			'matome.addFileFailed' => ({required Object error}) => 'ファイルの追加に失敗しました: ${error}',
			'matome.fileTooLarge' => ({required Object name, required Object max}) => '「${name}」は大きすぎます（最大 ${max} MB）',
			'matome.edit' => '編集',
			'matome.editNotes' => 'メモを編集',
			'matome.notesHint' => 'このまとめについてのメモ…',
			'matome.save' => '保存',
			'matome.cancel' => 'キャンセル',
			'matome.tagContacts' => '連絡先をタグ付け',
			'matome.share' => '共有',
			'matome.comingSoon' => '近日公開',
			'matome.contacts' => '連絡先',
			'matome.addContact' => '人を追加',
			'matome.noContacts' => '連絡先は追加されていません',
			'matome.addContactSheetTitle' => '連絡先を追加',
			'matome.noDirectoryContacts' => 'ディレクトリに連絡先がありません',
			'matome.removeContact' => '連絡先を削除',
			'matome.roleAttendee' => '参加者',
			'matome.roleOrganizer' => '主催者',
			'matome.roleSpeaker' => '発表者',
			'matome.itemCount' => ({required Object n}) => '${n} 件のアイテム',
			'matome.remove' => '削除',
			'matome.removeItemTitle' => 'アイテムを削除',
			'matome.removeItemBody' => ({required Object title}) => '「${title}」をこのまとめから削除しますか？',
			'matome.imageUnavailable' => '画像を表示できません',
			'matome.showMore' => 'もっと見る',
			'matome.showLess' => '閉じる',
			'matome.detailPanelTitle' => '詳細',
			'matome.filesLabel' => '添付',
			'matome.peopleLabel' => '関係者',
			'matome.spaceLabel' => '保存先',
			'matome.statusLabel' => '状態',
			'matome.filesPreviewMore' => ({required Object n}) => '他${n}件',
			'matome.noFiles' => '項目はまだありません',
			'matome.noPeople' => '関係者はまだいません',
			'matome.relationPicker.addToThisMatome' => 'このまとめに追加',
			'matome.relationPicker.search' => '連絡先・ファイル・スペースを検索',
			'matome.relationPicker.typeContacts' => '連絡先',
			'matome.relationPicker.typeFiles' => 'ファイル',
			'matome.relationPicker.typeSpaces' => 'スペース',
			'matome.relationPicker.labelContact' => '連絡先',
			'matome.relationPicker.labelFile' => 'ファイル',
			'matome.relationPicker.labelSpace' => 'スペース',
			'matome.relationPicker.recordAudio' => '録音',
			'matome.relationPicker.createContact' => '連絡先を作成',
			'matome.relationPicker.newSpace' => '新しいスペース',
			'matome.relationPicker.createContactTitle' => '新しい連絡先',
			'matome.relationPicker.createContactHint' => '連絡先の名前',
			'matome.relationPicker.newSpaceTitle' => '新しいスペース',
			'matome.relationPicker.newSpaceHint' => 'スペース名',
			'matome.relationPicker.empty' => '一致なし。上の作成アクションを使ってください。',
			'matome.relationPicker.add' => '追加',
			'matome.actions.menuTooltip' => 'その他',
			'matome.actions.rename' => '名前を変更',
			'matome.actions.editDateTime' => '日時を編集',
			'matome.actions.regenerateSummary' => '要約を再生成',
			'matome.actions.moveToSpace' => 'スペースへ移動',
			'matome.actions.share' => '共有',
			'matome.actions.soon' => '近日',
			'matome.actions.copySummary' => '要約をコピー',
			'matome.actions.archive' => 'アーカイブ',
			'matome.actions.summaryCopied' => '要約をコピーしました',
			'matome.actions.noSummaryToCopy' => 'コピーできる要約がまだありません',
			'matome.actions.archiveTitle' => 'このまとめをアーカイブしますか？',
			'matome.actions.archiveBody' => 'リストから外れます。アーカイブから復元できます。',
			'matome.actions.archiveConfirm' => 'アーカイブ',
			'matome.actions.archived' => 'まとめをアーカイブしました',
			'matome.actions.undo' => '元に戻す',
			'matome.actions.archivedBanner' => 'このまとめはアーカイブされています',
			'matome.actions.restore' => '復元',
			'matome.actions.renameTitle' => 'まとめの名前を変更',
			'matome.actions.renameLabel' => 'タイトル',
			'matome.actions.renameHint' => 'まとめのタイトル',
			'matome.actions.renameSave' => '保存',
			'matome.actions.renameEmptyError' => 'タイトルを入力してください',
			'matome.actions.renamed' => '名前を変更しました',
			'matome.actions.editDateTimeTitle' => '日時を編集',
			'matome.actions.editDateTimeSave' => '保存',
			'matome.actions.editDateTimeUpdated' => '日時を更新しました',
			'matome.actions.editFailed' => '保存できませんでした — もう一度お試しください',
			'matome.table.colTitle' => 'まとめ',
			'matome.table.colWhen' => '日時',
			'matome.table.colItems' => '項目',
			'matome.table.colPeople' => '関係者',
			'matome.table.colSpace' => '保存先',
			'matome.table.colSync' => '同期',
			'matome.table.selected' => ({required Object n}) => '${n} 件選択中',
			'matome.table.moveToSpace' => '空間へ移動',
			'matome.table.archive' => 'アーカイブ',
			'matome.table.delete' => '削除',
			'matome.table.clear' => '解除',
			'matome.table.cancel' => 'キャンセル',
			'matome.table.undo' => '元に戻す',
			'matome.table.open' => '開く',
			'matome.table.sortBy' => '並び替え',
			'matome.table.inboxLabel' => '受信箱',
			'matome.table.noSummary' => '要約はまだありません',
			'matome.table.emptyTitle' => '表示する項目がありません',
			'matome.table.emptyBody' => '取り込んだまとめや整理したまとめがここに行として表示されます。',
			'matome.table.deleteTitle' => 'まとめを削除しますか？',
			'matome.table.deleteBody' => ({required Object n}) => '${n} 件のまとめを削除します。元に戻せます。',
			'matome.table.archivedMsg' => ({required Object n}) => '${n} 件をアーカイブしました',
			'matome.table.deletedMsg' => ({required Object n}) => '${n} 件を削除しました',
			'matome.table.audioUnit' => '音声',
			'matome.table.imageUnit' => '画像',
			'matome.table.docUnit' => '書類',
			'matome.table.peopleUnit' => '人',
			'matome.table.selectRow' => '行を選択',
			'matome.table.rowActions' => '行の操作',
			'matome.table.viewCards' => 'カード',
			'matome.table.viewTable' => 'テーブル',
			'files.unfiled' => '未整理',
			'files.title' => 'ファイル',
			'files.colName' => '名前',
			'files.colMatome' => 'まとめ',
			'files.colSpace' => '保存先',
			'files.colPeople' => '関係者',
			'files.colWhen' => '日時',
			'files.colSize' => 'サイズ',
			'files.colSync' => '同期',
			'files.selected' => ({required Object n}) => '${n} 件選択中',
			'files.moveToMatome' => 'まとめへ移動',
			'files.download' => 'ダウンロード',
			'files.delete' => '削除',
			'files.clear' => '解除',
			'files.cancel' => 'キャンセル',
			'files.undo' => '元に戻す',
			'files.open' => '開く',
			'files.sortBy' => '並び替え',
			'files.selectFile' => 'ファイルを選択',
			'files.fileActions' => 'ファイルの操作',
			'files.noSize' => '—',
			'files.viewGrid' => 'グリッド',
			'files.viewTable' => 'テーブル',
			'files.emptyTitle' => 'ファイルがありません',
			'files.emptyBody' => '取り込んだファイルは、まとめの有無に関わらずここに表示されます。',
			'files.deleteTitle' => 'ファイルを削除しますか？',
			'files.deleteBody' => ({required Object n}) => '${n} 件のファイルを削除します。元に戻せます。',
			'files.deletedMsg' => ({required Object n}) => '${n} 件を削除しました',
			'files.downloadUnavailable' => 'ダウンロードはまだ利用できません',
			'files.moveSheetTitle' => 'まとめに移動',
			'files.moveUnfiled' => '未整理',
			'files.moveUnfiledHint' => 'まとめなし',
			'files.movedMsg' => ({required Object n}) => '${n} 件を移動しました',
			'files.moveNoTargets' => '移動先のまとめがまだありません',
			'files.scopeAll' => 'すべて',
			'files.scopeLoose' => '未整理',
			'files.scopeInSpace' => 'スペース内',
			'files.fileIntoSpace' => 'スペースに整理',
			'files.fileIntoSpaceInbox' => '受信トレイ',
			'files.fileIntoSpaceInboxHint' => 'スペースなし',
			'files.fileNoSpaces' => '整理先のスペースがまだありません',
			'files.filedMsg' => ({required Object n}) => '${n} 件を整理しました',
			'files.selectHint' => 'ファイルを選択するとここに表示されます',
			'spaces.title' => 'スペース',
			'spaces.empty' => 'スペースがありません',
			'spaces.emptyHint' => '+ をタップしてスペースを作成し、録音を整理しましょう',
			'spaces.count' => ({required Object n}) => '${n} 件の録音',
			'spaces.createTitle' => '新しいスペース',
			'spaces.createHint' => 'スペース名',
			'spaces.create' => '作成',
			'spaces.cancel' => 'キャンセル',
			'spaces.deleteTitle' => 'スペースを削除しますか？',
			'spaces.deleteBody' => 'このスペースの録音は受信トレイに戻ります。',
			'spaces.delete' => '削除',
			'spaces.detailEmpty' => 'このスペースにはまだ録音がありません',
			'spaces.detailEmptyMatomes' => 'このスペースにはまだマトメがありません',
			'spaces.matomeCount' => ({required Object n}) => '${n} 件のマトメ',
			'spaces.selectHint' => 'スペースを選択するとマトメが表示されます',
			'spaces.turnOnSync' => '同期をオンにする',
			'spaces.local' => 'ローカル',
			'spaces.cloud' => 'クラウド',
			'calendar.title' => 'カレンダー',
			'calendar.noRecordings' => 'この日の録音はありません',
			'calendar.noMatomes' => 'この日のマトメはありません',
			'calendar.matomeCount' => ({required Object n}) => '${n} 件のマトメ',
			'calendar.allSpaces' => 'すべて',
			'contacts.title' => '連絡先',
			'contacts.count' => ({required Object n}) => '${n} 件の連絡先',
			'contacts.empty' => '連絡先がありません',
			'contacts.emptyHint' => '+ をタップして連絡先を追加しましょう',
			'contacts.selectHint' => '連絡先を選択するとプレビューが表示されます',
			'contacts.createTitle' => '新しい連絡先',
			'contacts.editTitle' => '連絡先を編集',
			'contacts.nameLabel' => '名前',
			'contacts.nameHint' => '表示名',
			'contacts.notesLabel' => 'メモ',
			'contacts.notesHint' => 'メール、電話番号、その他の詳細',
			'contacts.create' => '追加',
			'contacts.save' => '保存',
			'contacts.cancel' => 'キャンセル',
			'contacts.deleteTitle' => '連絡先を削除しますか？',
			'contacts.deleteBody' => 'この連絡先はディレクトリから削除されます。',
			'contacts.delete' => '削除',
			'contacts.detail.edit' => '編集',
			'contacts.detail.merge' => '統合',
			'contacts.detail.delete' => '削除',
			'contacts.detail.actions' => 'その他',
			'contacts.detail.contactInfo' => '連絡先情報',
			'contacts.detail.notes' => 'メモ',
			'contacts.detail.notesEmpty' => 'メモはまだありません',
			'contacts.detail.matomesLabel' => 'まとめ',
			'contacts.detail.spacesLabel' => 'スペース',
			'contacts.detail.filesLabel' => 'ファイル',
			'contacts.detail.email' => 'メール',
			'contacts.detail.phone' => '電話',
			'contacts.detail.company' => '会社',
			'contacts.detail.addInfo' => '追加',
			'contacts.detail.synced' => '同期済み',
			'contacts.detail.onDevice' => '端末のみ',
			'contacts.detail.empty' => '—',
			'contacts.detail.notFound' => '連絡先が見つかりません',
			'satori.title' => '悟り',
			'satori.subtitle' => '悟 · あなたのAIアシスタント',
			'satori.soon' => '近日公開',
			'satori.underConstruction' => '開発中',
			'satori.headlinePrefix' => 'Satori はもうすぐ',
			'satori.headlineAccent' => '目覚め',
			'satori.headlineSuffix' => 'ます。',
			'satori.body' => 'あなたの録音を検索し、理解します。質問したり、フォローアップを下書きしたり、重要なことを浮かび上がらせたり。リリース目標：次回リリース。',
			'satori.roadmapLabel' => '今後の予定',
			'satori.roadmapSearchTitle' => '録音全体の全文検索',
			'satori.roadmapSearchDetail' => 'v0.8 · 提供開始',
			'satori.roadmapQuestionsTitle' => 'トランスクリプトに質問する',
			'satori.roadmapQuestionsDetail' => '進行中',
			'satori.roadmapEmailsTitle' => '通話からメール・フォローアップを下書き',
			'satori.roadmapEmailsDetail' => '次の予定',
			'satori.roadmapInsightsTitle' => 'スペース横断のインサイトと傾向',
			'satori.roadmapInsightsDetail' => '後ほど',
			'satori.notify' => '準備ができたら通知する',
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
			'auth.forgotPassword' => 'パスワードをお忘れですか？',
			'auth.forgotPasswordTitle' => 'パスワードをリセット',
			'auth.forgotPasswordSubtitle' => 'メールアドレスを入力すると、リセット用のリンクをお送りします。',
			'auth.forgotPasswordSubmit' => 'リセットリンクを送信',
			'auth.forgotPasswordSent' => 'そのメールアドレスのアカウントが存在する場合、リセットリンクを送信しました。受信トレイをご確認ください。',
			'auth.backToSignIn' => 'サインインに戻る',
			'auth.resetPasswordTitle' => '新しいパスワードを設定',
			'auth.resetPasswordSubtitle' => 'メールに記載されたコードを貼り付け、新しいパスワードを設定してください。',
			'auth.resetToken' => 'リセットコード',
			'auth.resetTokenPlaceholder' => 'メールのコードを貼り付けてください',
			'auth.newPassword' => '新しいパスワード',
			'auth.resetPasswordSubmit' => 'パスワードを更新',
			'auth.resetPasswordSuccess' => 'パスワードを更新しました。サインインできます。',
			'auth.errorInvalidCredentials' => 'メールアドレスまたはパスワードが正しくありません。',
			'auth.errorRequiredFields' => 'メールアドレスとパスワードを入力してください。',
			'auth.errorPasswordMismatch' => 'パスワードが一致しません。',
			'auth.errorEmailTaken' => 'そのメールアドレスは既に登録されています。',
			'auth.errorResetTokenInvalid' => 'そのリセットコードは無効か、有効期限が切れています。',
			'auth.errorGeneric' => '問題が発生しました。もう一度お試しください。',
			_ => null,
		};
	}
}
