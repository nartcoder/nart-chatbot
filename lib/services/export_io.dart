import 'dart:io';

import 'package:nart_chat/models/chat_session.dart';
import 'package:nart_chat/services/export_text.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Metin dosyasını belgelere kaydeder ve paylaşım sayfasını açar.
Future<String> exportAndShareSession(ChatSession session) async {
  final docs = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(docs.path, 'exports'));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final name = '${_safeName(session.title)}.txt';
  final file = File(p.join(folder.path, name));
  await file.writeAsString(renderSessionText(session));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/plain', name: name)],
      subject: session.title,
    ),
  );
  return file.path;
}

String _safeName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  if (cleaned.isEmpty) return 'sohbet';
  return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60).trim();
}
