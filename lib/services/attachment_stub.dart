/// Web gibi dosya sistemi olmayan ortamlarda ek saklamayı reddeder.
Future<String> persistBytes(List<int> bytes, String fileName) async {
  throw UnsupportedError('Bu platformda dosya ekleri desteklenmiyor.');
}

/// Web ortamında yerel dosya okunamaz.
Future<List<int>?> readFileBytes(String path) async => null;

/// Web ortamında sıkıştırma yapılmaz.
Future<List<int>> compressImage({
  required String sourcePath,
  required List<int> original,
}) async {
  return original;
}
