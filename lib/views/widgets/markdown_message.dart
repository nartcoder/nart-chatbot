import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/utils/markdown_segments.dart';

/// AI cevabını kod, tablo, formül ve markdown olarak çizer.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(data);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final block in blocks) _block(context, block)],
    );
  }

  Widget _block(BuildContext context, MdBlock block) {
    return switch (block) {
      MdText(:final text) => MarkdownBody(
        data: text,
        selectable: true,
        shrinkWrap: true,
        softLineBreak: true,
        styleSheet: _sheet(context),
      ),
      MdCode(:final language, :final code) => _CodeBlock(
        language: language,
        code: code,
      ),
      MdMath(:final tex, :final display) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: display ? MathStyle.display : MathStyle.text,
            textStyle: const TextStyle(color: AppColors.text, fontSize: 16),
            onErrorFallback: (error) =>
                Text(tex, style: const TextStyle(color: AppColors.text)),
          ),
        ),
      ),
      MdTable(:final rows) => _GlassTable(rows: rows),
    };
  }

  MarkdownStyleSheet _sheet(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.text,
        height: 1.45,
      ),
      h1: theme.textTheme.titleLarge?.copyWith(color: AppColors.text),
      h2: theme.textTheme.titleMedium?.copyWith(color: AppColors.text),
      h3: theme.textTheme.titleSmall?.copyWith(color: AppColors.text),
      a: const TextStyle(color: AppColors.accent),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AppColors.accent,
        backgroundColor: Colors.transparent,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      listBullet: const TextStyle(color: AppColors.muted),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final label = language.isEmpty ? 'kod' : language;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Kodu Kopyala'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code.isEmpty ? ' ' : code,
              language: language.isEmpty ? 'plaintext' : language,
              theme: atomOneDarkTheme,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTable extends StatelessWidget {
  const _GlassTable({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columnCount = rows
        .map((row) => row.length)
        .reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: AppColors.hairline),
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              TableRow(
                decoration: BoxDecoration(
                  color: rowIndex == 0
                      ? AppColors.surfaceRaised.withValues(alpha: 0.9)
                      : Colors.transparent,
                ),
                children: [
                  for (var column = 0; column < columnCount; column++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        column < rows[rowIndex].length
                            ? rows[rowIndex][column]
                            : '',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: rowIndex == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
