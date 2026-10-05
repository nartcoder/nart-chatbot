import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/chat_controller.dart';
import 'package:nart_chat/models/chat_message.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/utils/file_kind.dart';
import 'package:nart_chat/views/widgets/local_image.dart';
import 'package:nart_chat/views/widgets/markdown_message.dart';
import 'package:path/path.dart' as p;

/// Tek bir sohbet satırını balon olarak çizer.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isLastAi,
  });

  final ChatMessage message;
  final bool isLastAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.86;
    if (message.role == MessageRole.thinking) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SelectableText(
              message.textContent,
              style: const TextStyle(
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }
    if (message.role == MessageRole.tool) {
      return _ToolChip(message: message);
    }

    final isUser = message.role == MessageRole.user;
    final isError = message.role == MessageRole.error;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final speakingId = ref.watch(
      chatControllerProvider.select((state) => state.speakingMessageId),
    );
    final speaking = speakingId == message.id;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: isError
                ? AppColors.danger.withValues(alpha: 0.14)
                : isUser
                ? AppColors.userBubble
                : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isError
                  ? AppColors.danger.withValues(alpha: 0.7)
                  : AppColors.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imagePath != null) ...[
                LocalImage(path: message.imagePath!),
                const SizedBox(height: 8),
              ],
              if (message.fileName != null || message.filePath != null) ...[
                _FileBadge(
                  name: message.fileName ?? p.basename(message.filePath!),
                ),
                const SizedBox(height: 8),
              ],
              if (isError)
                SelectableText(
                  message.textContent,
                  style: const TextStyle(color: AppColors.danger, height: 1.4),
                )
              else if (isUser)
                SelectableText(
                  message.textContent,
                  style: const TextStyle(color: AppColors.text, height: 1.4),
                )
              else
                MarkdownMessage(data: message.textContent),
              if (isError)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        ref.read(chatControllerProvider.notifier).retry(),
                    child: const Text('Tekrar Dene'),
                  ),
                )
              else if (!isUser)
                _AiActions(
                  message: message,
                  showRegenerate: isLastAi,
                  speaking: speaking,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final running = message.toolStatus?.toLowerCase() != 'completed';
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (running)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.textContent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileBadge extends StatelessWidget {
  const _FileBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final kind = fileKindFromName(name);
    final color = fileKindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fileKindIcon(kind), color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiActions extends ConsumerWidget {
  const _AiActions({
    required this.message,
    required this.showRegenerate,
    required this.speaking,
  });

  final ChatMessage message;
  final bool showRegenerate;
  final bool speaking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatControllerProvider.notifier);
    return Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: 'Panoya Kopyala',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message.textContent));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
        ),
        if (showRegenerate)
          IconButton(
            tooltip: 'Yeniden Oluştur',
            onPressed: notifier.regenerate,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        IconButton(
          tooltip: speaking ? 'Durdur' : 'Sesli Oku',
          onPressed: () => notifier.toggleSpeak(message.id),
          icon: Icon(
            speaking ? Icons.stop_rounded : Icons.volume_up_outlined,
            size: 18,
          ),
        ),
      ],
    );
  }
}
