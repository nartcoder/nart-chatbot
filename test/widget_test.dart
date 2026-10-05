import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nart_chat/app.dart';
import 'package:nart_chat/services/local_database.dart';
import 'package:nart_chat/utils/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('nart_chat_widget_');
  });

  tearDown(() async {
    await Hive.close();
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'boş sohbet ve ayarlar alanları görünür',
    (tester) async {
      final database = LocalDatabase();
      await tester.runAsync(() => database.init(directoryPath: temp.path));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localDatabaseProvider.overrideWithValue(database)],
          child: const NartApp(),
        ),
      );
      await tester.pump();
      expect(find.text('NART Chatbot'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('NART Chatbot'), findsOneWidget);
      expect(find.text('İlk mesajını yaz.'), findsOneWidget);
      expect(find.text('Mesaj yaz'), findsOneWidget);

      await tester.tap(find.byTooltip('Menü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Geçmiş Sohbetler'), findsOneWidget);
      expect(find.text('Sohbetlerde ara'), findsOneWidget);

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('Özel API Endpoint URL'), findsOneWidget);
      for (final label in [
        'Sistem İstemi',
        'Temperature',
        'Max Tokens',
        'Top P',
      ]) {
        final target = find.text(label);
        for (var step = 0; step < 8 && target.evaluate().isEmpty; step++) {
          await tester.drag(
            find.byKey(const Key('settings-list')),
            const Offset(0, -320),
          );
          await tester.pump();
        }
        expect(target, findsOneWidget);
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
