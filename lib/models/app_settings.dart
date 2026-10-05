import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/models/payload_type.dart';

/// Yerel ayar kutusunun tamamı.
class AppSettings {
  const AppSettings({
    required this.profiles,
    required this.activeProfileId,
    required this.payloadType,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.topP,
    required this.sendFullHistory,
    this.savedRepos = const [],
  });

  final List<ApiProfile> profiles;
  final String activeProfileId;
  final PayloadType payloadType;
  final String systemPrompt;
  final double? temperature;
  final int? maxTokens;
  final double? topP;
  final bool sendFullHistory;
  final List<String> savedRepos;

  /// Seçili profili döndürür; yoksa listedeki ilk profili kullanır.
  ApiProfile get active {
    return profileById(activeProfileId) ?? profiles.first;
  }

  /// Kimliğe göre profil arar.
  ApiProfile? profileById(String? id) {
    if (id == null) return null;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Ayarların bir bölümünü değiştiren kopya üretir.
  AppSettings copyWith({
    List<ApiProfile>? profiles,
    String? activeProfileId,
    PayloadType? payloadType,
    String? systemPrompt,
    double? temperature,
    bool clearTemperature = false,
    int? maxTokens,
    bool clearMaxTokens = false,
    double? topP,
    bool clearTopP = false,
    bool? sendFullHistory,
    List<String>? savedRepos,
  }) {
    return AppSettings(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      payloadType: payloadType ?? this.payloadType,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
      maxTokens: clearMaxTokens ? null : (maxTokens ?? this.maxTokens),
      topP: clearTopP ? null : (topP ?? this.topP),
      sendFullHistory: sendFullHistory ?? this.sendFullHistory,
      savedRepos: savedRepos ?? this.savedRepos,
    );
  }

  /// İlk açılışta kullanılan boş profil ve limitsiz parametreler.
  factory AppSettings.initial() {
    return const AppSettings(
      profiles: [
        ApiProfile(
          id: 'default',
          name: 'Varsayılan',
          endpoint: '',
          apiKey: '',
          modelName: '',
        ),
        cursorCloudProfile,
      ],
      activeProfileId: cursorCloudProfileId,
      payloadType: PayloadType.base64,
      systemPrompt: '',
      temperature: null,
      maxTokens: null,
      topP: null,
      sendFullHistory: true,
    );
  }
}
