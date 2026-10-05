import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/app_settings.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/models/payload_type.dart';
import 'package:nart_chat/services/hive_adapters.dart';
import 'package:nart_chat/utils/storage_keys.dart';

/// Sohbet oturumlarını ve ayarları Hive kutularında tutar.
class LocalDatabase {
  Box<ChatSession>? _sessions;
  Box<dynamic>? _settings;

  /// Kutuları açar ve eksik ayar anahtarlarını varsayılanla doldurur.
  Future<void> init({String? directoryPath}) async {
    if (directoryPath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directoryPath);
    }
    _registerAdapters();
    _sessions = await Hive.openBox<ChatSession>(StorageKeys.sessionsBox);
    _settings = await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await _ensureSettings();
  }

  /// Kayıtlı sohbetleri son hareket zamanına göre sıralar.
  List<ChatSession> loadSessions() {
    final sessions = _sessionBox.values.toList();
    sessions.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return sessions;
  }

  /// Oturumu kimliğiyle kutuya yazar.
  Future<void> saveSession(ChatSession session) async {
    await _sessionBox.put(session.id, session);
  }

  /// Oturumu kutudan siler.
  Future<void> deleteSession(String id) async {
    await _sessionBox.delete(id);
  }

  /// Ayar kutusunu modele çevirir.
  AppSettings readSettings() {
    final box = _settingsBox;
    final profiles = _readProfiles(box);
    final activeId =
        box.get(StorageKeys.activeProfileId) as String? ?? profiles.first.id;
    final resolvedId = profiles.any((profile) => profile.id == activeId)
        ? activeId
        : profiles.first.id;
    return AppSettings(
      profiles: profiles,
      activeProfileId: resolvedId,
      payloadType: PayloadType.fromStorage(
        box.get(StorageKeys.payloadType) as String?,
      ),
      systemPrompt: box.get(StorageKeys.systemPrompt) as String? ?? '',
      temperature: _readDouble(box.get(StorageKeys.temperature)),
      maxTokens: _readInt(box.get(StorageKeys.maxTokens)),
      topP: _readDouble(box.get(StorageKeys.topP)),
      sendFullHistory: box.get(StorageKeys.sendFullHistory) as bool? ?? true,
      savedRepos: _readRepos(box.get(StorageKeys.savedRepos)),
    );
  }

  /// Ayarları kutuya yazar ve etkin profili eski anahtarlara da yansıtır.
  Future<void> writeSettings(AppSettings settings) async {
    final box = _settingsBox;
    final profiles = settings.profiles.isEmpty
        ? AppSettings.initial().profiles
        : settings.profiles;
    final active =
        profiles.any((profile) => profile.id == settings.activeProfileId)
        ? settings.activeProfileId
        : profiles.first.id;
    final activeProfile = profiles.firstWhere(
      (profile) => profile.id == active,
    );
    await box.put(
      StorageKeys.apiProfiles,
      jsonEncode([for (final profile in profiles) profile.toJson()]),
    );
    await box.put(StorageKeys.activeProfileId, active);
    await box.put(StorageKeys.apiKey, activeProfile.apiKey);
    await box.put(StorageKeys.customApiEndpoint, activeProfile.endpoint);
    await box.put(StorageKeys.payloadType, settings.payloadType.name);
    await box.put(StorageKeys.systemPrompt, settings.systemPrompt);
    await box.put(
      StorageKeys.temperature,
      settings.temperature?.toString() ?? '',
    );
    await box.put(StorageKeys.maxTokens, settings.maxTokens?.toString() ?? '');
    await box.put(StorageKeys.topP, settings.topP?.toString() ?? '');
    await box.put(StorageKeys.sendFullHistory, settings.sendFullHistory);
    await box.put(StorageKeys.savedRepos, jsonEncode(settings.savedRepos));
  }

  Box<ChatSession> get _sessionBox {
    final box = _sessions;
    if (box == null) {
      throw StateError('Yerel veritabanı başlatılmadı.');
    }
    return box;
  }

  Box<dynamic> get _settingsBox {
    final box = _settings;
    if (box == null) {
      throw StateError('Yerel veritabanı başlatılmadı.');
    }
    return box;
  }

  /// Adaptörleri bir kez kaydeder.
  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(HiveTypeIds.chatMessage)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.chatSession)) {
      Hive.registerAdapter(ChatSessionAdapter());
    }
  }

  /// İlk kurulumda boş anahtarları ve varsayılan profili oluşturur.
  Future<void> _ensureSettings() async {
    final box = _settingsBox;
    if (!box.containsKey(StorageKeys.apiKey)) {
      await box.put(StorageKeys.apiKey, '');
    }
    if (!box.containsKey(StorageKeys.customApiEndpoint)) {
      await box.put(StorageKeys.customApiEndpoint, '');
    }
    if (!box.containsKey(StorageKeys.apiProfiles)) {
      final profile = ApiProfile(
        id: 'default',
        name: 'Varsayılan',
        endpoint: box.get(StorageKeys.customApiEndpoint) as String? ?? '',
        apiKey: box.get(StorageKeys.apiKey) as String? ?? '',
        modelName: '',
      );
      await box.put(StorageKeys.apiProfiles, jsonEncode([profile.toJson()]));
      await box.put(StorageKeys.activeProfileId, profile.id);
    }
    if (!box.containsKey(StorageKeys.payloadType)) {
      await box.put(StorageKeys.payloadType, PayloadType.base64.name);
    }
    if (!box.containsKey(StorageKeys.systemPrompt)) {
      await box.put(StorageKeys.systemPrompt, '');
    }
    if (!box.containsKey(StorageKeys.temperature)) {
      await box.put(StorageKeys.temperature, '');
    }
    if (!box.containsKey(StorageKeys.maxTokens)) {
      await box.put(StorageKeys.maxTokens, '');
    }
    if (!box.containsKey(StorageKeys.topP)) {
      await box.put(StorageKeys.topP, '');
    }
    if (!box.containsKey(StorageKeys.sendFullHistory)) {
      await box.put(StorageKeys.sendFullHistory, true);
    }
    if (!box.containsKey(StorageKeys.savedRepos)) {
      await box.put(StorageKeys.savedRepos, '[]');
    }
    await _ensureCursorProfile(box);
  }

  /// Cursor profilini tamamlar. Kayıtlı API anahtarına dokunmaz.
  Future<void> _ensureCursorProfile(Box<dynamic> box) async {
    final current = _readProfiles(box);
    final hasCursor = current.any(
      (profile) => profile.id == cursorCloudProfileId,
    );
    final next = hasCursor
        ? [
            for (final profile in current)
              if (profile.id == cursorCloudProfileId)
                _completedCursorProfile(profile)
              else
                profile,
          ]
        : [...current, cursorCloudProfile];
    final changed =
        !hasCursor ||
        next.any((profile) {
          if (profile.id != cursorCloudProfileId) return false;
          final previous = current.cast<ApiProfile?>().firstWhere(
            (item) => item?.id == cursorCloudProfileId,
            orElse: () => null,
          );
          return previous?.endpoint != profile.endpoint ||
              previous?.modelName != profile.modelName ||
              previous?.name != profile.name;
        });
    if (changed) {
      await box.put(
        StorageKeys.apiProfiles,
        jsonEncode([for (final profile in next) profile.toJson()]),
      );
    }
    final activeId = box.get(StorageKeys.activeProfileId) as String?;
    final active = next.cast<ApiProfile?>().firstWhere(
      (profile) => profile?.id == activeId,
      orElse: () => null,
    );
    if (active == null || active.endpoint.trim().isEmpty) {
      await box.put(StorageKeys.activeProfileId, cursorCloudProfileId);
      final cursor = next.firstWhere(
        (profile) => profile.id == cursorCloudProfileId,
      );
      await box.put(StorageKeys.apiKey, cursor.apiKey);
      await box.put(StorageKeys.customApiEndpoint, cursor.endpoint);
    }
  }

  /// Boş adresi tamamlar. Geçersiz composer-2 kaydını siler.
  ApiProfile _completedCursorProfile(ApiProfile profile) {
    final model = profile.modelName.trim();
    return profile.copyWith(
      name: profile.name.trim().isEmpty
          ? cursorCloudProfile.name
          : profile.name,
      endpoint: profile.endpoint.trim().isEmpty
          ? cursorCloudEndpoint
          : profile.endpoint,
      modelName: model == 'composer-2' ? '' : model,
    );
  }

  List<String> _readRepos(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return [
            for (final item in decoded)
              if (item is String && item.trim().isNotEmpty) item.trim(),
          ];
        }
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  List<ApiProfile> _readProfiles(Box<dynamic> box) {
    final raw = box.get(StorageKeys.apiProfiles);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final profiles = [
            for (final item in decoded)
              if (item is Map) ApiProfile.fromJson(item),
          ].where((profile) => profile.id.isNotEmpty).toList();
          if (profiles.isNotEmpty) return profiles;
        }
      } catch (_) {
        // Bozuk kayıt varsayılan profile döner.
      }
    }
    return AppSettings.initial().profiles;
  }

  double? _readDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String && raw.trim().isNotEmpty) {
      return double.tryParse(raw.trim());
    }
    return null;
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String && raw.trim().isNotEmpty) return int.tryParse(raw.trim());
    return null;
  }
}
