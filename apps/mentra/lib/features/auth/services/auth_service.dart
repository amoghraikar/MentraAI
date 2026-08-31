import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'token_storage_service.dart';

class AuthResult {
  const AuthResult({
    required this.user,
    required this.token,
  });

  final UserModel user;
  final String token;
}

class AuthService {
  AuthService({
    ApiClient? apiClient,
    ITokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? SecureTokenStorage();

  final ApiClient _apiClient;
  final ITokenStorage _tokenStorage;

  ITokenStorage get tokenStorage => _tokenStorage;
  ApiClient get apiClient => _apiClient;

  Future<UserModel> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
    return UserModel.fromJson(response as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final map = response as Map<String, dynamic>;
    final token = map['access_token'] as String;
    final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);

    await _tokenStorage.saveToken(token);
    return AuthResult(user: user, token: token);
  }

  Future<UserModel?> getCurrentUser(String token) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/users/me',
        token: token,
      );
      return UserModel.fromJson(response as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _tokenStorage.clearToken();
        return null;
      }
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult?> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final user = await getCurrentUser(token);
    if (user != null) {
      return AuthResult(user: user, token: token);
    }
    return null;
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
  }
}
