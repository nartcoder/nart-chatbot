import 'package:flutter/widgets.dart';
import 'package:nart_chat/views/widgets/media_fallback.dart';

/// Dosya sistemi olmayan ortamda resim yerine yer tutucu gösterir.
Widget buildLocalImage(String path, double height) {
  return const MediaFallback(label: 'Önizleme bu platformda yok');
}
