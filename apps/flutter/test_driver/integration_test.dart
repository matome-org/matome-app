import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver for `flutter drive` integration tests.
///
/// Enables running the `integration_test/*` suites on the **web** platform
/// (which `flutter test -d chrome` does not support), via:
///   chromedriver --port=4444 &
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=`integration_test/<file>.dart` -d web-server --browser-name=chrome
Future<void> main() => integrationDriver();
