import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nart_chat/controllers/chat_state.dart';
import 'package:nart_chat/controllers/settings_controller.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/models/pending_attachment.dart';
import 'package:nart_chat/services/api_exception.dart';
import 'package:nart_chat/services/api_service.dart';
import 'package:nart_chat/services/cursor_agent_service.dart';
import 'package:nart_chat/services/attachment_store.dart';
import 'package:nart_chat/services/document_text.dart';
import 'package:nart_chat/services/export_service.dart';
import 'package:nart_chat/services/local_database.dart';
import 'package:nart_chat/services/voice_service.dart';
import 'package:nart_chat/utils/cursor_sse.dart';
import 'package:nart_chat/utils/file_kind.dart';
import 'package:nart_chat/utils/limits.dart';
import 'package:nart_chat/utils/providers.dart';
import 'package:nart_chat/utils/response_parser.dart';
import 'package:nart_chat/utils/session_title.dart';
import 'package:uuid/uuid.dart';

/// Sohbet oturumları, akış ve ekler için denetleyici.
class ChatController extends Notifier<ChatState> {
  final ImagePicker _picker = ImagePicker();
  CancelToken? _cancel;
  var _generation = 0;
  var _streamBuffer = '';
  String? _streamMessageId;

  @override
  ChatState build() {
    ref.onDispose(() => _cancel?.cancel());
    return ChatState(sessions: ref.read(localDatabaseProvider).loadSessions());
  }

  /// Boş bir sohbet taslağı açar.
  void startNewChat() {
    unawaited(stopListening());
    state = state.copyWith(
      clearActiveSession: true,
      clearImage: true,
      clearFile: true,
      clearDictation: true,
      isListening: false,
    );
  }

  /// Geçmişten bir oturumu ekrana alır.
  void openSession(String id) {
    unawaited(stopListening());
    state = state.copyWith(
      activeSessionId: id,
      clearImage: true,
      clearFile: true,
      clearDictation: true,
      isListening: false,
    );
  }

  /// Oturumu listeden ve Hive kutusundan siler.
  Future<void> deleteSession(String id) async {
    if (state.sendingSessionId == id) {
      _cancel?.cancel();
      _generation++;
    }
    await _database.deleteSession(id);
    final remaining = [
      for (final session in state.sessions)
        if (session.id != id) session,
    ];
    final closingActive = state.activeSessionId == id;
    state = state.copyWith(
      sessions: remaining,
      clearActiveSession: closingActive,
      isSending: closingActive ? false : state.isSending,
      isStreaming: closingActive ? false : state.isStreaming,
      clearSendingSession: closingActive,
    );
  }

  /// Çekmece aramasını günceller.
  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Tek seferlik uyarıyı temizler.
  void clearNotice() {
    state = state.copyWith(clearNotice: true);
  }

  /// Bu sohbetin bundan sonraki isteklerinde kullanılacak profili seçer.
  Future<void> selectProfile(String id) async {
    await ref.read(settingsControllerProvider.notifier).setActiveProfile(id);
    final session = state.activeSession;
    if (session == null) return;
    final updated = session.copyWith(profileId: id);
    state = state.copyWith(sessions: _upsert(updated));
    await _database.saveSession(updated);
  }

  /// Galeriden resim seçer, sıkıştırır ve önizlemeye koyar.
  Future<void> pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final length = await image.length();
      if (length > maxAttachmentBytes) {
        _notice(fileTooLargeMessage);
        return;
      }
      final original = await image.readAsBytes();
      final compressed = await compressImage(
        sourcePath: image.path,
        original: original,
      );
      final path = await persistBytes(compressed, 'resim.jpg');
      state = state.copyWith(
        image: PendingAttachment(path: path, name: image.name),
        clearNotice: true,
      );
    } catch (_) {
      _notice('Resim seçilemedi.');
    }
  }

  /// Dosya seçer; txt, csv ve pdf ise metnini ayıklar.
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.size > maxAttachmentBytes) {
        _notice(fileTooLargeMessage);
        return;
      }
      final bytes =
          picked.bytes ??
          (picked.path == null ? null : await readFileBytes(picked.path!));
      if (bytes == null) {
        _notice('Dosya okunamadı.');
        return;
      }
      if (bytes.length > maxAttachmentBytes) {
        _notice(fileTooLargeMessage);
        return;
      }
      String? extracted;
      if (isReadableDocument(picked.name)) {
        try {
          final text = extractDocumentText(picked.name, bytes)?.trim();
          extracted = text == null || text.isEmpty ? null : text;
        } catch (_) {
          _notice('Dosya metni okunamadı.');
          return;
        }
      }
      final path = await persistBytes(bytes, picked.name);
      state = state.copyWith(
        file: PendingAttachment(
          path: path,
          name: picked.name,
          extractedText: extracted,
        ),
        clearNotice: true,
      );
    } catch (_) {
      _notice('Dosya seçilemedi.');
    }
  }

  /// Bekleyen resim önizlemesini kaldırır.
  void clearImage() => state = state.copyWith(clearImage: true);

  /// Bekleyen dosya önizlemesini kaldırır.
  void clearFile() => state = state.copyWith(clearFile: true);

  /// Kullanıcı metnini kaydeder ve modeli akışla çağırır.
  Future<void> sendMessage(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.isSending) return;
    await stopListening();
    final settings = ref.read(settingsControllerProvider);
    final image = state.image;
    final file = state.file;
    final now = DateTime.now();
    final existing = state.activeSession;
    final session =
        existing ??
        ChatSession(
          id: const Uuid().v4(),
          title: shortTitleFrom(text),
          createdAt: now,
          messages: const [],
          profileId: settings.activeProfileId,
          repoUrl: state.draftRepoUrl,
        );
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.user,
      textContent: text,
      timestamp: now,
      imagePath: image?.path,
      filePath: file?.path,
      fileName: file?.name,
      fileContext: file?.extractedText,
    );
    final withUser = session.copyWith(
      title: session.messages.isEmpty ? shortTitleFrom(text) : session.title,
      profileId: session.profileId ?? settings.activeProfileId,
      messages: [...session.messages, userMessage],
    );
    state = state.copyWith(
      sessions: _upsert(withUser),
      activeSessionId: withUser.id,
      clearImage: true,
      clearFile: true,
      clearDictation: true,
      clearNotice: true,
    );
    await _database.saveSession(withUser);
    await _streamInto(withUser);
  }

  /// Son hata veya AI cevabını silip aynı kullanıcı mesajını yeniden yollar.
  Future<void> retry() async {
    final session = state.activeSession;
    if (session == null) return;
    _cancel?.cancel();
    _generation++;
    final messages = [...session.messages];
    final profile = ref
        .read(settingsControllerProvider)
        .profileById(session.profileId);
    if (profile != null && isCursorProfile(profile)) {
      while (messages.isNotEmpty && messages.last.role != MessageRole.user) {
        messages.removeLast();
      }
    } else {
      if (messages.isNotEmpty && messages.last.role == MessageRole.error) {
        messages.removeLast();
      }
      if (messages.isNotEmpty && messages.last.role == MessageRole.ai) {
        messages.removeLast();
      }
    }
    if (messages.isEmpty || messages.last.role != MessageRole.user) return;
    final updated = session.copyWith(messages: messages);
    state = state.copyWith(
      sessions: _upsert(updated),
      isSending: false,
      isStreaming: false,
      clearSendingSession: true,
    );
    await _database.saveSession(updated);
    await _streamInto(updated);
  }

  /// Son model cevabını yeniden üretir.
  Future<void> regenerate() => retry();

  /// Mikrofonu açar ve duyulan metni yazı alanına işler.
  Future<void> startListening() async {
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    try {
      state = state.copyWith(isListening: true, clearNotice: true);
      await _voice.listen(
        device: device,
        onText: (text) => state = state.copyWith(dictation: text),
        onListening: (listening) {
          if (state.isListening == listening) return;
          state = state.copyWith(isListening: listening);
        },
      );
    } on VoiceException catch (error) {
      state = state.copyWith(isListening: false, notice: error.message);
    } catch (_) {
      state = state.copyWith(
        isListening: false,
        notice: 'Mikrofon kullanılamıyor.',
      );
    }
  }

  /// Dinlemeyi kapatır.
  Future<void> stopListening() async {
    await _voice.stopListening();
    if (state.isListening) {
      state = state.copyWith(isListening: false);
    }
  }

  /// AI mesajını sesli okur veya durdurur.
  Future<void> toggleSpeak(String messageId) async {
    final session = state.activeSession;
    if (session == null) return;
    ChatMessage? message;
    for (final item in session.messages) {
      if (item.id == messageId) message = item;
    }
    if (message == null || message.textContent.trim().isEmpty) return;
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    try {
      await _voice.toggleSpeak(
        messageId: messageId,
        text: message.textContent,
        device: device,
        onState: (id) {
          state = state.copyWith(
            speakingMessageId: id,
            clearSpeaking: id == null,
          );
        },
      );
    } catch (_) {
      _notice('Sesli okuma başlatılamadı.');
    }
  }

  /// Açık sohbeti .txt olarak kaydedip paylaşır.
  Future<void> exportActive() async {
    final session = state.activeSession;
    if (session == null || session.messages.isEmpty) {
      _notice('Dışa aktarılacak mesaj yok.');
      return;
    }
    try {
      await exportAndShareSession(session);
    } catch (_) {
      _notice('Sohbet dışa aktarılamadı.');
    }
  }

  /// Model cevabını parça parça oturuma yazar.
  Future<void> _streamInto(ChatSession session) async {
    _cancel?.cancel();
    final generation = ++_generation;
    final cancel = CancelToken();
    _cancel = cancel;
    _streamBuffer = '';
    _streamMessageId = null;
    var chunks = 0;
    state = state.copyWith(
      isSending: true,
      sendingSessionId: session.id,
      isStreaming: false,
      clearStreamingMessage: true,
      activeSessionId: state.activeSessionId ?? session.id,
    );

    try {
      final profile =
          ref.read(settingsControllerProvider).profileById(session.profileId) ??
          ref.read(settingsControllerProvider).active;
      if (isCursorProfile(profile)) {
        await _streamCursor(
          session: session,
          profile: profile,
          generation: generation,
          cancel: cancel,
        );
        return;
      }
      await for (final piece in _api.streamChat(
        history: session.messages,
        profileId: session.profileId,
        cancelToken: cancel,
      )) {
        if (generation != _generation) return;
        _streamBuffer = mergeStreamPiece(_streamBuffer, piece);
        if (_streamBuffer.isEmpty) continue;
        if (_streamMessageId == null) {
          _streamMessageId = const Uuid().v4();
          final ai = ChatMessage(
            id: _streamMessageId!,
            role: MessageRole.ai,
            textContent: _streamBuffer,
            timestamp: DateTime.now(),
          );
          final current = _sessionById(session.id) ?? session;
          final updated = current.copyWith(messages: [...current.messages, ai]);
          state = state.copyWith(
            sessions: _upsert(updated),
            isStreaming: true,
            streamingMessageId: ai.id,
          );
        } else {
          _replaceMessage(session.id, _streamMessageId!, _streamBuffer);
        }
        chunks++;
        if (chunks % 8 == 0) {
          final latest = _sessionById(session.id);
          if (latest != null) await _database.saveSession(latest);
        }
      }
      if (generation != _generation) return;
      if (_streamBuffer.trim().isEmpty) {
        _appendError(session.id, 'API cevabı boş.');
      }
      final latest = _sessionById(session.id);
      if (latest != null) {
        await _database.saveSession(latest);
        final userCount = latest.messages
            .where((message) => message.role == MessageRole.user)
            .length;
        if (!latest.titleGenerated &&
            userCount == 1 &&
            _streamBuffer.trim().isNotEmpty) {
          final seed = latest.messages
              .firstWhere((message) => message.role == MessageRole.user)
              .textContent;
          unawaited(_generateTitle(latest.id, seed, latest.profileId));
        }
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || generation != _generation) return;
      _appendError(session.id, 'Yanıt alınamadı. Yeniden dene.');
      await _persist(session.id);
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _appendError(session.id, error.message);
      await _persist(session.id);
    } catch (_) {
      if (generation != _generation) return;
      _appendError(session.id, 'Yanıt alınamadı. Yeniden dene.');
      await _persist(session.id);
    } finally {
      if (generation == _generation) {
        state = state.copyWith(
          isSending: false,
          isStreaming: false,
          clearSendingSession: true,
          clearStreamingMessage: true,
        );
      }
    }
  }

  /// İlk mesajdan gizli bir başlık isteği yollar.
  Future<void> _generateTitle(
    String sessionId,
    String seed,
    String? profileId,
  ) async {
    try {
      final raw = await _api.requestTitle(seed: seed, profileId: profileId);
      final current = _sessionById(sessionId);
      if (current == null || current.titleGenerated) return;
      final updated = current.copyWith(
        title: cleanGeneratedTitle(raw),
        titleGenerated: true,
      );
      state = state.copyWith(sessions: _upsert(updated));
      await _database.saveSession(updated);
    } catch (_) {
      final current = _sessionById(sessionId);
      if (current == null || current.titleGenerated) return;
      final updated = current.copyWith(titleGenerated: true);
      state = state.copyWith(sessions: _upsert(updated));
      await _database.saveSession(updated);
    }
  }

  /// Akıştaki AI balonunun metnini günceller.
  void _replaceMessage(String sessionId, String messageId, String text) {
    final session = _sessionById(sessionId);
    if (session == null) return;
    final updated = session.copyWith(
      messages: [
        for (final message in session.messages)
          if (message.id == messageId)
            message.copyWith(textContent: text)
          else
            message,
      ],
    );
    state = state.copyWith(sessions: _upsert(updated), isStreaming: true);
  }

  /// Kırmızı hata balonunu oturumun sonuna ekler.
  void _appendError(String sessionId, String text) {
    final session = _sessionById(sessionId);
    if (session == null) return;
    final error = ChatMessage(
      id: const Uuid().v4(),
      role: MessageRole.error,
      textContent: text,
      timestamp: DateTime.now(),
    );
    final updated = session.copyWith(messages: [...session.messages, error]);
    state = state.copyWith(sessions: _upsert(updated));
  }

  /// Kimliğiyle oturumu bulur.
  ChatSession? _sessionById(String id) {
    for (final session in state.sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// Oturumu listeye yerleştirip yeniden sıralar.
  List<ChatSession> _upsert(ChatSession session) {
    final next = [
      for (final item in state.sessions)
        if (item.id != session.id) item,
      session,
    ];
    next.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return next;
  }

  /// Varsa oturumu diske yazar.
  Future<void> _persist(String id) async {
    final latest = _sessionById(id);
    if (latest != null) await _database.saveSession(latest);
  }

  /// Bu sohbetin kullanacağı depo adresini kaydeder.
  Future<void> setRepoUrl(String? url) async {
    final cleaned = url?.trim();
    final value = cleaned == null || cleaned.isEmpty ? null : cleaned;
    final session = state.activeSession;
    state = state.copyWith(draftRepoUrl: value, clearDraftRepo: value == null);
    if (session == null) return;
    final updated = session.copyWith(
      repoUrl: value,
      clearRepoUrl: value == null,
    );
    state = state.copyWith(sessions: _upsert(updated));
    await _database.saveSession(updated);
  }

  /// Cursor ajanını açar veya takip eder, sonra SSE olaylarını ekrana yazar.
  Future<void> _streamCursor({
    required ChatSession session,
    required ApiProfile profile,
    required int generation,
    required CancelToken cancel,
  }) async {
    final prompt = _lastUserText(session);
    if (prompt.isEmpty) {
      _appendError(session.id, 'Gönderilecek mesaj yok.');
      await _persist(session.id);
      return;
    }
    final launch = session.agentId == null
        ? await _cursor.createAgent(
            profile: profile,
            text: prompt,
            repoUrl: session.repoUrl,
            cancelToken: cancel,
          )
        : await _cursor.createRun(
            profile: profile,
            agentId: session.agentId!,
            text: prompt,
            cancelToken: cancel,
          );
    if (generation != _generation) return;
    var current = _sessionById(session.id) ?? session;
    final named =
        launch.name != null &&
        launch.name!.trim().isNotEmpty &&
        !current.titleGenerated;
    current = current.copyWith(
      agentId: launch.agentId,
      runId: launch.runId,
      title: named ? launch.name!.trim() : current.title,
      titleGenerated: named || current.titleGenerated,
    );
    state = state.copyWith(sessions: _upsert(current), isStreaming: true);
    await _database.saveSession(current);

    String? thinkingId;
    String? assistantId;
    var assistantText = '';
    var thinkingText = '';
    var chunks = 0;
    await for (final event in _cursor.streamRun(
      profile: profile,
      agentId: launch.agentId,
      runId: launch.runId,
      cancelToken: cancel,
    )) {
      if (generation != _generation) return;
      switch (event.name) {
        case 'thinking':
          final piece = event.data['text'];
          if (piece is! String || piece.isEmpty) break;
          thinkingText = _appendDelta(
            currentId: thinkingId,
            lastRole: MessageRole.thinking,
            sessionId: session.id,
            buffer: thinkingText,
            piece: piece,
          );
          thinkingId = _ensureRoleMessage(
            sessionId: session.id,
            messageId: thinkingId,
            role: MessageRole.thinking,
            text: thinkingText,
          );
        case 'assistant':
          final piece = event.data['text'];
          if (piece is! String || piece.isEmpty) break;
          thinkingId = null;
          thinkingText = '';
          assistantText += piece;
          assistantId = _ensureRoleMessage(
            sessionId: session.id,
            messageId: assistantId,
            role: MessageRole.ai,
            text: assistantText,
          );
        case 'tool_call':
          thinkingId = null;
          thinkingText = '';
          _upsertTool(session.id, event);
        case 'result':
          final text = event.data['text'];
          if (text is String && text.trim().isNotEmpty) {
            assistantText = text;
            assistantId = _ensureRoleMessage(
              sessionId: session.id,
              messageId: assistantId,
              role: MessageRole.ai,
              text: assistantText,
            );
          }
        case 'error':
          final message = event.data['message'];
          final code = event.data['code'];
          final detail = message is String && message.trim().isNotEmpty
              ? message.trim()
              : 'Cursor akışı hata verdi.';
          _appendError(session.id, code == null ? detail : '$detail ($code)');
        case 'heartbeat':
        case 'status':
        case 'interaction_update':
        case 'done':
          break;
        default:
          break;
      }
      chunks++;
      if (chunks % 8 == 0) await _persist(session.id);
    }
    if (generation != _generation) return;
    final latest = _sessionById(session.id);
    if (latest != null && !_hasCursorOutput(latest)) {
      _appendError(session.id, 'API cevabı boş.');
    }
    await _persist(session.id);
  }

  /// Son kullanıcı mesajından sonra düşünme, araç veya cevap olup olmadığına bakar.
  bool _hasCursorOutput(ChatSession session) {
    var start = session.messages.length;
    for (var index = session.messages.length - 1; index >= 0; index--) {
      if (session.messages[index].role == MessageRole.user) {
        start = index + 1;
        break;
      }
    }
    for (final message in session.messages.skip(start)) {
      if (message.role == MessageRole.ai ||
          message.role == MessageRole.thinking ||
          message.role == MessageRole.tool) {
        return true;
      }
    }
    return false;
  }

  /// Düşünme metnini, araya başka bir balon girdiyse sıfırdan biriktirir.
  String _appendDelta({
    required String? currentId,
    required MessageRole lastRole,
    required String sessionId,
    required String buffer,
    required String piece,
  }) {
    final session = _sessionById(sessionId);
    final last = session == null || session.messages.isEmpty
        ? null
        : session.messages.last;
    if (currentId == null ||
        last == null ||
        last.id != currentId ||
        last.role != lastRole) {
      return piece;
    }
    return buffer + piece;
  }

  /// Yoksa balon açar, varsa metnini günceller. Balon kimliğini döndürür.
  String _ensureRoleMessage({
    required String sessionId,
    required String? messageId,
    required MessageRole role,
    required String text,
  }) {
    final session = _sessionById(sessionId);
    if (session == null) return messageId ?? const Uuid().v4();
    if (messageId != null &&
        session.messages.any((message) => message.id == messageId)) {
      _replaceMessage(sessionId, messageId, text);
      return messageId;
    }
    final id = const Uuid().v4();
    final message = ChatMessage(
      id: id,
      role: role,
      textContent: text,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      sessions: _upsert(
        session.copyWith(messages: [...session.messages, message]),
      ),
      isStreaming: true,
      streamingMessageId: id,
    );
    return id;
  }

  /// Aynı callId için araç çipini ekler veya durumunu günceller.
  void _upsertTool(String sessionId, CursorSseEvent event) {
    final callId = event.data['callId'];
    final name = event.data['name'];
    final status = event.data['status'];
    if (callId is! String || name is! String) return;
    final toolStatus = status is String ? status : 'running';
    final label = toolChipLabel(name, toolStatus);
    final session = _sessionById(sessionId);
    if (session == null) return;
    final existing = session.messages.where(
      (message) => message.toolCallId == callId,
    );
    if (existing.isEmpty) {
      final message = ChatMessage(
        id: const Uuid().v4(),
        role: MessageRole.tool,
        textContent: label,
        timestamp: DateTime.now(),
        toolCallId: callId,
        toolName: name,
        toolStatus: toolStatus,
      );
      state = state.copyWith(
        sessions: _upsert(
          session.copyWith(messages: [...session.messages, message]),
        ),
        isStreaming: true,
      );
      return;
    }
    state = state.copyWith(
      sessions: _upsert(
        session.copyWith(
          messages: [
            for (final message in session.messages)
              if (message.toolCallId == callId)
                message.copyWith(textContent: label, toolStatus: toolStatus)
              else
                message,
          ],
        ),
      ),
      isStreaming: true,
    );
  }

  String _lastUserText(ChatSession session) {
    for (final message in session.messages.reversed) {
      if (message.role == MessageRole.user) return message.textContent;
    }
    return '';
  }

  /// Snackbar ile gösterilecek kısa uyarıyı ayarlar.
  void _notice(String message) {
    state = state.copyWith(notice: message);
  }

  LocalDatabase get _database => ref.read(localDatabaseProvider);

  ApiService get _api => ref.read(apiServiceProvider);

  CursorAgentService get _cursor => ref.read(cursorAgentServiceProvider);

  VoiceService get _voice => ref.read(voiceServiceProvider);
}

/// Sohbet denetleyicisi.
final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
