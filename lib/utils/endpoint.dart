/// Yapıştırılan adresin başındaki ve sonundaki tırnakları temizler.
String normalizeEndpoint(String raw) {
  var value = raw.trim();
  final quoted =
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")));
  if (quoted) {
    value = value.substring(1, value.length - 1).trim();
  }
  return value;
}

/// Adresin http veya https şemalı ve host içeren bir URL olup olmadığına bakar.
bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

/// OpenAI uyumlu sohbet uç noktası bekleyen bilinen sunucular.
const standardChatHosts = <String>[
  'api.openai.com',
  'api.groq.com',
  'api.mistral.ai',
  'api.together.xyz',
  'api.together.ai',
  'openrouter.ai',
  'api.deepseek.com',
  'api.perplexity.ai',
  'api.x.ai',
  'api.fireworks.ai',
];

/// Standart sunucuda `/chat/completions` unutulmuşsa isteğin gideceği adresi tamamlar.
///
/// Kayıtlı profil metnine dokunmaz. Yalnızca `https://api.openai.com` veya
/// `https://api.openai.com/v1` gibi taban adreslere yol ekler. Tam yol zaten
/// varsa olduğu gibi bırakır.
String resolveChatEndpoint(String raw) {
  final normalized = normalizeEndpoint(raw);
  final uri = Uri.tryParse(normalized);
  if (uri == null || !isHttpUrl(normalized)) return normalized;
  if (!_isStandardChatHost(uri.host)) return normalized;
  if (uri.path.contains('chat/completions')) return uri.toString();

  final trimmed = _trimSlash(uri.path);
  if (!_isChatBasePath(trimmed)) return uri.toString();

  final path = _chatCompletionsPath(uri.host, trimmed);
  return uri.replace(path: path).toString();
}

bool _isStandardChatHost(String host) {
  final value = host.toLowerCase();
  for (final marker in standardChatHosts) {
    if (value == marker || value.endsWith('.$marker')) return true;
  }
  return false;
}

String _trimSlash(String path) {
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

/// Sürüm öneki veya boş yol, sohbet yolunun ekleneceği taban adrestir.
bool _isChatBasePath(String path) {
  return path.isEmpty ||
      path == '/' ||
      path == '/v1' ||
      path == '/api' ||
      path == '/openai' ||
      path == '/openai/v1' ||
      path == '/api/v1';
}

String _chatCompletionsPath(String host, String path) {
  if (path.isEmpty || path == '/') {
    if (host.toLowerCase() == 'api.deepseek.com') return '/chat/completions';
    return '/v1/chat/completions';
  }
  return '$path/chat/completions';
}
