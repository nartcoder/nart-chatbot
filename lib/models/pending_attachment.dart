/// Gönderilmeyi bekleyen, henüz mesaja yazılmamış bir ek.
class PendingAttachment {
  const PendingAttachment({
    required this.path,
    required this.name,
    this.extractedText,
  });

  final String path;
  final String name;
  final String? extractedText;
}
