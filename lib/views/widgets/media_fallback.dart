import 'package:flutter/material.dart';
import 'package:nart_chat/utils/app_theme.dart';

/// Resim dosyası okunamadığında gösterilen yer tutucu.
class MediaFallback extends StatelessWidget {
  const MediaFallback({super.key, this.label = 'Görsel açılamadı'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}
