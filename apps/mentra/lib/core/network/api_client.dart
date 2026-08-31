import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String message;
  final dynamic details;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'MENTRA_API_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
        _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<dynamic> get(
    String path, {
    String? token,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(path, queryParams);
    final response = await _httpClient.get(
      uri,
      headers: _buildHeaders(token: token),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(token: token),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    String? token,
  }) async {
    final uri = _buildUri(path);
    final response = await _httpClient.delete(
      uri,
      headers: _buildHeaders(token: token),
    );
    return _handleResponse(response);
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlString = '$cleanBase$cleanPath';
    final uri = Uri.parse(urlString);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    try {
      if (response.body.isNotEmpty) {
        decodedBody = jsonDecode(response.body);
      }
    } catch (_) {
      decodedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    String message = 'An unexpected error occurred.';
    if (decodedBody is Map<String, dynamic>) {
      if (decodedBody.containsKey('detail')) {
        final detail = decodedBody['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final firstError = detail.first;
          if (firstError is Map && firstError.containsKey('msg')) {
            message = firstError['msg'].toString();
          }
        }
      } else if (decodedBody.containsKey('message')) {
        message = decodedBody['message'].toString();
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      details: decodedBody,
    );
  }
}
