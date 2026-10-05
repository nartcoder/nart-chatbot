import 'dart:convert';

/// Tamamlanmış bir model cevabından görünen metni ayıklar.
String? tryParseAssistantText(dynamic data) {
  if (data == null) return null;
  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty || trimmed == '[DONE]') return null;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return tryParseAssistantText(jsonDecode(trimmed));
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }
  if (data is List) {
    final parts = data.map(tryParseAssistantText).whereType<String>();
    final joined = parts.join();
    return joined.trim().isEmpty ? null : joined;
  }
  if (data is Map) {
    final error = tryParseErrorMessage(data);
    if (error != null && !_hasAssistantPayload(data)) return null;

    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final first = Map<dynamic, dynamic>.from(choices.first as Map);
      final delta = first['delta'];
      if (delta is Map) {
        final text = _contentToString(delta['content']);
        if (text != null && text.isNotEmpty) return text;
      }
      final message = first['message'];
      if (message is Map) {
        final text = _contentToString(message['content']);
        if (text != null && text.isNotEmpty) return text;
      }
      if (first['text'] is String &&
          (first['text'] as String).trim().isNotEmpty) {
        return (first['text'] as String).trim();
      }
    }

    final candidates = data['candidates'];
    if (candidates is List &&
        candidates.isNotEmpty &&
        candidates.first is Map) {
      final content = (candidates.first as Map)['content'];
      if (content is Map && content['parts'] is List) {
        final text = (content['parts'] as List)
            .map((part) => part is Map ? part['text'] : null)
            .whereType<String>()
            .join();
        if (text.trim().isNotEmpty) return text.trim();
      }
    }

    for (final key in const [
      'text',
      'content',
      'message',
      'response',
      'output',
      'answer',
      'result',
      'reply',
      'data',
    ]) {
      if (!data.containsKey(key)) continue;
      final nested = tryParseAssistantText(data[key]);
      if (nested != null && nested.isNotEmpty) return nested;
    }
  }
  return null;
}

/// Hata gövdesindeki kısa mesajı okur.
String? tryParseErrorMessage(dynamic data) {
  if (data is! Map || data['error'] == null) return null;
  final error = data['error'];
  if (error is String && error.trim().isNotEmpty) return error.trim();
  if (error is Map && error['message'] is String) {
    final message = (error['message'] as String).trim();
    if (message.isNotEmpty) return message;
  }
  return null;
}

/// SSE satırından eklenecek metin parçasını çıkarır. `[DONE]` için boş string döner.
String? deltaFromSseLine(String rawLine) {
  final line = rawLine.trim();
  if (line.isEmpty || line.startsWith(':')) return null;
  if (!line.startsWith('data:')) return null;
  final data = line.substring(5).trim();
  if (data.isEmpty) return null;
  if (data == '[DONE]') return '';
  try {
    final decoded = jsonDecode(data);
    final error = tryParseErrorMessage(decoded);
    if (error != null && tryParseAssistantText(decoded) == null) {
      throw FormatException(error);
    }
    return tryParseAssistantText(decoded);
  } on FormatException {
    rethrow;
  } catch (_) {
    return data;
  }
}

/// Parça, birikmiş metnin devamı değil de tamamıysa birleştirmeyi düzeltir.
String mergeStreamPiece(String current, String piece) {
  if (piece.isEmpty) return current;
  if (current.isNotEmpty && piece.startsWith(current)) return piece;
  return current + piece;
}

bool _hasAssistantPayload(Map<dynamic, dynamic> data) {
  return data.containsKey('choices') ||
      data.containsKey('candidates') ||
      data.containsKey('content') ||
      data.containsKey('text');
}

String? _contentToString(dynamic content) {
  if (content is String) {
    return content.isEmpty ? null : content;
  }
  if (content is List) {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is String) {
        buffer.write(part);
      } else if (part is Map && part['text'] is String) {
        buffer.write(part['text']);
      }
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }
  if (content is Map && content['text'] is String) {
    final text = content['text'] as String;
    return text.isEmpty ? null : text;
  }
  return null;
}
