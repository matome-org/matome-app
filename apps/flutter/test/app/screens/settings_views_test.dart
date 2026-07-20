import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/app/auth_state.dart';
import 'package:matome_flutter/app/screens/settings_screen.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart'
    show AppLocale, AppLocaleUtils, LocaleSettings, TranslationProvider;

/// #1468: the Settings "Default views" section is the config surface for the two
/// view preferences. It must reflect the stored value and write changes back
/// through the SAME persisted providers the in-view toggles use.

const _signedOut = AuthState(isAuthenticated: false, isLoading: false);

Widget _pump(SettingsStore store) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(store),
      authStateProvider.overrideWithValue(_signedOut),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  // A tall surface so the lazy Settings ListView builds every radio row (the
  // views section sits below appearance + language).
  Future<void> pumpSettings(WidgetTester tester, SettingsStore store) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_pump(store));
    await tester.pumpAndSettle();
  }

  testWidgets('reflects the stored inbox + files view selection', (
    tester,
  ) async {
    final store = InMemorySettingsStore({
      'matome.inbox_view': 'table',
      'matome.files_view': 'table',
    });
    await pumpSettings(tester, store);

    // The stored "table" choices flow into the Settings radio groups: each
    // RadioGroup's active selection is the Table option.
    final inboxGroup = tester.widget<RadioGroup<InboxView>>(
      find.byType(RadioGroup<InboxView>),
    );
    final filesGroup = tester.widget<RadioGroup<FilesView>>(
      find.byType(RadioGroup<FilesView>),
    );
    expect(inboxGroup.groupValue, InboxView.table);
    expect(filesGroup.groupValue, FilesView.table);
  });

  testWidgets('tapping a radio persists the new view', (tester) async {
    final store = InMemorySettingsStore();
    await pumpSettings(tester, store);

    // Switch the Matome list to Table (writes through inboxViewProvider).
    final inboxTable = find.byWidgetPredicate(
      (w) => w is RadioListTile<InboxView> && w.value == InboxView.table,
    );
    await tester.tap(inboxTable);
    await tester.pumpAndSettle();
    expect(await store.read('matome.inbox_view'), 'table');

    // Switch Files to Table (writes through filesViewProvider).
    final filesTable = find.byWidgetPredicate(
      (w) => w is RadioListTile<FilesView> && w.value == FilesView.table,
    );
    await tester.tap(filesTable);
    await tester.pumpAndSettle();
    expect(await store.read('matome.files_view'), 'table');
  });
}
