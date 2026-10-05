import 'package:flutter/widgets.dart';
import 'package:nart_chat/views/widgets/local_image_stub.dart'
    if (dart.library.io) 'package:nart_chat/views/widgets/local_image_io.dart';

/// Kayıtlı bir resim yolunu platforma uygun biçimde çizer.
class LocalImage extends StatelessWidget {
  const LocalImage({super.key, required this.path, this.height = 160});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) => buildLocalImage(path, height);
}
