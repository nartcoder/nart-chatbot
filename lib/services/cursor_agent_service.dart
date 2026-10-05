import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/services/api_exception.dart';
import 'package:nart_chat/utils/cursor_sse.dart';

/// Yeni ajan veya takip çalışmasının kimlikleri.
class CursorLaunch {
  const CursorLaunch({required this.agentId, required this.runId, this.name});

  final String agentId;
  final String runId;
  final String? name;
}

/// Cursor Cloud Agents API v1 çağrıları.
class CursorAgentService {
  CursorAgentService(this._dio);

  final Dio _dio;

  /// İlk mesajla ajan açar ve ilk çalıştırmanın kimliğini döndürür.
  Future<CursorLaunch> createAgent({
    required ApiProfile profile,
    required String text,
    String? repoUrl,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'prompt': {'text': text},
      if (repoUrl != null && repoUrl.trim().isNotEmpty)
        'repos': [
          {'url': repoUrl.trim()},
        ],
    };
    final model = profile.modelName.trim();
    if (model.isNotEmpty && model != 'composer-2') {
      body['model'] = {'id': model};
    }
    final data = await _postJson(
      profile: profile,
      path: '/v1/agents',
      body: body,
      cancelToken: cancelToken,
    );
    final agent = data['agent'];
    final run = data['run'];
    final agentId = agent is Map ? agent['id'] : null;
    final runId = run is Map
        ? run['id']
        : (agent is Map ? agent['latestRunId'] : null);
    if (agentId is! String ||
        agentId.isEmpty ||
        runId is! String ||
        runId.isEmpty) {
      throw ApiException('Cursor ajan kimliği okunamadı.');
    }
    final name = agent is Map && agent['name'] is String
        ? agent['name'] as String
        : null;
    return CursorLaunch(agentId: agentId, runId: runId, name: name);
  }

  /// Aynı ajana yeni bir takip mesajı yollar.
  Future<CursorLaunch> createRun({
    required ApiProfile profile,
    required String agentId,
    required String text,
    CancelToken? cancelToken,
  }) async {
    final data = await _postJson(
      profile: profile,
      path: '/v1/agents/$agentId/runs',
      body: {
        'prompt': {'text': text},
      },
      cancelToken: cancelToken,
    );
    final run = data['run'];
    final runId = run is Map ? run['id'] : null;
    if (runId is! String || runId.isEmpty) {
      throw ApiException('Cursor çalıştırma kimliği okunamadı.');
    }
    return CursorLaunch(agentId: agentId, runId: runId);
  }

  /// Çalıştırmanın SSE akışını olay olay üretir.
  Stream<CursorSseEvent> streamRun({
    required ApiProfile profile,
    required String agentId,
    required String runId,
    CancelToken? cancelToken,
  }) async* {
    final key = _requireKey(profile);
    final response = await _dio.get<ResponseBody>(
      '${_root(profile.endpoint)}/v1/agents/$agentId/runs/$runId/stream',
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Authorization': cursorBasicHeader(key),
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
        validateStatus: (code) => true,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    final code = response.statusCode ?? 0;
    final body = response.data;
    if (body == null) throw ApiException('API cevabı boş.');
    if (code < 200 || code >= 300) {
      final raw = await utf8.decodeStream(body.stream);
      throw _httpError(code, raw);
    }
    final decoder = CursorSseDecoder();
    await for (final chunk in utf8.decoder.bind(body.stream)) {
      for (final event in decoder.add(chunk)) {
        yield event;
      }
    }
    for (final event in decoder.flush()) {
      yield event;
    }
  }

  /// Cursor'a bağlı GitHub depolarının adreslerini döndürür.
  Future<List<String>> listRepositories({
    required ApiProfile profile,
    CancelToken? cancelToken,
  }) async {
    final key = _requireKey(profile);
    final response = await _dio.get<dynamic>(
      '${_root(profile.endpoint)}/v1/repositories',
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Authorization': cursorBasicHeader(key),
          'Accept': 'application/json',
        },
        validateStatus: (code) => true,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw _httpError(code, '${response.data ?? ''}');
    }
    final data = response.data;
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map &&
            item['url'] is String &&
            (item['url'] as String).trim().isNotEmpty)
          (item['url'] as String).trim(),
    ];
  }

  Future<Map<String, dynamic>> _postJson({
    required ApiProfile profile,
    required String path,
    required Map<String, dynamic> body,
    CancelToken? cancelToken,
  }) async {
    final key = _requireKey(profile);
    final response = await _dio.post<dynamic>(
      '${_root(profile.endpoint)}$path',
      data: body,
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Authorization': cursorBasicHeader(key),
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (code) => true,
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final code = response.statusCode ?? 0;
    final data = response.data;
    if (code < 200 || code >= 300) {
      throw _httpError(code, data is String ? data : jsonEncode(data));
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Cursor cevabı okunamadı.');
  }

  String _requireKey(ApiProfile profile) {
    final key = profile.apiKey.trim();
    if (key.isEmpty) {
      throw ApiException(
        'Cursor API anahtarı yok. Ayarlardan Cursor Cloud Agent profiline ekle.',
      );
    }
    return key;
  }

  /// `https://api.cursor.com/v1` adresini kök sunucuya indirir.
  String _root(String endpoint) {
    var value = endpoint.trim();
    if (value.endsWith('/')) value = value.substring(0, value.length - 1);
    if (value.endsWith('/v1')) {
      return value.substring(0, value.length - 3);
    }
    return value;
  }

  ApiException _httpError(int code, String raw) {
    final body = raw.trim().isEmpty ? '(boş gövde)' : raw.trim();
    final shown = body.length > 4000 ? '${body.substring(0, 4000)}\n…' : body;
    return ApiException('HTTP $code\n$shown');
  }
}

/// `curl -u API_KEY:` ile aynı Basic başlığı üretir.
String cursorBasicHeader(String apiKey) {
  return 'Basic ${base64Encode(utf8.encode('$apiKey:'))}';
}
