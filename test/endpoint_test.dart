import 'package:flutter_test/flutter_test.dart';
import 'package:nart_chat/utils/endpoint.dart';

void main() {
  test('OpenAI taban adresine sohbet yolunu ekler', () {
    expect(
      resolveChatEndpoint('https://api.openai.com'),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(
      resolveChatEndpoint('https://api.openai.com/v1'),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(
      resolveChatEndpoint('https://api.openai.com/v1/'),
      'https://api.openai.com/v1/chat/completions',
    );
  });

  test('tam sohbet yoluna ve özel sunucuya dokunmaz', () {
    expect(
      resolveChatEndpoint('https://api.openai.com/v1/chat/completions'),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(
      resolveChatEndpoint('https://api.openai.com/v1/models'),
      'https://api.openai.com/v1/models',
    );
    expect(
      resolveChatEndpoint('https://example.com/v1'),
      'https://example.com/v1',
    );
  });

  test('Groq, OpenRouter ve DeepSeek tabanlarını tamamlar', () {
    expect(
      resolveChatEndpoint('https://api.groq.com/openai/v1'),
      'https://api.groq.com/openai/v1/chat/completions',
    );
    expect(
      resolveChatEndpoint('https://openrouter.ai/api/v1'),
      'https://openrouter.ai/api/v1/chat/completions',
    );
    expect(
      resolveChatEndpoint('https://api.deepseek.com'),
      'https://api.deepseek.com/chat/completions',
    );
  });
}
