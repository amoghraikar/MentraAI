import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    this.tokenProvider,
    this.timeout = const Duration(seconds: 15),
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'MENTRA_API_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
        _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function()? tokenProvider;
  final Duration timeout;

  Future<String?> _resolveToken(String? explicitToken) async {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    final provider = tokenProvider;
    if (provider != null) {
      return await provider();
    }
    return null;
  }

  Future<dynamic> get(
    String path, {
    String? token,
    Map<String, String>? queryParams,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path, queryParams);
    return _sendRequest(() => _httpClient.get(
          uri,
          headers: _buildHeaders(token: effectiveToken),
        ));
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path);
    return _sendRequest(() => _httpClient.post(
          uri,
          headers: _buildHeaders(token: effectiveToken),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path);
    return _sendRequest(() => _httpClient.put(
          uri,
          headers: _buildHeaders(token: effectiveToken),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path);
    return _sendRequest(() => _httpClient.patch(
          uri,
          headers: _buildHeaders(token: effectiveToken),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> delete(
    String path, {
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path);
    return _sendRequest(() => _httpClient.delete(
          uri,
          headers: _buildHeaders(token: effectiveToken),
        ));
  }

  Stream<String> postStream(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async* {
    final effectiveToken = await _resolveToken(token);
    final uri = _buildUri(path);
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders(token: effectiveToken));
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamedResponse = await _httpClient.send(request);
    if (streamedResponse.statusCode >= 400) {
      final errBody = await streamedResponse.stream.bytesToString();
      throw ApiException(
        statusCode: streamedResponse.statusCode,
        message: 'Streaming failed ($errBody)',
      );
    }
    yield* streamedResponse.stream.transform(utf8.decoder);
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn().timeout(timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Request timed out. Please check your internet connection.',
      );
    } on SocketException {
      throw const ApiException(
        statusCode: 503,
        message: 'Could not connect to Mentra server. Please ensure the backend is running.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Unexpected network error: $e',
      );
    }
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
