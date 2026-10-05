import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/services/api_exception.dart';
import 'package:nart_chat/services/attachment_store.dart';
import 'package:nart_chat/services/chat_payload.dart';
import 'package:nart_chat/services/local_database.dart';
import 'package:nart_chat/utils/endpoint.dart';
import 'package:nart_chat/utils/response_parser.dart';
import 'package:nart_chat/utils/sse_buffer.dart';
import 'package:path/path.dart' as p;

/// Ayarlardaki profile göre sohbet isteği atan ve akan cevabı üreten servis.
class ApiService {
  ApiService(this._dio, this._database);

  final Dio _dio;
  final LocalDatabase _database;

  /// Sohbet geçmişini uç noktaya gönderir ve metin parçalarını yayar.
  Stream<String> streamChat({
    required List<ChatMessage> history,
    String? profileId,
    CancelToken? cancelToken,
  }) async* {
    final settings = _database.readSettings();
    final profile = settings.profileById(profileId) ?? settings.active;
    _ensureEndpoint(profile);
    final media = await _latestMedia(history);
    final useMultipart = shouldUseMultipart(
      payloadType: settings.payloadType,
      hasImage: media.imageBytes != null,
      hasFile: media.fileBytes != null,
    );
    final payload = buildChatPayload(
      history: history,
      profile: profile,
      settings: settings,
      imageBase64: media.imageBytes == null
          ? null
          : base64Encode(media.imageBytes!),
      imageMime: media.imageMime,
      fileBase64: media.fileBytes == null
          ? null
          : base64Encode(media.fileBytes!),
      fileName: media.fileName,
      stream: true,
    );
    final data = useMultipart ? _multipart(payload, media) : payload;
    yield* _send(
      profile: profile,
      data: data,
      cancelToken: cancelToken,
      jsonBody: !useMultipart,
    );
  }

  /// Sohbet balonuna yazmadan, kısa bir başlık ister.
  Future<String> requestTitle({
    required String seed,
    String? profileId,
    CancelToken? cancelToken,
  }) async {
    final settings = _database.readSettings();
    final profile = settings.profileById(profileId) ?? settings.active;
    _ensureEndpoint(profile);
    final payload = <String, dynamic>{
      'stream': false,
      'messages': [
        {
          'role': 'user',
          'content':
              'Aşağıdaki mesaja yalnızca 2 veya 3 kelimelik kısa bir başlık yaz.\n\n$seed',
        },
      ],
    };
    final model = profile.modelName.trim();
    if (model.isNotEmpty) payload['model'] = model;
    final buffer = StringBuffer();
    await for (final piece in _send(
      profile: profile,
      data: payload,
      cancelToken: cancelToken,
      jsonBody: true,
    )) {
      buffer.write(piece);
    }
    return buffer.toString();
  }

  /// Adres boşsa veya şema geçersizse isteği başlatmaz.
  void _ensureEndpoint(ApiProfile profile) {
    final endpoint = resolveChatEndpoint(profile.endpoint);
    if (endpoint.isEmpty) {
      throw ApiException(
        'Özel API endpoint tanımlı değil. Ayarlar ekranından ekle.',
      );
    }
    if (!isHttpUrl(endpoint)) {
      throw ApiException(
        'Endpoint adresi geçerli bir http veya https URL değil.',
      );
    }
  }

  /// JSON veya form-data gövdesini yollar, SSE ya da tek JSON cevabı parçalara böler.
  Stream<String> _send({
    required ApiProfile profile,
    required Object data,
    required bool jsonBody,
    CancelToken? cancelToken,
  }) async* {
    final endpoint = resolveChatEndpoint(profile.endpoint);
    final headers = <String, dynamic>{
      'Accept': 'text/event-stream, application/json',
      if (profile.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${profile.apiKey.trim()}',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    _logRequest(endpoint: endpoint, headers: headers, data: data);
    try {
      final response = await _dio.post<ResponseBody>(
        endpoint,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (code) => true,
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final code = response.statusCode ?? 0;
      final body = response.data;
      if (body == null) {
        throw ApiException('API cevabı boş.');
      }
      if (code < 200 || code >= 300) {
        final raw = await utf8.decodeStream(body.stream);
        throw _statusException(code, raw);
      }
      yield* _decodeBody(body);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiException(_dioMessage(error));
    }
  }

  /// Akış gövdesini metin parçalarına çevirir.
  Stream<String> _decodeBody(ResponseBody body) async* {
    final contentType =
        body.headers['content-type']?.join(';').toLowerCase() ?? '';
    final buffer = SseBuffer();
    final raw = StringBuffer();
    var emitted = false;
    await for (final chunk in utf8.decoder.bind(body.stream)) {
      raw.write(chunk);
      if (contentType.contains('json') &&
          !contentType.contains('event-stream')) {
        continue;
      }
      for (final piece in buffer.add(chunk)) {
        emitted = true;
        yield piece;
      }
    }
    if (!emitted &&
        contentType.contains('json') &&
        !contentType.contains('event-stream')) {
      final text = tryParseAssistantText(raw.toString());
      if (text == null || text.trim().isEmpty) {
        throw ApiException(
          tryParseErrorMessage(_tryJson(raw.toString())) ??
              'API cevabı okunamadı.',
        );
      }
      yield text;
      return;
    }
    for (final piece in buffer.flush()) {
      emitted = true;
      yield piece;
    }
    if (!emitted) {
      final fallback = tryParseAssistantText(raw.toString());
      if (fallback != null && fallback.trim().isNotEmpty) {
        yield fallback;
        return;
      }
      final plain = raw.toString().trim();
      if (plain.isNotEmpty &&
          !plain.startsWith('{') &&
          !plain.startsWith('[')) {
        yield plain;
        return;
      }
      throw ApiException('API cevabı okunamadı.');
    }
  }

  /// Son kullanıcı mesajındaki resim ve dosyayı okur.
  Future<_Media> _latestMedia(List<ChatMessage> history) async {
    ChatMessage? lastUser;
    for (final message in history) {
      if (message.role == MessageRole.user) lastUser = message;
    }
    if (lastUser == null) return const _Media();
    List<int>? imageBytes;
    String? imageMime;
    if (lastUser.imagePath != null) {
      imageBytes = await readFileBytes(lastUser.imagePath!);
      imageMime = _mime(lastUser.imagePath!);
    }
    List<int>? fileBytes;
    if (lastUser.filePath != null) {
      fileBytes = await readFileBytes(lastUser.filePath!);
    }
    return _Media(
      imageBytes: imageBytes,
      imageMime: imageMime,
      fileBytes: fileBytes,
      fileName:
          lastUser.fileName ??
          (lastUser.filePath == null ? null : p.basename(lastUser.filePath!)),
    );
  }

  /// Multipart gövdede metin alanlarını ve dosya parçalarını bir araya getirir.
  FormData _multipart(Map<String, dynamic> payload, _Media media) {
    final fields = <String, dynamic>{
      'message': _latestUserText(payload),
      'messages': jsonEncode(payload['messages']),
      'stream': true,
      if (payload['model'] != null) 'model': payload['model'],
      if (payload['temperature'] != null) 'temperature': payload['temperature'],
      if (payload['max_tokens'] != null) 'max_tokens': payload['max_tokens'],
      if (payload['top_p'] != null) 'top_p': payload['top_p'],
    };
    if (media.imageBytes != null) {
      fields['image'] = MultipartFile.fromBytes(
        media.imageBytes!,
        filename: 'image.jpg',
      );
    }
    if (media.fileBytes != null) {
      fields['file'] = MultipartFile.fromBytes(
        media.fileBytes!,
        filename: media.fileName ?? 'dosya',
      );
    }
    return FormData.fromMap(fields);
  }

  String _latestUserText(Map<String, dynamic> payload) {
    final messages = payload['messages'];
    if (messages is! List || messages.isEmpty) return '';
    for (final message in messages.reversed) {
      if (message is Map && message['role'] == 'user') {
        final content = message['content'];
        if (content is String) return content;
        if (content is List) {
          for (final part in content) {
            if (part is Map &&
                part['type'] == 'text' &&
                part['text'] is String) {
              return part['text'] as String;
            }
          }
        }
      }
    }
    return '';
  }

  /// İstek gitmeden URL, başlık ve gövdeyi konsola yazar.
  void _logRequest({
    required String endpoint,
    required Map<String, dynamic> headers,
    required Object data,
  }) {
    final safeHeaders = <String, dynamic>{
      for (final entry in headers.entries)
        entry.key: _redactHeader(entry.key, '${entry.value}'),
    };
    _debugBlock(
      '[ApiService] İstek\n'
      'URL: $endpoint\n'
      'Headers: ${const JsonEncoder.withIndent('  ').convert(safeHeaders)}\n'
      'Body:\n${_bodyForLog(data)}',
    );
  }

  /// Uzun konsol satırlarını parçalayarak debugPrint sınırına takılmadan yazar.
  void _debugBlock(String text) {
    const size = 800;
    for (var start = 0; start < text.length; start += size) {
      final end = start + size > text.length ? text.length : start + size;
      debugPrint(text.substring(start, end));
    }
  }

  String _bodyForLog(Object data) {
    if (data is Map) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    if (data is FormData) {
      final parts = [
        for (final field in data.fields) '${field.key}=${field.value}',
        for (final file in data.files)
          '${file.key}=<dosya ${file.value.filename ?? ''}>',
      ];
      return 'multipart\n${parts.join('\n')}';
    }
    return data.toString();
  }

  String _redactHeader(String name, String value) {
    if (name.toLowerCase() != 'authorization') return value;
    final token = value.replaceFirst(RegExp(r'^Bearer\s+'), '');
    if (token.length <= 4) return 'Bearer ••••';
    return 'Bearer ••••${token.substring(token.length - 4)}';
  }

  /// HTTP kodunu ve API gövdesinin orijinal metnini hata balonuna taşır.
  ApiException _statusException(int code, String raw) {
    final body = raw.trim().isEmpty ? '(boş gövde)' : raw.trim();
    final shown = body.length > 4000 ? '${body.substring(0, 4000)}\n…' : body;
    _debugBlock('[ApiService] Hata HTTP $code\n$shown');
    return ApiException('HTTP $code\n$shown');
  }

  String _dioMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'İstek zaman aşımına uğradı. Yeniden dene.';
      case DioExceptionType.connectionError:
        return 'Bağlantı kurulamadı. İnternetini kontrol edip yeniden dene.';
      default:
        final code = error.response?.statusCode;
        final raw = error.response?.data;
        if (code != null) {
          final body = raw == null ? '(boş gövde)' : '$raw'.trim();
          return 'HTTP $code\n${body.isEmpty ? '(boş gövde)' : body}';
        }
        return 'Yanıt alınamadı. Yeniden dene.';
    }
  }

  dynamic _tryJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _mime(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

class _Media {
  const _Media({
    this.imageBytes,
    this.imageMime,
    this.fileBytes,
    this.fileName,
  });

  final List<int>? imageBytes;
  final String? imageMime;
  final List<int>? fileBytes;
  final String? fileName;
}
