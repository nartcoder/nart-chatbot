import 'package:nart_chat/utils/response_parser.dart';

/// Gelen bayt akışını SSE satırlarına böler.
class SseBuffer {
  String _remainder = '';

  /// Yeni parçadan tamamlanan metin deltalarını döndürür.
  List<String> add(String chunk) {
    _remainder += chunk;
    final lines = _remainder.split('\n');
    _remainder = lines.removeLast();
    return _collect(lines);
  }

  /// Akış bitince elde kalan satırı da işler.
  List<String> flush() {
    final tail = _remainder;
    _remainder = '';
    if (tail.trim().isEmpty) return const [];
    return _collect([tail]);
  }

  List<String> _collect(List<String> lines) {
    final deltas = <String>[];
    for (final line in lines) {
      final delta = deltaFromSseLine(line);
      if (delta == null || delta.isEmpty) continue;
      deltas.add(delta);
    }
    return deltas;
  }
}
