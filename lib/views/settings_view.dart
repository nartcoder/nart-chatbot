import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/settings_controller.dart';
import 'package:nart_chat/models/api_profile.dart';
import 'package:nart_chat/models/app_settings.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/models/payload_type.dart';
import 'package:nart_chat/utils/endpoint.dart';
import 'package:uuid/uuid.dart';

/// API profilleri, sistem istemi ve üretim parametreleri.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _system = TextEditingController();
  final TextEditingController _maxTokens = TextEditingController();
  var _ready = false;
  var _saving = false;
  var _obscure = true;
  var _useTemperature = false;
  var _temperature = 0.7;
  var _useTopP = false;
  var _topP = 1.0;
  var _fullHistory = true;
  var _payload = PayloadType.base64;
  String? _endpointError;
  String? _tokenError;
  List<ApiProfile> _profiles = [];
  String _activeId = 'default';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _load(ref.read(settingsControllerProvider));
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _apiKey.dispose();
    _model.dispose();
    _system.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  /// Kayıtlı ayarları forma basar.
  void _load(AppSettings settings) {
    _profiles = [...settings.profiles];
    _activeId = settings.activeProfileId;
    _payload = settings.payloadType;
    _system.text = settings.systemPrompt;
    _fullHistory = settings.sendFullHistory;
    _useTemperature = settings.temperature != null;
    _temperature = settings.temperature ?? 0.7;
    _useTopP = settings.topP != null;
    _topP = settings.topP ?? 1;
    _maxTokens.text = settings.maxTokens?.toString() ?? '';
    _fillProfile(_activeId);
  }

  /// Seçili profilin alanlarını kutulara yazar.
  void _fillProfile(String id) {
    final profile = _profiles.cast<ApiProfile?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => _profiles.isEmpty ? null : _profiles.first,
    );
    if (profile == null) return;
    _activeId = profile.id;
    _name.text = profile.name;
    _endpoint.text = profile.endpoint.trim().isEmpty && isCursorProfile(profile)
        ? cursorCloudEndpoint
        : profile.endpoint;
    _apiKey.text = profile.apiKey;
    final model = profile.modelName.trim();
    _model.text = model == 'composer-2' ? '' : model;
  }

  /// Formdaki profil alanlarını listeye geri yazar.
  void _stash() {
    final index = _profiles.indexWhere((profile) => profile.id == _activeId);
    if (index < 0) return;
    final name = _name.text.trim().isEmpty ? 'Profil' : _name.text.trim();
    _profiles[index] = _profiles[index].copyWith(
      name: name,
      endpoint: normalizeEndpoint(_endpoint.text),
      apiKey: _apiKey.text.trim(),
      modelName: _model.text.trim(),
    );
  }

  /// Yeni boş bir profil ekler.
  void _addProfile() {
    _stash();
    final profile = ApiProfile(
      id: const Uuid().v4(),
      name: 'Yeni profil',
      endpoint: '',
      apiKey: '',
      modelName: '',
    );
    setState(() {
      _profiles = [..._profiles, profile];
      _endpointError = null;
      _fillProfile(profile.id);
    });
  }

  /// Seçili profili siler. Son profil kalır.
  void _deleteProfile() {
    if (_profiles.length <= 1) return;
    _profiles = [
      for (final profile in _profiles)
        if (profile.id != _activeId) profile,
    ];
    setState(() => _fillProfile(_profiles.first.id));
  }

  /// Formu doğrular ve yerel kutuya yazar.
  Future<void> _save() async {
    _stash();
    for (final profile in _profiles) {
      final endpoint = profile.endpoint.trim();
      if (endpoint.isNotEmpty && !isHttpUrl(endpoint)) {
        setState(() {
          _endpointError = 'Geçerli bir http veya https adresi gir.';
          _fillProfile(profile.id);
        });
        return;
      }
    }
    final tokenText = _maxTokens.text.trim();
    int? maxTokens;
    if (tokenText.isNotEmpty) {
      maxTokens = int.tryParse(tokenText);
      if (maxTokens == null || maxTokens < 1) {
        setState(() => _tokenError = 'Pozitif bir sayı gir veya boş bırak.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _endpointError = null;
      _tokenError = null;
    });
    final next = AppSettings(
      profiles: _profiles,
      activeProfileId: _activeId,
      payloadType: _payload,
      systemPrompt: _system.text,
      temperature: _useTemperature ? _temperature : null,
      maxTokens: maxTokens,
      topP: _useTopP ? _topP : null,
      sendFullHistory: _fullHistory,
    );
    await ref.read(settingsControllerProvider.notifier).save(next);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _profiles.cast<ApiProfile?>().firstWhere(
      (profile) => profile?.id == _activeId,
      orElse: () => _profiles.isEmpty ? null : _profiles.first,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        key: const Key('settings-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Profiller',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (selected != null)
            DropdownButtonFormField<String>(
              key: ValueKey(selected.id),
              initialValue: selected.id,
              decoration: const InputDecoration(labelText: 'Etkin profil'),
              items: [
                for (final profile in _profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    child: Text(profile.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                if (id == null || id == _activeId) return;
                _stash();
                setState(() => _fillProfile(id));
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Profil adı'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'API Key',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Göster' : 'Gizle',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Özel API Endpoint URL',
              errorText: _endpointError,
              helperText: selected != null && isCursorProfile(selected)
                  ? 'Cursor adresi hazır. Yalnızca API anahtarını yapıştır.'
                  : 'Örnek: https://api.openai.com/v1/chat/completions',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: InputDecoration(
              labelText: 'Model adı',
              helperText: selected != null && isCursorProfile(selected)
                  ? 'Boş bırak. Cursor hesabındaki modeli kullanır.'
                  : 'Boşsa istekte model alanı gönderilmez.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addProfile,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Profil ekle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _profiles.length <= 1 ? null : _deleteProfile,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sil'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Payload Tipi',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<PayloadType>(
            segments: const [
              ButtonSegment(value: PayloadType.base64, label: Text('Base64')),
              ButtonSegment(
                value: PayloadType.multipart,
                label: Text('Multipart'),
              ),
            ],
            selected: {_payload},
            onSelectionChanged: (value) =>
                setState(() => _payload = value.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _system,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Sistem İstemi',
              alignLabelWithHint: true,
              helperText: 'Boşsa sistem mesajı gönderilmez.',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tüm sohbet geçmişini gönder'),
            value: _fullHistory,
            onChanged: (value) => setState(() => _fullHistory = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Temperature'),
            subtitle: Text(
              _useTemperature
                  ? _temperature.toStringAsFixed(1)
                  : 'API varsayılanı',
            ),
            value: _useTemperature,
            onChanged: (value) => setState(() => _useTemperature = value),
          ),
          if (_useTemperature)
            Slider(
              value: _temperature,
              min: 0,
              max: 2,
              divisions: 20,
              label: _temperature.toStringAsFixed(1),
              onChanged: (value) => setState(() => _temperature = value),
            ),
          TextField(
            controller: _maxTokens,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max Tokens',
              errorText: _tokenError,
              helperText: 'Boş bırakılırsa sınır gönderilmez.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Top P'),
            subtitle: Text(
              _useTopP ? _topP.toStringAsFixed(2) : 'API varsayılanı',
            ),
            value: _useTopP,
            onChanged: (value) => setState(() => _useTopP = value),
          ),
          if (_useTopP)
            Slider(
              value: _topP,
              min: 0,
              max: 1,
              divisions: 20,
              label: _topP.toStringAsFixed(2),
              onChanged: (value) => setState(() => _topP = value),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
