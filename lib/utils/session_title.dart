/// İlk kullanıcı mesajından kısa bir sohbet başlığı üretir.
String sessionTitleFrom(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return 'Yeni sohbet';
  if (compact.length <= 42) return compact;
  return '${compact.substring(0, 42).trim()}…';
}

/// İlk mesajdan 2-3 kelimelik geçici bir başlık seçer.
String shortTitleFrom(String text) {
  final words = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .take(3);
  final title = words.join(' ');
  if (title.isEmpty) return 'Yeni sohbet';
  return title;
}

/// Modelin ürettiği başlığı tek satırlık kısa bir ada indirger.
String cleanGeneratedTitle(String raw) {
  var text = raw.split(RegExp(r'\r?\n')).first.trim();
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'''^["'`“”]+|["'`“”]+$'''), '');
  if (text.length > 48) text = text.substring(0, 48).trim();
  if (text.isEmpty) return 'Yeni sohbet';
  return text;
}
