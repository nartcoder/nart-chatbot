import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nart_chat/views/widgets/media_fallback.dart';

/// Yerel resim dosyasını kırparak gösterir.
Widget buildLocalImage(String path, double height) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.file(
      File(path),
      width: 220,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const MediaFallback(),
    ),
  );
}
