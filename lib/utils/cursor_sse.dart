import 'dart:convert';

/// Cursor akışındaki tek bir SSE olayı.
class CursorSseEvent {
  const CursorSseEvent({this.id, required this.name, required this.data});

  final String? id;
  final String name;
  final Map<String, dynamic> data;
}

/// `event:` ve `data:` satırlarını olaylara böler.
class CursorSseDecoder {
  String _pending = '';

  /// Yeni parçadaki tamamlanmış olayları döndürür.
  List<CursorSseEvent> add(String chunk) {
    _pending += chunk.replaceAll('\r\n', '\n');
    final blocks = _pending.split('\n\n');
    _pending = blocks.removeLast();
    return [for (final block in blocks) ..._parse(block)];
  }

  /// Akış kapanınca elde kalan bloğu da okur.
  List<CursorSseEvent> flush() {
    final tail = _pending;
    _pending = '';
    if (tail.trim().isEmpty) return const [];
    return _parse(tail);
  }

  List<CursorSseEvent> _parse(String block) {
    String? id;
    String? name;
    final dataLines = <String>[];
    for (final raw in block.split('\n')) {
      if (raw.isEmpty || raw.startsWith(':')) continue;
      if (raw.startsWith('id:')) {
        id = raw.substring(3).trim();
      } else if (raw.startsWith('event:')) {
        name = raw.substring(6).trim();
      } else if (raw.startsWith('data:')) {
        dataLines.add(raw.substring(5).trimLeft());
      }
    }
    if (name == null && dataLines.isEmpty) return const [];
    return [
      CursorSseEvent(
        id: id,
        name: name ?? 'message',
        data: _decodeData(dataLines.join('\n')),
      ),
    ];
  }

  Map<String, dynamic> _decodeData(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const {};
    }
    return const {};
  }
}

/// Araç çipinde görünen kısa Türkçe etiketi üretir.
String toolChipLabel(String name, String status) {
  final running = status.toLowerCase() != 'completed';
  final lower = name.toLowerCase();
  if (lower == 'mcp' || lower.contains('mcp')) {
    return running ? 'github mcp kullanılıyor...' : 'github mcp tamamlandı';
  }
  return running ? '$name çalıştırılıyor...' : '$name tamamlandı';
}
