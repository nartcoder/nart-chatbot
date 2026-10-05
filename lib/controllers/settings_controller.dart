import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/models/app_settings.dart';
import 'package:nart_chat/utils/providers.dart';

/// Ayarlar kutusunu okuyan ve yazan denetleyici.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return ref.read(localDatabaseProvider).readSettings();
  }

  /// Tüm ayar formunu kaydeder.
  Future<void> save(AppSettings settings) async {
    await ref.read(localDatabaseProvider).writeSettings(settings);
    state = ref.read(localDatabaseProvider).readSettings();
  }

  /// Etkin profili değiştirir ve apiKey / endpoint aynasını günceller.
  Future<void> setActiveProfile(String id) async {
    if (state.profileById(id) == null) return;
    await save(state.copyWith(activeProfileId: id));
  }

  /// Kayıtlı depo listesine yeni bir adres ekler.
  Future<void> addRepo(String url) async {
    final cleaned = url.trim();
    if (cleaned.isEmpty || state.savedRepos.contains(cleaned)) return;
    await save(state.copyWith(savedRepos: [...state.savedRepos, cleaned]));
  }

  /// Kayıtlı depo adresini listeden çıkarır.
  Future<void> removeRepo(String url) async {
    await save(
      state.copyWith(
        savedRepos: [
          for (final item in state.savedRepos)
            if (item != url) item,
        ],
      ),
    );
  }
}

/// Ayarlar denetleyicisi.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
