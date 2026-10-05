import 'package:nart_chat/models/api_profile.dart';

/// Ayarlara eklenen Cursor Cloud Agent profilinin kimliği.
const cursorCloudProfileId = 'cursor-cloud';

/// Cursor Cloud Agents API taban adresi. İstek yolları `/v1/...` olarak eklenir.
const cursorCloudEndpoint = 'https://api.cursor.com/v1';

/// Listede varsayılan duran Cursor profili. Anahtar kullanıcı tarafından girilir.
/// Model boş kalır; Cursor hesabın varsayılan modelini seçer.
const cursorCloudProfile = ApiProfile(
  id: cursorCloudProfileId,
  name: 'Cursor Cloud Agent',
  endpoint: cursorCloudEndpoint,
  apiKey: '',
  modelName: '',
);

/// Profilin Cursor Cloud Agents API'sine gittiğini söyler.
bool isCursorProfile(ApiProfile profile) {
  if (profile.id == cursorCloudProfileId) return true;
  return profile.endpoint.toLowerCase().contains('api.cursor.com');
}
