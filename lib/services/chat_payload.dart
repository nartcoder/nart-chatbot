import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/app_settings.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/models/payload_type.dart';

/// Sohbet isteğinin JSON gövdesini kurar.
///
/// Boş temperature, max token ve top_p anahtarları yazılmaz; uç nokta kendi
/// varsayılanını kullanır. Metin olduğu gibi gider, kelime filtresi uygulanmaz.
Map<String, dynamic> buildChatPayload({
  required List<ChatMessage> history,
  required ApiProfile profile,
  required AppSettings settings,
  String? imageBase64,
  String? imageMime,
  String? fileBase64,
  String? fileName,
  bool stream = true,
}) {
  final messages = <Map<String, dynamic>>[];
  final system = settings.systemPrompt.trim();
  if (system.isNotEmpty) {
    messages.add({'role': 'system', 'content': system});
  }

  final usable = [
    for (final message in history)
      if (message.role != MessageRole.error &&
          message.role != MessageRole.thinking &&
          message.role != MessageRole.tool)
        message,
  ];
  final selected = settings.sendFullHistory || usable.isEmpty
      ? usable
      : [
          usable.lastWhere(
            (message) => message.role == MessageRole.user,
            orElse: () => usable.last,
          ),
        ];

  var lastUserIndex = -1;
  for (var index = 0; index < selected.length; index++) {
    if (selected[index].role == MessageRole.user) {
      lastUserIndex = index;
    }
  }
  for (var index = 0; index < selected.length; index++) {
    final message = selected[index];
    final attachImage =
        index == lastUserIndex &&
        imageBase64 != null &&
        settings.payloadType == PayloadType.base64;
    messages.add(
      _messageJson(
        message,
        imageBase64: attachImage ? imageBase64 : null,
        imageMime: imageMime,
      ),
    );
  }

  final body = <String, dynamic>{'messages': messages, 'stream': stream};
  final model = profile.modelName.trim();
  if (model.isNotEmpty) body['model'] = model;
  if (settings.temperature != null) body['temperature'] = settings.temperature;
  if (settings.maxTokens != null) body['max_tokens'] = settings.maxTokens;
  if (settings.topP != null) body['top_p'] = settings.topP;
  if (fileBase64 != null && settings.payloadType == PayloadType.base64) {
    body['file_base64'] = fileBase64;
    if (fileName != null) body['file_name'] = fileName;
  }
  return body;
}

/// Medya varken ve ayar multipart ise form-data kullanılacağını söyler.
bool shouldUseMultipart({
  required PayloadType payloadType,
  required bool hasImage,
  required bool hasFile,
}) {
  return payloadType == PayloadType.multipart && (hasImage || hasFile);
}

Map<String, dynamic> _messageJson(
  ChatMessage message, {
  String? imageBase64,
  String? imageMime,
}) {
  final text = _apiText(message);
  final role = message.role == MessageRole.user ? 'user' : 'assistant';
  if (imageBase64 == null) {
    return {'role': role, 'content': text};
  }
  return {
    'role': role,
    'content': [
      {'type': 'text', 'text': text},
      {
        'type': 'image_url',
        'image_url': {
          'url': 'data:${imageMime ?? 'image/jpeg'};base64,$imageBase64',
        },
      },
    ],
  };
}

/// Dosya metnini, ekranda göstermeden model bağlamına ekler.
String _apiText(ChatMessage message) {
  final context = message.fileContext?.trim();
  if (context == null || context.isEmpty) return message.textContent;
  return '${message.textContent}\n\n[Eklenen Dosya İçeriği: $context]';
}
