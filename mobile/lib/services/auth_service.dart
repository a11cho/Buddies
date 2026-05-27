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

abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<User> getMe();

  Future<void> logout();
}
