import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/models/payload_type.dart';
import 'package:nart_chat/services/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late LocalDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('nart_chat_test_');
    database = LocalDatabase();
    await database.init(directoryPath: temp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('ayar kutusu boş anahtarlar ve varsayılan profille açılır', () {
    final settings = database.readSettings();
    expect(settings.active.apiKey, isEmpty);
    expect(settings.active.name, 'Cursor Cloud Agent');
    expect(settings.active.endpoint, 'https://api.cursor.com/v1');
    expect(settings.active.modelName, isEmpty);
    expect(
      settings.profiles.any((profile) => profile.name == 'Cursor Cloud Agent'),
      isTrue,
    );
    expect(
      settings.profiles
          .firstWhere((profile) => profile.name == 'Cursor Cloud Agent')
          .endpoint,
      'https://api.cursor.com/v1',
    );
    expect(settings.systemPrompt, isEmpty);
    expect(settings.temperature, isNull);
    expect(settings.maxTokens, isNull);
    expect(settings.topP, isNull);
    expect(settings.sendFullHistory, isTrue);
    expect(settings.payloadType, PayloadType.base64);
  });

  test('geçersiz composer-2 modeli bir sonraki açılışta silinir', () async {
    final settings = database.readSettings();
    await database.writeSettings(
      settings.copyWith(
        profiles: [
          for (final profile in settings.profiles)
            if (profile.id == settings.active.id)
              profile.copyWith(modelName: 'composer-2')
            else
              profile,
        ],
      ),
    );
    await Hive.close();

    final again = LocalDatabase();
    await again.init(directoryPath: temp.path);
    expect(again.readSettings().active.modelName, isEmpty);
  });

  test('ayarlar ve sohbet oturumu yeniden açılınca durur', () async {
    final settings = database.readSettings().copyWith(
      systemPrompt: 'Kısa yaz',
      temperature: 0.2,
      profiles: [
        database.readSettings().active.copyWith(
          apiKey: 'anahtar',
          endpoint: 'https://example.com/v1',
          modelName: 'demo',
        ),
      ],
    );
    await database.writeSettings(settings);

    final session = ChatSession(
      id: 's1',
      title: 'Deneme',
      createdAt: DateTime.utc(2026, 4, 1),
      profileId: 'default',
      messages: [
        ChatMessage(
          id: 'm1',
          role: MessageRole.user,
          textContent: 'Selam',
          timestamp: DateTime.utc(2026, 4, 1, 1),
          fileName: 'not.txt',
          fileContext: 'gizli bağlam',
        ),
      ],
    );
    await database.saveSession(session);
    await Hive.close();

    final again = LocalDatabase();
    await again.init(directoryPath: temp.path);
    final loadedSettings = again.readSettings();
    expect(loadedSettings.active.apiKey, 'anahtar');
    expect(loadedSettings.systemPrompt, 'Kısa yaz');
    expect(loadedSettings.temperature, 0.2);
    final loaded = again.loadSessions().single;
    expect(loaded.title, 'Deneme');
    expect(loaded.messages.single.fileContext, 'gizli bağlam');
    expect(loaded.messages.single.role, MessageRole.user);
  });
}
