import 'package:flutter_test/flutter_test.dart';
import 'package:nart_chat/utils/markdown_segments.dart';
import 'package:nart_chat/utils/response_parser.dart';
import 'package:nart_chat/utils/session_title.dart';
import 'package:nart_chat/utils/sse_buffer.dart';

void main() {
  test('OpenAI delta, tam cevap ve Gemini metnini okur', () {
    expect(
      tryParseAssistantText({
        'choices': [
          {
            'delta': {'content': 'Merhaba'},
          },
        ],
      }),
      'Merhaba',
    );
    expect(
      tryParseAssistantText({
        'choices': [
          {
            'message': {'content': 'Tam cevap'},
          },
        ],
      }),
      'Tam cevap',
    );
    expect(
      tryParseAssistantText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Gemini'},
              ],
            },
          },
        ],
      }),
      'Gemini',
    );
  });

  test('SSE satırlarını birleştirir ve DONE satırını atlar', () {
    final buffer = SseBuffer();
    final first = buffer.add(
      'data: {"choices":[{"delta":{"content":"Na"}}]}\n',
    );
    final second = buffer.add(
      'data: {"choices":[{"delta":{"content":"rt"}}]}\n\ndata: [DONE]\n',
    );
    expect(first, ['Na']);
    expect(second, ['rt']);
    expect(buffer.flush(), isEmpty);
  });

  test('birikimli parçayı tekrar eklemez', () {
    expect(mergeStreamPiece('Na', 'Nart'), 'Nart');
    expect(mergeStreamPiece('Na', 'rt'), 'Nart');
  });

  test('kod, tablo ve formülü ayırır', () {
    const source = '''
Giriş

| Ad | Değer |
| --- | --- |
| a | 1 |

\$\$x^2\$\$

```dart
print(1);
```
''';
    final blocks = parseMarkdownBlocks(source);
    expect(blocks.whereType<MdTable>().single.rows.first, ['Ad', 'Değer']);
    expect(blocks.whereType<MdMath>().single.tex, 'x^2');
    expect(blocks.whereType<MdCode>().single.language, 'dart');
    expect(blocks.whereType<MdCode>().single.code, contains('print(1);'));
  });

  test('kısa başlık ilk üç kelimeyi alır', () {
    expect(
      shortTitleFrom('  Flutter   State   Management   dersi '),
      'Flutter State Management',
    );
    expect(cleanGeneratedTitle('"Makarna Tarifi"\nfazlası'), 'Makarna Tarifi');
  });
}
