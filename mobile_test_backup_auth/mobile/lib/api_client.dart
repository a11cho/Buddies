import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class BuddiesApiClient {
  BuddiesApiClient({
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api',
    ),
    HttpClient? httpClient,
  })  : _baseUri = Uri.parse(baseUrl),
        _httpClient = httpClient ?? HttpClient() {
    _assertSecureBaseUri(_baseUri);
  }

  final Uri _baseUri;
  final HttpClient _httpClient;

  Future<List<LobbySummary>> getLobbies({String? accessToken}) async {
    final body = await _requestJson('/lobbies', accessToken: accessToken);
    return (body as List<dynamic>)
        .map((item) => LobbySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LoginResponse> login(String email, String password) async {
    // Passwords are sent only over HTTPS/TLS and must be bcrypt-verified by the server.
    final body = await _requestJson(
      '/auth/login',
      method: 'POST',
      body: {'email': email, 'password': password},
    );
    return LoginResponse.fromJson(body as Map<String, dynamic>);
  }

  Future<void> verifySignup(String email, String otp) async {
    await _requestJson(
      '/auth/signup/verify',
      method: 'POST',
      body: {'email': email, 'otp': sha256Hex(otp)},
    );
  }

  Future<void> confirmPasswordReset(String token, String newPassword, String newPasswordConfirm) async {
    await _requestJson(
      '/auth/password-reset/confirm',
      method: 'POST',
      body: {
        'token': sha256Hex(token),
        'newPassword': newPassword,
        'newPasswordConfirm': newPasswordConfirm,
      },
    );
  }

  Future<dynamic> _requestJson(
    String path, {
    String method = 'GET',
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final request = await _openRequest(method, _baseUri.resolve(_joinPath(path)));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');

    // TODO: Store JWTs in platform secure storage after the auth flow is implemented.
    if (accessToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, text);
    }
    if (text.isEmpty) {
      return null;
    }
    return jsonDecode(text);
  }

  String _joinPath(String path) {
    final normalizedBase = _baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$normalizedBase$normalizedPath';
  }

  Future<HttpClientRequest> _openRequest(String method, Uri uri) {
    switch (method) {
      case 'POST':
        return _httpClient.postUrl(uri);
      case 'PATCH':
        return _httpClient.patchUrl(uri);
      case 'DELETE':
        return _httpClient.deleteUrl(uri);
      default:
        return _httpClient.getUrl(uri);
    }
  }

  void _assertSecureBaseUri(Uri uri) {
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '10.0.2.2';
    if (uri.scheme != 'https' && !isLocalhost) {
      throw StateError('Buddies API requires HTTPS for non-local network communication.');
    }
  }
}

String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }
}

class LobbySummary {
  const LobbySummary({
    required this.id,
    required this.restaurantName,
    required this.deliveryLocation,
    required this.orderStatus,
    required this.cartLocked,
  });

  final int id;
  final String restaurantName;
  final String deliveryLocation;
  final String orderStatus;
  final bool cartLocked;

  factory LobbySummary.fromJson(Map<String, dynamic> json) {
    return LobbySummary(
      id: json['id'] as int,
      restaurantName: json['restaurantName'] as String,
      deliveryLocation: json['deliveryLocation'] as String,
      orderStatus: json['orderStatus'] as String,
      cartLocked: json['cartLocked'] as bool,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
