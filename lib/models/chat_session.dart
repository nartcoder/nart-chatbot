import 'package:nart_chat/models/chat_message.dart';

/// Bir sohbet oturumu ve ona ait tüm mesaj geçmişi.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    this.profileId,
    this.titleGenerated = false,
    this.agentId,
    this.runId,
    this.repoUrl,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;
  final String? profileId;
  final bool titleGenerated;
  final String? agentId;
  final String? runId;
  final String? repoUrl;

  /// Listenin son hareket zamanını döndürür; boşsa oluşturulma zamanıdır.
  DateTime get lastActivity =>
      messages.isEmpty ? createdAt : messages.last.timestamp;

  /// Başlığı veya mesaj listesini değiştiren yeni bir oturum kopyalar.
  ChatSession copyWith({
    String? title,
    List<ChatMessage>? messages,
    String? profileId,
    bool? titleGenerated,
    String? agentId,
    bool clearAgentId = false,
    String? runId,
    bool clearRunId = false,
    String? repoUrl,
    bool clearRepoUrl = false,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      messages: messages ?? this.messages,
      profileId: profileId ?? this.profileId,
      titleGenerated: titleGenerated ?? this.titleGenerated,
      agentId: clearAgentId ? null : (agentId ?? this.agentId),
      runId: clearRunId ? null : (runId ?? this.runId),
      repoUrl: clearRepoUrl ? null : (repoUrl ?? this.repoUrl),
    );
  }
}
