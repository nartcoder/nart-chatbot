import 'package:flutter/widgets.dart';

/// Cihaz yerelini `tr-TR` biçimine çevirir.
String localeTag(Locale locale) {
  final country = locale.countryCode;
  if (country == null || country.isEmpty) return locale.languageCode;
  return '${locale.languageCode}-$country';
}

/// Konuşma motorundaki yerel kimliklerden cihaza en yakın olanı seçer.
String matchSpeechLocale(Locale device, List<String> localeIds) {
  final full = localeTag(device).replaceAll('_', '-').toLowerCase();
  final language = device.languageCode.toLowerCase();
  for (final id in localeIds) {
    if (id.replaceAll('_', '-').toLowerCase() == full) return id;
  }
  for (final id in localeIds) {
    if (id.replaceAll('_', '-').toLowerCase().startsWith('$language-') ||
        id.replaceAll('_', '-').toLowerCase() == language) {
      return id;
    }
  }
  if (localeIds.isEmpty) return localeTag(device);
  return localeIds.first;
}
