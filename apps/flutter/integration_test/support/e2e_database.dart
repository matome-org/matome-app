import 'package:matome_flutter/core/db/app_database.dart';

import 'e2e_database_native.dart'
    if (dart.library.js_interop) 'e2e_database_web.dart'
    as platform;

Future<AppDatabase> createE2EDatabase() => platform.createE2EDatabase();
