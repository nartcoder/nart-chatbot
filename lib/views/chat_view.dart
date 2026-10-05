import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nart_chat/controllers/chat_controller.dart';
import 'package:nart_chat/models/message_role.dart';
import 'package:nart_chat/utils/app_theme.dart';
import 'package:nart_chat/views/widgets/composer_bar.dart';
import 'package:nart_chat/views/widgets/message_bubble.dart';
import 'package:nart_chat/views/widgets/typing_indicator.dart';

/// Aktif sohbetin mesaj listesi ve yazma alanı.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final Set<String> _seen = {};
  String? _sessionId;
  var _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Kullanıcı yukarı çıktıysa otomatik kaydırmayı bırakır.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final distance = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    _stickToBottom = distance < 120;
  }

  @override
  void didChangeMetrics() {
    _scrollToEnd();
  }

  /// Listeyi, kullanıcı alttaysa son mesaja kaydırır.
  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_stickToBottom) return;
      final target = _scroll.position.maxScrollExtent;
      if (!animate || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
        return;
      }
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (previous, next) {
      final previousSession = previous?.activeSession;
      final nextSession = next.activeSession;
      final previousText =
          previousSession == null || previousSession.messages.isEmpty
          ? ''
          : previousSession.messages.last.textContent;
      final nextText = nextSession == null || nextSession.messages.isEmpty
          ? ''
          : nextSession.messages.last.textContent;
      final changed =
          previousSession?.id != nextSession?.id ||
          previousSession?.messages.length != nextSession?.messages.length ||
          previousText != nextText;
      if (changed) _scrollToEnd();
    });

    final session = chat.activeSession;
    if (session?.id != _sessionId) {
      _sessionId = session?.id;
      _seen.clear();
      _stickToBottom = true;
      _scrollToEnd(animate: false);
    }

    final messages = session?.messages ?? const [];
    final waitingHere =
        chat.isSending &&
        !chat.isStreaming &&
        chat.sendingSessionId != null &&
        chat.sendingSessionId == session?.id;
    final showEmpty = messages.isEmpty && !waitingHere;

    return Column(
      children: [
        Expanded(
          child: showEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'İlk mesajını yaz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length + (waitingHere ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (waitingHere && index == messages.length) {
                      return const TypingIndicator();
                    }
                    final message = messages[index];
                    final isLatest = index == messages.length - 1;
                    final animate = isLatest && _seen.add(message.id);
                    final last = messages.last;
                    return _Arrive(
                      key: ValueKey(message.id),
                      animate: animate,
                      child: MessageBubble(
                        message: message,
                        isLastAi:
                            message.role == MessageRole.ai &&
                            last.id == message.id,
                      ),
                    );
                  },
                ),
        ),
        const ComposerBar(),
      ],
    );
  }
}

class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: widget.child,
      ),
    );
  }
}
