import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nart_chat/utils/app_theme.dart';

/// Buzlu cam yüzey: bulanıklık, yarı saydam dolgu ve ince kenar.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = AppRadius.md,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Alttan açılan buzlu cam sayfayı gösterir.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.glass,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Material(
              color: Colors.transparent,
              child: builder(sheetContext),
            ),
          ),
        ),
      );
    },
  );
}
