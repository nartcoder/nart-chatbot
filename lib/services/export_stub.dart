import 'package:nart_chat/models/chat_session.dart';

/// Dosya sistemi olmayan ortamda dışa aktarmayı reddeder.
Future<String> exportAndShareSession(ChatSession session) async {
  throw UnsupportedError('Dışa aktarma bu platformda desteklenmiyor.');
}
