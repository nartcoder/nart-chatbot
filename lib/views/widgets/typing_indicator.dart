import 'package:flutter/material.dart';
import 'package:nart_chat/utils/app_theme.dart';

/// Cevap beklenirken solda görünen üç nokta.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Semantics(
          label: 'Yazıyor',
          child: MediaQuery.disableAnimationsOf(context)
              ? const Text(
                  '...',
                  style: TextStyle(color: AppColors.muted, fontSize: 18),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        final phase = (_controller.value + index / 3) % 1;
                        final opacity =
                            0.25 + (phase < 0.5 ? phase : 1 - phase);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Opacity(
                            opacity: opacity.clamp(0.25, 1),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 7, height: 7),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
