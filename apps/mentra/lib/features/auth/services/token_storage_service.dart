import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ITokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class SecureTokenStorage implements ITokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'mentra_auth_token';
  static String? _inMemoryTokenCache;

  @override
  Future<String?> getToken() async {
    if (_inMemoryTokenCache != null && _inMemoryTokenCache!.isNotEmpty) {
      return _inMemoryTokenCache;
    }
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _inMemoryTokenCache = token;
      }
      return token;
    } catch (_) {
      return _inMemoryTokenCache;
    }
  }

  @override
  Future<void> saveToken(String token) async {
    _inMemoryTokenCache = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  @override
  Future<void> clearToken() async {
    _inMemoryTokenCache = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }
}

class InMemoryTokenStorage implements ITokenStorage {
  String? _token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}
