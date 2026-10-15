import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/db/hive_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveSetup.init();
  runApp(const ProviderScope(child: GoodReaderApp()));
}

/// Exposed so integration tests can boot the app against a temp Hive dir.
Future<void> bootstrap({String? hiveSubDir}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveSetup.init(subDir: hiveSubDir);
  await Hive.box(HiveBoxes.settings).close();
}
