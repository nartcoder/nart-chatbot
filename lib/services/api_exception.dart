/// Uç noktadan veya ağ katmanından gelen, kullanıcıya gösterilen hata.
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
