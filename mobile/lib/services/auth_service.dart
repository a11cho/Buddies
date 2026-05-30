import '../models/user.dart';

// 로그인 성공 시 service가 화면에 돌려줄 인증 결과입니다.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final User user;
}

class SignupRequest {
  const SignupRequest({
    required this.email,
    required this.name,
    required this.password,
  });

  final String email;
  final String name;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'password': password,
    };
  }
}

class SignupVerifyRequest {
  const SignupVerifyRequest({
    required this.email,
    required this.otp,
  });

  final String email;
  final String otp;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'otp': otp,
    };
  }
}

class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    this.mockResetToken,
  });

  // 실제 API는 이메일 링크만 보내지만, mock에서는 화면 확인을 위해 token을 돌려줍니다.
  final String? mockResetToken;
}

class PasswordResetConfirmRequest {
  const PasswordResetConfirmRequest({
    required this.token,
    required this.newPassword,
    required this.newPasswordConfirm,
  });

  final String token;
  final String newPassword;
  final String newPasswordConfirm;
}

abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<void> requestSignup(SignupRequest request);

  Future<void> resendSignupOtp(String email);

  Future<void> verifySignup(SignupVerifyRequest request);

  Future<AuthSession> refreshSession();

  Future<PasswordResetRequestResult> requestPasswordReset(String email);

  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request);

  Future<User> getMe();

  Future<void> logout();
}
