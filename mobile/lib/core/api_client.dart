import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

// 실제 REST API 연결 단계에서 사용할 기본 설정입니다.
class ApiClientConfig {
  const ApiClientConfig({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://localhost:8443',
    ),
    this.timeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final Duration timeout;
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final Object? responseBody;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return '$message ($statusCode)';
  }
}

// 모든 REST service가 공유할 HTTP client입니다.
// 인증 토큰 첨부, JSON encode/decode, backend error response 변환을 이곳에서 처리합니다.
class ApiClient {
  ApiClient({
    this.config = const ApiClientConfig(),
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  })  : tokenStorage = tokenStorage ?? InMemoryTokenStorage(),
        _httpClient = httpClient ?? http.Client();

  final ApiClientConfig config;
  final TokenStorage tokenStorage;
  final http.Client _httpClient;

  Future<dynamic> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
    bool authenticated = true,
  }) {
    return request(
      'GET',
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool authenticated = true,
  }) {
    return request(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool authenticated = true,
  }) {
    return request(
      'PATCH',
      path,
      body: body,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool authenticated = true,
  }) {
    return request(
      'DELETE',
      path,
      body: body,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool authenticated = true,
  }) async {
    final request = http.Request(
      method,
      buildUri(path, queryParameters: queryParameters),
    );
    request.headers.addAll(await _headers(authenticated: authenticated));
    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamedResponse = await _httpClient.send(request).timeout(
            config.timeout,
          );
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(message: 'Request timed out.');
    } on http.ClientException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  // baseUrl과 endpoint path를 안전하게 합쳐 Uri로 만듭니다.
  // 예: /lobbies -> https://10.0.2.2:8443/lobbies
  Uri buildUri(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) {
    final baseUri = Uri.parse(config.baseUrl);
    final normalizedBase =
        baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final mergedQuery = <String, String>{
      ...baseUri.queryParameters,
      for (final entry in queryParameters.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return baseUri.replace(
      path: '$normalizedBase$normalizedPath',
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      final accessToken = await tokenStorage.readAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  dynamic _parseResponse(http.Response response) {
    final responseBody = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    }

    throw ApiException(
      statusCode: response.statusCode,
      responseBody: responseBody,
      message: extractApiErrorMessage(
        responseBody,
        fallbackMessage: 'Request failed.',
      ),
    );
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('application/json')) {
      return response.body;
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      return response.body;
    }
  }

  void close() {
    _httpClient.close();
  }
}

class ApiResponseParser {
  const ApiResponseParser._();

  static Map<String, dynamic> requireObject(
    Object? responseBody, {
    String message = 'Expected an object response.',
  }) {
    if (responseBody is Map<String, dynamic>) {
      return responseBody;
    }
    throw ApiException(message: message, responseBody: responseBody);
  }

  static List<dynamic> requireList(
    Object? responseBody, {
    String message = 'Expected a list response.',
  }) {
    if (responseBody is List<dynamic>) {
      return responseBody;
    }
    throw ApiException(message: message, responseBody: responseBody);
  }
}

class ApiClientFactory {
  const ApiClientFactory._();

  static ApiClient create({
    ApiClientConfig config = const ApiClientConfig(),
    required TokenStorage tokenStorage,
  }) {
    return ApiClient(
      config: config,
      tokenStorage: tokenStorage,
    );
  }
}

// 백엔드 에러 response가 최종 확정되기 전까지 사용할 에러 메시지 추출 helper입니다.
// 업데이트된 가정 기준으로 error를 가장 먼저 보고, message/errorCode를 fallback으로 봅니다.
String extractApiErrorMessage(
  Object? responseBody, {
  String fallbackMessage = 'Request failed.',
}) {
  if (responseBody is Map<String, dynamic>) {
    final error = responseBody['error'];
    if (error is String && error.isNotEmpty) {
      return error;
    }

    final message = responseBody['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    final errorCode = responseBody['errorCode'];
    if (errorCode is String && errorCode.isNotEmpty) {
      return errorCode;
    }
  }

  return fallbackMessage;
}
