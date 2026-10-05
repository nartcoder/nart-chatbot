import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/pending_attachment.dart';

/// Sohbet ekranının anlık durumu.
class ChatState {
  const ChatState({
    this.sessions = const [],
    this.activeSessionId,
    this.isSending = false,
    this.sendingSessionId,
    this.isStreaming = false,
    this.streamingMessageId,
    this.speakingMessageId,
    this.isListening = false,
    this.searchQuery = '',
    this.notice,
    this.dictation,
    this.image,
    this.file,
    this.draftRepoUrl,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final bool isSending;
  final String? sendingSessionId;
  final bool isStreaming;
  final String? streamingMessageId;
  final String? speakingMessageId;
  final bool isListening;
  final String searchQuery;
  final String? notice;
  final String? dictation;
  final PendingAttachment? image;
  final PendingAttachment? file;
  final String? draftRepoUrl;

  /// Açık sohbetin reposu; sohbet yoksa taslak adres.
  String? get selectedRepoUrl {
    final session = activeSession;
    if (session != null) return session.repoUrl;
    return draftRepoUrl;
  }

  /// Açık oturumu döndürür.
  ChatSession? get activeSession {
    final id = activeSessionId;
    if (id == null) return null;
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// Arama kutusuna göre başlık ve mesaj metnini süzer.
  List<ChatSession> get visibleSessions {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return sessions;
    return [
      for (final session in sessions)
        if (_matches(session, query)) session,
    ];
  }

  /// Alanları seçerek yeni bir durum kopyalar.
  ChatState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    bool clearActiveSession = false,
    bool? isSending,
    String? sendingSessionId,
    bool clearSendingSession = false,
    bool? isStreaming,
    String? streamingMessageId,
    bool clearStreamingMessage = false,
    String? speakingMessageId,
    bool clearSpeaking = false,
    bool? isListening,
    String? searchQuery,
    String? notice,
    bool clearNotice = false,
    String? dictation,
    bool clearDictation = false,
    PendingAttachment? image,
    bool clearImage = false,
    PendingAttachment? file,
    bool clearFile = false,
    String? draftRepoUrl,
    bool clearDraftRepo = false,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      isSending: isSending ?? this.isSending,
      sendingSessionId: clearSendingSession
          ? null
          : (sendingSessionId ?? this.sendingSessionId),
      isStreaming: isStreaming ?? this.isStreaming,
      streamingMessageId: clearStreamingMessage
          ? null
          : (streamingMessageId ?? this.streamingMessageId),
      speakingMessageId: clearSpeaking
          ? null
          : (speakingMessageId ?? this.speakingMessageId),
      isListening: isListening ?? this.isListening,
      searchQuery: searchQuery ?? this.searchQuery,
      notice: clearNotice ? null : (notice ?? this.notice),
      dictation: clearDictation ? null : (dictation ?? this.dictation),
      image: clearImage ? null : (image ?? this.image),
      file: clearFile ? null : (file ?? this.file),
      draftRepoUrl: clearDraftRepo ? null : (draftRepoUrl ?? this.draftRepoUrl),
    );
  }

  bool _matches(ChatSession session, String query) {
    if (session.title.toLowerCase().contains(query)) return true;
    for (final message in session.messages) {
      if (message.textContent.toLowerCase().contains(query)) return true;
    }
    return false;
  }
}
