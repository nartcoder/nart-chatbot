import 'package:flutter_test/flutter_test.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/app_settings.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/models/payload_type.dart';
import 'package:nart_chat/services/chat_payload.dart';

void main() {
  const profile = ApiProfile(
    id: 'default',
    name: 'Varsayılan',
    endpoint: 'https://example.com/v1/chat',
    apiKey: 'secret',
    modelName: 'llama3',
  );

  final history = [
    ChatMessage(
      id: '1',
      role: MessageRole.user,
      textContent: 'Merhaba',
      timestamp: DateTime.utc(2026, 1, 1),
      fileContext: 'dosya satırı',
    ),
    ChatMessage(
      id: '2',
      role: MessageRole.ai,
      textContent: 'Selam',
      timestamp: DateTime.utc(2026, 1, 1, 0, 1),
    ),
    ChatMessage(
      id: '3',
      role: MessageRole.error,
      textContent: 'olmadı',
      timestamp: DateTime.utc(2026, 1, 1, 0, 2),
    ),
  ];

  test('boş üretim alanlarını göndermez ve hata balonunu atlar', () {
    final body = buildChatPayload(
      history: history,
      profile: profile,
      settings: AppSettings.initial().copyWith(
        profiles: const [profile],
        activeProfileId: profile.id,
      ),
    );

    expect(body.containsKey('temperature'), isFalse);
    expect(body.containsKey('max_tokens'), isFalse);
    expect(body.containsKey('top_p'), isFalse);
    expect(body['stream'], isTrue);
    expect(body['model'], 'llama3');
    final messages = body['messages'] as List;
    expect(messages, hasLength(2));
    expect(
      messages.first['content'],
      contains('[Eklenen Dosya İçeriği: dosya satırı]'),
    );
    expect(messages.last['role'], 'assistant');
  });

  test('sistem istemini ve sayısal parametreleri ekler', () {
    final body = buildChatPayload(
      history: history,
      profile: profile.copyWith(modelName: ''),
      settings: AppSettings.initial().copyWith(
        systemPrompt: 'Kısa yanıt ver',
        temperature: 0.4,
        maxTokens: 128,
        topP: 0.9,
      ),
      stream: false,
    );

    expect(body.containsKey('model'), isFalse);
    expect(body['temperature'], 0.4);
    expect(body['max_tokens'], 128);
    expect(body['top_p'], 0.9);
    expect(body['stream'], isFalse);
    final messages = body['messages'] as List;
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], 'Kısa yanıt ver');
  });

  test('geçmiş kapatılınca yalnız son kullanıcı mesajı gider', () {
    final body = buildChatPayload(
      history: history,
      profile: profile,
      settings: AppSettings.initial().copyWith(sendFullHistory: false),
    );
    final messages = body['messages'] as List;
    expect(messages, hasLength(1));
    expect(messages.single['role'], 'user');
  });

  test('base64 resim son kullanıcı mesajına eklenir', () {
    final body = buildChatPayload(
      history: history,
      profile: profile,
      settings: AppSettings.initial(),
      imageBase64: 'abc',
      imageMime: 'image/png',
    );
    final messages = body['messages'] as List;
    final user = messages.firstWhere((message) => message['role'] == 'user');
    final content = user['content'] as List;
    expect(content.last['image_url']['url'], 'data:image/png;base64,abc');
  });

  test('multipart yalnız medya varken seçilir', () {
    expect(
      shouldUseMultipart(
        payloadType: PayloadType.multipart,
        hasImage: true,
        hasFile: false,
      ),
      isTrue,
    );
    expect(
      shouldUseMultipart(
        payloadType: PayloadType.base64,
        hasImage: true,
        hasFile: true,
      ),
      isFalse,
    );
    expect(
      shouldUseMultipart(
        payloadType: PayloadType.multipart,
        hasImage: false,
        hasFile: false,
      ),
      isFalse,
    );
  });
}
