import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/chat_controller.dart';
import 'package:nart_chat/controllers/settings_controller.dart';
import 'package:nart_chat/models/cursor_profile.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/views/widgets/glass.dart';
import 'package:nart_chat/views/widgets/repo_sheet.dart';
import 'package:nart_chat/views/widgets/local_image.dart';

/// Mesaj yazma alanı, ek önizlemesi ve mikrofon ya da gönder düğmesi.
class ComposerBar extends ConsumerStatefulWidget {
  const ComposerBar({super.key});

  @override
  ConsumerState<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends ConsumerState<ComposerBar> {
  final TextEditingController _controller = TextEditingController();
  var _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Metin varken gönder düğmesini açar.
  void _onChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider.select((state) => state.dictation), (
      previous,
      next,
    ) {
      if (next == null || next == _controller.text) return;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    final listening = chat.isListening;
    final showSend = _hasText;
    final canSend = showSend && !chat.isSending;
    final settings = ref.watch(settingsControllerProvider);
    final profile =
        settings.profileById(chat.activeSession?.profileId) ?? settings.active;
    final showRepo = isCursorProfile(profile);
    final repo = chat.selectedRepoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chat.image != null || chat.file != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (chat.image != null)
                      _PreviewChip(
                        label: chat.image!.name,
                        child: LocalImage(path: chat.image!.path, height: 44),
                        onRemove: () => ref
                            .read(chatControllerProvider.notifier)
                            .clearImage(),
                      ),
                    if (chat.file != null)
                      _PreviewChip(
                        label: chat.file!.name,
                        child: const Icon(
                          Icons.insert_drive_file_outlined,
                          color: AppColors.accent,
                        ),
                        onRemove: () => ref
                            .read(chatControllerProvider.notifier)
                            .clearFile(),
                      ),
                  ],
                ),
              ),
            if (showRepo)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 48,
                    ),
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.account_tree_outlined,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      label: Text(
                        repo == null || repo.isEmpty ? 'Repo seç' : repo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => showRepoSheet(context),
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Ekle',
                  onPressed: () => _openSheet(context),
                  icon: const Icon(Icons.add_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yaz',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                _WaveButton(
                  tooltip: showSend
                      ? 'Gönder'
                      : (listening ? 'Durdur' : 'Mikrofon'),
                  icon: showSend
                      ? Icons.arrow_upward_rounded
                      : Icons.mic_none_rounded,
                  enabled: showSend ? canSend : true,
                  animate: listening,
                  onTap: () => _onAction(showSend),
                  onLongPressStart: showSend
                      ? null
                      : () => ref
                            .read(chatControllerProvider.notifier)
                            .startListening(),
                  onLongPressEnd: showSend
                      ? null
                      : () => ref
                            .read(chatControllerProvider.notifier)
                            .stopListening(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Gönderir ya da dinlemeyi açıp kapatır.
  Future<void> _onAction(bool showSend) async {
    final notifier = ref.read(chatControllerProvider.notifier);
    if (showSend) {
      final text = _controller.text;
      _controller.clear();
      await notifier.sendMessage(text);
      return;
    }
    if (ref.read(chatControllerProvider).isListening) {
      await notifier.stopListening();
      return;
    }
    await notifier.startListening();
  }

  /// Resim ve dosya seçeneklerini açar.
  Future<void> _openSheet(BuildContext context) {
    final notifier = ref.read(chatControllerProvider.notifier);
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Resim Yükle'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  notifier.pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text('Dosya Yükle'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  notifier.pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.child,
    required this.onRemove,
  });

  final String label;
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: FittedBox(fit: BoxFit.cover, child: child),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: 'Kaldır',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _WaveButton extends StatefulWidget {
  const _WaveButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.animate,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final bool animate;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  State<_WaveButton> createState() => _WaveButtonState();
}

class _WaveButtonState extends State<_WaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didUpdateWidget(covariant _WaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  /// Dalga animasyonunu dinleme durumuna bağlar.
  void _sync() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.animate && !reduced) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? AppColors.accent : AppColors.surfaceRaised;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPressStart: widget.onLongPressStart == null
            ? null
            : (_) => widget.onLongPressStart!(),
        onLongPressEnd: widget.onLongPressEnd == null
            ? null
            : (_) => widget.onLongPressEnd!(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.animate)
                    ...List.generate(2, (index) {
                      final progress = (_controller.value + index / 2) % 1;
                      return Container(
                        width: 36 + (progress * 16),
                        height: 36 + (progress * 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(
                              alpha: (1 - progress) * 0.45,
                            ),
                          ),
                        ),
                      );
                    }),
                  Material(
                    color:
                        widget.icon == Icons.arrow_upward_rounded &&
                            widget.enabled
                        ? color
                        : AppColors.surfaceRaised,
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color:
                            widget.icon == Icons.arrow_upward_rounded &&
                                widget.enabled
                            ? AppColors.background
                            : AppColors.text,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
