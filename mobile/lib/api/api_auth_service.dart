import '../core/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class ApiAuthService implements AuthService {
  ApiAuthService({
    required ApiClient apiClient,
    this.authBasePath = '/auth',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String authBasePath;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final responseBody = await _apiClient.post(
      '$authBasePath/login',
      authenticated: false,
      body: {
        'email': email,
        'password': password,
      },
    );
    return _sessionFromLoginResponse(responseBody);
  }

  @override
  Future<void> requestSignup(SignupRequest request) async {
    await _apiClient.post(
      '$authBasePath/signup/request',
      authenticated: false,
      body: request.toJson(),
    );
  }

  @override
  Future<void> resendSignupOtp(String email) async {
    await _apiClient.post(
      '$authBasePath/signup/resend',
      authenticated: false,
      body: {
        'email': email.trim(),
      },
    );
  }

  @override
  Future<void> verifySignup(SignupVerifyRequest request) async {
    await _apiClient.post(
      '$authBasePath/signup/verify',
      authenticated: false,
      body: request.toJson(),
    );
  }

  @override
  Future<AuthSession> refreshSession() async {
    final responseBody = await _apiClient.post('$authBasePath/refresh');
    return _sessionFromLoginResponse(responseBody);
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    await _apiClient.post(
      '$authBasePath/password-reset/request',
      authenticated: false,
      body: {
        'email': email.trim(),
      },
    );
    return const PasswordResetRequestResult();
  }

  @override
  Future<void> confirmPasswordReset(
    PasswordResetConfirmRequest request,
  ) async {
    await _apiClient.post(
      '$authBasePath/password-reset/confirm',
      authenticated: false,
      body: {
        'token': request.token,
        'newPassword': request.newPassword,
        'newPasswordConfirm': request.newPasswordConfirm,
      },
    );
  }

  @override
  Future<User> getMe() async {
    final responseBody = await _apiClient.get('$authBasePath/me');
    return User.fromJson(
      ApiResponseParser.requireObject(
        responseBody,
        message: 'Invalid current user response.',
      ),
    );
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post('$authBasePath/logout');
    } finally {
      await _apiClient.tokenStorage.clearAccessToken();
    }
  }

  Future<AuthSession> _sessionFromLoginResponse(Object? responseBody) async {
    final json = ApiResponseParser.requireObject(
      responseBody,
      message: 'Invalid login response.',
    );
    final accessToken = json['accessToken'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiException(
        message: 'Login response did not include accessToken.',
        responseBody: responseBody,
      );
    }

    await _apiClient.tokenStorage.saveAccessToken(accessToken);
    try {
      return AuthSession(
        accessToken: accessToken,
        tokenType: json['tokenType'] as String? ?? 'Bearer',
        expiresIn: _parseExpiresIn(json['expiresIn']),
        user: await getMe(),
      );
    } catch (_) {
      await _apiClient.tokenStorage.clearAccessToken();
      rethrow;
    }
  }

  int _parseExpiresIn(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
