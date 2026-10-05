import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nart_chat/services/cursor_agent_service.dart';
import 'package:nart_chat/utils/cursor_sse.dart';

void main() {
  test('Basic başlık anahtarın sonuna iki nokta koyar', () {
    expect(
      cursorBasicHeader('secret'),
      'Basic ${base64Encode(utf8.encode('secret:'))}',
    );
  });

  test('SSE düşünme, araç ve sonuç olaylarını ayırır', () {
    const raw = '''
event: thinking
data: {"text":"Bakıyorum"}

event: tool_call
data: {"callId":"call-1","name":"read_file","status":"running"}

event: result
data: {"text":"Bitti","status":"FINISHED"}

event: done
data: {}
''';
    final decoder = CursorSseDecoder();
    final events = [...decoder.add(raw), ...decoder.flush()];
    expect(events.map((event) => event.name), [
      'thinking',
      'tool_call',
      'result',
      'done',
    ]);
    expect(events[1].data['name'], 'read_file');
    expect(
      toolChipLabel('read_file', 'running'),
      'read_file çalıştırılıyor...',
    );
    expect(toolChipLabel('mcp', 'running'), 'github mcp kullanılıyor...');
    expect(toolChipLabel('read_file', 'completed'), 'read_file tamamlandı');
  });
}
