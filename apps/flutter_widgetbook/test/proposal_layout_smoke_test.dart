import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_widgetbook/widgetbook.dart';

void main() {
  testWidgets('master-detail proposal scenes render without exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LocaleSettings.setLocaleSync(AppLocale.en);

    final scenes = <Widget Function(BuildContext)>[
      mdFilesTablePanelUseCase, // previously crashed
      mdFilesGridPanelUseCase, // previously crashed
      mdInboxListPanelUseCase,
      mdInboxTablePanelUseCase,
      mdInboxEmptyPaneUseCase,
      mdSpacesPanelUseCase,
      mdSpacesNoPanelUseCase,
      mdContactsPanelUseCase,
      mdContactsNoPanelUseCase,
      mdMobileListUseCase, // real icon-only dock
      mdMobileDetailUseCase,
    ];

    for (final scene in scenes) {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: Builder(builder: (context) => Scaffold(body: scene(context))),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
