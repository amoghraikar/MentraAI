import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiConfigStorage {
  AiConfigStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static Map<String, String> _inMemoryCache = {
    'provider': 'gemini',
    'apiKey': '',
    'model': 'gemini-1.5-flash',
    'systemPrompt': '',
    'endpointUrl': '',
  };

  static const _providerKey = 'mentra_ai_provider';
  static const _apiKey = 'mentra_ai_api_key';
  static const _modelKey = 'mentra_ai_model';
  static const _systemPromptKey = 'mentra_ai_system_prompt';
  static const _endpointKey = 'mentra_ai_endpoint_url';

  Future<Map<String, String>> loadConfig() async {
    try {
      final provider = await _storage.read(key: _providerKey).timeout(const Duration(milliseconds: 150)) ?? _inMemoryCache['provider']!;
      final apiKey = await _storage.read(key: _apiKey).timeout(const Duration(milliseconds: 150)) ?? _inMemoryCache['apiKey']!;
      final model = await _storage.read(key: _modelKey).timeout(const Duration(milliseconds: 150)) ?? _inMemoryCache['model']!;
      final systemPrompt = await _storage.read(key: _systemPromptKey).timeout(const Duration(milliseconds: 150)) ?? _inMemoryCache['systemPrompt']!;
      final endpoint = await _storage.read(key: _endpointKey).timeout(const Duration(milliseconds: 150)) ?? _inMemoryCache['endpointUrl']!;

      _inMemoryCache = {
        'provider': provider,
        'apiKey': apiKey,
        'model': model,
        'systemPrompt': systemPrompt,
        'endpointUrl': endpoint,
      };
      return _inMemoryCache;
    } catch (_) {
      return Map.from(_inMemoryCache);
    }
  }

  Future<void> saveConfig({
    required String provider,
    required String apiKey,
    required String model,
    String? systemPrompt,
    String? endpointUrl,
  }) async {
    _inMemoryCache = {
      'provider': provider,
      'apiKey': apiKey,
      'model': model,
      'systemPrompt': systemPrompt ?? '',
      'endpointUrl': endpointUrl ?? '',
    };
    try {
      await _storage.write(key: _providerKey, value: provider).timeout(const Duration(milliseconds: 250));
      await _storage.write(key: _apiKey, value: apiKey).timeout(const Duration(milliseconds: 250));
      await _storage.write(key: _modelKey, value: model).timeout(const Duration(milliseconds: 250));
      if (systemPrompt != null) {
        await _storage.write(key: _systemPromptKey, value: systemPrompt).timeout(const Duration(milliseconds: 250));
      }
      if (endpointUrl != null) {
        await _storage.write(key: _endpointKey, value: endpointUrl).timeout(const Duration(milliseconds: 250));
      }
    } catch (_) {}
  }
}
