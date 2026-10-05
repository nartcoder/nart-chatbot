import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/utils/time_format.dart';

/// Oturumu paylaşılabilir düz metne çevirir.
String renderSessionText(ChatSession session) {
  final buffer = StringBuffer()
    ..writeln(session.title)
    ..writeln(formatStamp(session.createdAt))
    ..writeln();
  for (final message in session.messages) {
    final label = switch (message.role) {
      MessageRole.user => 'Kullanıcı',
      MessageRole.ai => 'AI',
      MessageRole.error => 'Hata',
      MessageRole.thinking => 'Düşünme',
      MessageRole.tool => 'Araç',
    };
    buffer
      ..writeln('[$label] ${formatStamp(message.timestamp)}')
      ..writeln(message.textContent);
    if (message.fileName != null) {
      buffer.writeln('Dosya: ${message.fileName}');
    }
    final context = message.fileContext?.trim();
    if (context != null && context.isNotEmpty) {
      buffer.writeln('[Eklenen Dosya İçeriği: $context]');
    }
    buffer.writeln();
  }
  return buffer.toString();
}
