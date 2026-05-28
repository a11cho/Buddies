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

abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<void> requestSignup(SignupRequest request);

  Future<void> verifySignup(SignupVerifyRequest request);

  Future<User> getMe();

  Future<void> logout();
}
