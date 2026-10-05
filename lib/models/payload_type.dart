/// İstek gövdesinin resim ve dosyayı nasıl taşıyacağını seçer.
enum PayloadType {
  base64,
  multipart;

  /// Kayıtlı ayar değerini payload tipine çevirir.
  static PayloadType fromStorage(String? raw) {
    if (raw == PayloadType.multipart.name) return PayloadType.multipart;
    return PayloadType.base64;
  }
}
