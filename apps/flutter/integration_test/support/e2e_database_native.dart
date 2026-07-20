import 'package:drift/native.dart';
import 'package:matome_flutter/core/db/app_database.dart';

Future<AppDatabase> createE2EDatabase() async =>
    AppDatabase.forTesting(NativeDatabase.memory());
