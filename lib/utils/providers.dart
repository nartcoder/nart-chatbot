import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/services/api_service.dart';
import 'package:nart_chat/services/cursor_agent_service.dart';
import 'package:nart_chat/services/local_database.dart';
import 'package:nart_chat/services/voice_service.dart';

/// Uygulama açılışında doldurulan yerel veritabanı.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw StateError('LocalDatabase başlatılmadan kullanılamaz.');
});

/// HTTP istemcisi.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));
  ref.onDispose(dio.close);
  return dio;
});

/// Uç nokta çağrıları.
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider), ref.watch(localDatabaseProvider));
});

/// Cursor Cloud Agents çağrıları.
final cursorAgentServiceProvider = Provider<CursorAgentService>((ref) {
  return CursorAgentService(ref.watch(dioProvider));
});

/// Mikrofon ve sesli okuma.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});
