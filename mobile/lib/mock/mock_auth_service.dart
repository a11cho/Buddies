import '../services/auth_service.dart';
import '../models/user.dart';
import 'mock_data_store.dart';

class MockAuthService implements AuthService {
  MockAuthService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;
  final Set<String> _pendingSignupEmails = <String>{};

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw StateError('Email and password are required.');
    }

    return AuthSession(
      accessToken: 'mock-access-token',
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: _store.currentUser,
    );
  }

  @override
  Future<void> requestSignup(SignupRequest request) async {
    if (request.email.trim().isEmpty ||
        request.name.trim().isEmpty ||
        request.password.isEmpty) {
      throw StateError('Email, name, and password are required.');
    }
    _pendingSignupEmails.add(request.email.trim());
  }

  @override
  Future<void> resendSignupOtp(String email) async {
    final normalizedEmail = email.trim();
    if (!_pendingSignupEmails.contains(normalizedEmail)) {
      throw StateError('Signup request was not found.');
    }
  }

  @override
  Future<void> verifySignup(SignupVerifyRequest request) async {
    if (!_pendingSignupEmails.contains(request.email.trim())) {
      throw StateError('Signup request was not found.');
    }
    if (request.otp.trim().length < 4) {
      throw StateError('OTP is invalid.');
    }
    _pendingSignupEmails.remove(request.email.trim());
  }

  @override
  Future<AuthSession> refreshSession() async {
    return AuthSession(
      accessToken: 'mock-access-token-refreshed',
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: _store.currentUser,
    );
  }

  @override
  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    final normalizedEmail = email.trim();
    if (!normalizedEmail.endsWith('@kaist.ac.kr')) {
      throw StateError('Only KAIST email can request password reset.');
    }

    final token = 'mock-reset-${_store.passwordResetTokensByEmail.length + 1}';
    _store.passwordResetTokensByEmail[normalizedEmail] = token;
    return PasswordResetRequestResult(mockResetToken: token);
  }

  @override
  Future<void> confirmPasswordReset(
    PasswordResetConfirmRequest request,
  ) async {
    if (request.newPassword != request.newPasswordConfirm) {
      throw StateError('Password confirmation does not match.');
    }
    if (request.newPassword.length < 8) {
      throw StateError('Password must be at least 8 characters.');
    }
    final tokenExists = _store.passwordResetTokensByEmail.values.contains(
      request.token.trim(),
    );
    if (!tokenExists) {
      throw StateError('Password reset token is invalid or expired.');
    }
    _store.passwordResetTokensByEmail.removeWhere(
      (email, token) => token == request.token.trim(),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User> getMe() async => _store.currentUser;
}
