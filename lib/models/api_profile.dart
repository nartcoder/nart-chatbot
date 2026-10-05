/// Kullanıcının kaydettiği bir model bağlantısı.
class ApiProfile {
  const ApiProfile({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.apiKey,
    required this.modelName,
  });

  final String id;
  final String name;
  final String endpoint;
  final String apiKey;
  final String modelName;

  /// Profili JSON haritasına çevirir.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'endpoint': endpoint,
      'apiKey': apiKey,
      'modelName': modelName,
    };
  }

  /// JSON haritasından profil okur.
  factory ApiProfile.fromJson(Map<dynamic, dynamic> json) {
    return ApiProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Profil',
      endpoint: json['endpoint'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
    );
  }

  /// Değişen alanlarla yeni bir profil kopyalar.
  ApiProfile copyWith({
    String? name,
    String? endpoint,
    String? apiKey,
    String? modelName,
  }) {
    return ApiProfile(
      id: id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
    );
  }
}
