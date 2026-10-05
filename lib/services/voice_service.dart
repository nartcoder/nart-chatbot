import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nart_chat/utils/locale_match.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Mikrofon ve sesli okuma motorlarını cihaz diline bağlar.
class VoiceService {
  VoiceService();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  var _speechReady = false;
  var _disposed = false;
  String? speakingMessageId;
  void Function(bool listening)? _onListening;

  /// Dinlemeyi başlatır ve ara sonuçları [onText] ile iletir.
  Future<void> listen({
    required Locale device,
    required void Function(String text) onText,
    required void Function(bool listening) onListening,
  }) async {
    if (_disposed) return;
    _onListening = onListening;
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (_disposed) return;
          _onListening?.call(status == 'listening');
        },
        onError: (_) {
          if (_disposed) return;
          _onListening?.call(false);
        },
      );
    }
    if (!_speechReady) {
      throw VoiceException('Konuşma tanıma bu cihazda kullanılamıyor.');
    }
    final locales = await _speech.locales();
    final localeId = matchSpeechLocale(device, [
      for (final locale in locales) locale.localeId,
    ]);
    await _speech.listen(
      onResult: (result) {
        if (_disposed) return;
        onText(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 1),
      ),
    );
  }

  /// Süregelen dinlemeyi durdurur.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Aynı mesajı durdurur ya da yeni mesajı cihaz dilinde okur.
  Future<void> toggleSpeak({
    required String messageId,
    required String text,
    required Locale device,
    required void Function(String? messageId) onState,
  }) async {
    if (_disposed) return;
    if (speakingMessageId == messageId) {
      speakingMessageId = null;
      onState(null);
      await _tts.stop();
      return;
    }
    await _tts.stop();
    final tag = localeTag(device);
    try {
      await _tts.setLanguage(tag);
    } catch (_) {
      await _tts.setLanguage(device.languageCode);
    }
    speakingMessageId = messageId;
    onState(messageId);
    _tts.setCompletionHandler(() {
      if (_disposed) return;
      speakingMessageId = null;
      onState(null);
    });
    _tts.setCancelHandler(() {
      if (_disposed) return;
      speakingMessageId = null;
      onState(null);
    });
    await _tts.speak(text);
  }

  /// Motorları kapatır.
  Future<void> dispose() async {
    _disposed = true;
    speakingMessageId = null;
    await _speech.cancel();
    await _tts.stop();
  }
}

/// Ses motorunun kullanıcıya gösterilecek hatası.
class VoiceException implements Exception {
  VoiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
