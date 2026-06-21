import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Task #1441 — FileView slang i18n coverage (en/ja).
///
/// Two guarantees, asserted independently so a regression points straight at the
/// cause:
///   1. Every FileView-spine slang key resolves to a NON-EMPTY string in BOTH
///      locales (catalog-level — fails the moment a key is dropped or left blank
///      in one locale).
///   2. A pumped [FileView] renders the ACTIVE locale's strings (wiring-level —
///      fails if a component ever hardcodes a literal instead of reading slang).
///
/// Surface boundary: this touches only i18n + the presentational FileView; it
/// asserts nothing about the host's DB / routing / state-machine behaviour.
void main() {
  // The FileView naming spine, expressed per-locale. Both maps MUST share the
  // same keys; mismatched key sets fail the parity check below.
  ({
    String contents,
    String notes,
    String notesHint,
    String viewFullscreen,
    String tagTranscript,
    String tagDescription,
    String tagDocument,
    String audioProcessing,
    String audioFailed,
    String audioEmpty,
    String imageProcessing,
    String imageFailed,
    String imageEmpty,
    String docProcessing,
    String docFailed,
    String docEmpty,
  }) spine(AppLocale locale) {
    final fv = locale.translations.fileView;
    return (
      contents: fv.contents,
      notes: fv.notes,
      notesHint: fv.notesHint,
      viewFullscreen: fv.viewFullscreen,
      tagTranscript: fv.contentsTag.transcript,
      tagDescription: fv.contentsTag.description,
      tagDocument: fv.contentsTag.document,
      audioProcessing: fv.contentsStatus.audio.processing,
      audioFailed: fv.contentsStatus.audio.failed,
      audioEmpty: fv.contentsStatus.audio.empty,
      imageProcessing: fv.contentsStatus.image.processing,
      imageFailed: fv.contentsStatus.image.failed,
      imageEmpty: fv.contentsStatus.image.empty,
      docProcessing: fv.contentsStatus.doc.processing,
      docFailed: fv.contentsStatus.doc.failed,
      docEmpty: fv.contentsStatus.doc.empty,
    );
  }

  group('FileView slang keys resolve non-empty in en + ja', () {
    for (final locale in [AppLocale.en, AppLocale.ja]) {
      test(locale.languageCode, () {
        final s = spine(locale);
        // Every string in the spine record must be present and non-blank.
        final values = <String, String>{
          'contents': s.contents,
          'notes': s.notes,
          'notesHint': s.notesHint,
          'viewFullscreen': s.viewFullscreen,
          'tag.transcript': s.tagTranscript,
          'tag.description': s.tagDescription,
          'tag.document': s.tagDocument,
          'status.audio.processing': s.audioProcessing,
          'status.audio.failed': s.audioFailed,
          'status.audio.empty': s.audioEmpty,
          'status.image.processing': s.imageProcessing,
          'status.image.failed': s.imageFailed,
          'status.image.empty': s.imageEmpty,
          'status.doc.processing': s.docProcessing,
          'status.doc.failed': s.docFailed,
          'status.doc.empty': s.docEmpty,
        };
        values.forEach((key, value) {
          expect(
            value.trim(),
            isNotEmpty,
            reason: 'fileView.$key is blank in ${locale.languageCode}',
          );
        });
      });
    }
  });

  test('en and ja translate the spine differently (no untranslated fallthrough)',
      () {
    final en = spine(AppLocale.en);
    final ja = spine(AppLocale.ja);
    // Sanity that ja is a real translation, not the base locale leaking through.
    expect(ja.contents, isNot(equals(en.contents)));
    expect(ja.notes, isNot(equals(en.notes)));
    expect(ja.audioProcessing, isNot(equals(en.audioProcessing)));
    expect(ja.imageEmpty, isNot(equals(en.imageEmpty)));
  });

  group('FileView renders the active locale strings', () {
    Widget host(FileMediaKind kind) {
      return TranslationProvider(
        child: MaterialApp(
          locale: LocaleSettings.currentLocale.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildLightTheme(),
          home: Scaffold(
            body: FileView(
              data: FileViewData(
                title: 'Sample',
                mediaKind: kind,
                contentsState: ContentsState.empty,
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpUnder(
      WidgetTester tester,
      AppLocale locale,
      FileMediaKind kind,
    ) async {
      LocaleSettings.setLocaleSync(locale);
      await tester.pumpWidget(host(kind));
      await tester.pump();
    }

    tearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));

    for (final locale in [AppLocale.en, AppLocale.ja]) {
      testWidgets('audio variant — ${locale.languageCode}', (tester) async {
        await pumpUnder(tester, locale, FileMediaKind.audio);
        final s = spine(locale);
        // Umbrella label, per-type tag, empty-state copy, and Notes label all
        // come from this locale's catalog.
        expect(find.text(s.contents), findsOneWidget);
        expect(find.text(s.tagTranscript), findsOneWidget);
        expect(find.text(s.audioEmpty), findsOneWidget);
        expect(find.text(s.notes), findsOneWidget);
      });

      testWidgets('image variant — ${locale.languageCode}', (tester) async {
        await pumpUnder(tester, locale, FileMediaKind.image);
        final s = spine(locale);
        expect(find.text(s.tagDescription), findsOneWidget);
        expect(find.text(s.imageEmpty), findsOneWidget);
      });
    }
  });
}
