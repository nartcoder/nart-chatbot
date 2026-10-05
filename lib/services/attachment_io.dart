import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Seçilen baytları uygulama belgelerine yazar.
Future<String> persistBytes(List<int> bytes, String fileName) async {
  final docs = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(docs.path, 'attachments'));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final dest = p.join(
    folder.path,
    '${const Uuid().v4()}_${_safeName(fileName)}',
  );
  await File(dest).writeAsBytes(bytes, flush: true);
  return dest;
}

/// Kayıtlı dosyanın baytlarını okur.
Future<List<int>?> readFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

/// Resmi yerelde sıkıştırır; başarısız olursa özgün baytları döndürür.
Future<List<int>> compressImage({
  required String sourcePath,
  required List<int> original,
}) async {
  try {
    final compressed = await FlutterImageCompress.compressWithFile(
      sourcePath,
      quality: 72,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );
    if (compressed != null && compressed.isNotEmpty) return compressed;
  } catch (_) {
    // Platform sıkıştırmayı desteklemiyorsa özgün dosya kullanılır.
  }
  return original;
}

String _safeName(String name) {
  final base = p.basename(name).replaceAll(RegExp(r'[^\w\.\- ]'), '_');
  if (base.isEmpty) return 'dosya';
  if (base.length <= 80) return base;
  return base.substring(base.length - 80);
}
