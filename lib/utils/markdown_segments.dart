/// Markdown gövdesinin ekranda ayrı çizilen parçaları.
sealed class MdBlock {
  const MdBlock();
}

/// Düz ya da markdown metin.
class MdText extends MdBlock {
  const MdText(this.text);
  final String text;
}

/// Çitle çevrili kod bloğu.
class MdCode extends MdBlock {
  const MdCode({required this.language, required this.code});
  final String language;
  final String code;
}

/// LaTeX formülü.
class MdMath extends MdBlock {
  const MdMath({required this.tex, required this.display});
  final String tex;
  final bool display;
}

/// Markdown tablosu. İlk satır başlıktır.
class MdTable extends MdBlock {
  const MdTable(this.rows);
  final List<List<String>> rows;
}

/// Metni kod, formül, tablo ve düz yazı bloklarına ayırır.
List<MdBlock> parseMarkdownBlocks(String input) {
  if (input.isEmpty) return const [];
  final blocks = <MdBlock>[];
  final fence = RegExp(r'```([^\n`]*)\r?\n?([\s\S]*?)```');
  var cursor = 0;
  for (final match in fence.allMatches(input)) {
    if (match.start > cursor) {
      blocks.addAll(_parseRich(input.substring(cursor, match.start)));
    }
    blocks.add(
      MdCode(
        language: (match.group(1) ?? '').trim(),
        code: (match.group(2) ?? '').replaceAll(RegExp(r'\n$'), ''),
      ),
    );
    cursor = match.end;
  }
  if (cursor < input.length) {
    final rest = input.substring(cursor);
    final open = rest.lastIndexOf('```');
    final hasUnclosed = open >= 0 && !rest.substring(open + 3).contains('```');
    if (hasUnclosed) {
      blocks.addAll(_parseRich(rest.substring(0, open)));
      final after = rest.substring(open + 3);
      final newline = after.indexOf('\n');
      final language = (newline == -1 ? after : after.substring(0, newline))
          .trim();
      final code = newline == -1 ? '' : after.substring(newline + 1);
      blocks.add(MdCode(language: language, code: code));
    } else {
      blocks.addAll(_parseRich(rest));
    }
  }
  return blocks.where((block) {
    return block is! MdText || block.text.trim().isNotEmpty;
  }).toList();
}

List<MdBlock> _parseRich(String input) {
  final blocks = <MdBlock>[];
  final display = RegExp(r'\$\$([\s\S]+?)\$\$');
  var cursor = 0;
  for (final match in display.allMatches(input)) {
    if (match.start > cursor) {
      blocks.addAll(_parseTables(input.substring(cursor, match.start)));
    }
    blocks.add(MdMath(tex: (match.group(1) ?? '').trim(), display: true));
    cursor = match.end;
  }
  if (cursor < input.length) {
    blocks.addAll(_parseTables(input.substring(cursor)));
  }
  return blocks;
}

List<MdBlock> _parseTables(String input) {
  final lines = input.split('\n');
  final blocks = <MdBlock>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    blocks.addAll(_splitInlineMath(buffer.join('\n')));
    buffer.clear();
  }

  var index = 0;
  while (index < lines.length) {
    if (_isTableStart(lines, index)) {
      flush();
      final tableLines = <String>[];
      while (index < lines.length && lines[index].contains('|')) {
        tableLines.add(lines[index]);
        index++;
      }
      final rows = _tableRows(tableLines);
      if (rows.isNotEmpty) {
        blocks.add(MdTable(rows));
      }
      continue;
    }
    buffer.add(lines[index]);
    index++;
  }
  flush();
  return blocks;
}

bool _isTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) return false;
  if (!lines[index].contains('|')) return false;
  return _isSeparator(lines[index + 1]);
}

bool _isSeparator(String line) {
  final trimmed = line.trim();
  if (!trimmed.contains('-')) return false;
  return RegExp(r'^[\|\s:-]+$').hasMatch(trimmed) && trimmed.contains('---');
}

List<List<String>> _tableRows(List<String> lines) {
  final rows = <List<String>>[];
  for (final line in lines) {
    if (_isSeparator(line)) continue;
    rows.add(_cells(line));
  }
  return rows;
}

List<String> _cells(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
  return trimmed.split('|').map((cell) => cell.trim()).toList();
}

List<MdBlock> _splitInlineMath(String input) {
  if (input.trim().isEmpty) return const [];
  final pattern = RegExp(r'(?<!\\)\$(?!\$)([^\$\n]+?)\$(?!\$)');
  final blocks = <MdBlock>[];
  var cursor = 0;
  for (final match in pattern.allMatches(input)) {
    if (match.start > cursor) {
      blocks.add(MdText(input.substring(cursor, match.start)));
    }
    blocks.add(MdMath(tex: (match.group(1) ?? '').trim(), display: false));
    cursor = match.end;
  }
  if (cursor < input.length) {
    blocks.add(MdText(input.substring(cursor)));
  }
  return blocks;
}
