import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/app.dart';
import 'package:nart_chat/services/local_database.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/utils/providers.dart';

/// Yerel veritabanını açar ve uygulamayı başlatır.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final database = LocalDatabase();
  await database.init();
  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const NartApp(),
    ),
  );
}
