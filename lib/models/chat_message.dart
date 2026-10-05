import 'package:nart_chat/models/message_role.dart';

/// Tek bir sohbet satırı: metin ve isteğe bağlı yerel medya yolları.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.textContent,
    required this.timestamp,
    this.imagePath,
    this.filePath,
    this.fileName,
    this.fileContext,
    this.toolCallId,
    this.toolName,
    this.toolStatus,
  });

  final String id;
  final MessageRole role;
  final String textContent;
  final String? imagePath;
  final String? filePath;
  final String? fileName;
  final String? fileContext;
  final String? toolCallId;
  final String? toolName;
  final String? toolStatus;
  final DateTime timestamp;

  /// Akış sırasında metni veya araç durumunu değiştiren bir kopya üretir.
  ChatMessage copyWith({String? textContent, String? toolStatus}) {
    return ChatMessage(
      id: id,
      role: role,
      textContent: textContent ?? this.textContent,
      timestamp: timestamp,
      imagePath: imagePath,
      filePath: filePath,
      fileName: fileName,
      fileContext: fileContext,
      toolCallId: toolCallId,
      toolName: toolName,
      toolStatus: toolStatus ?? this.toolStatus,
    );
  }
}
