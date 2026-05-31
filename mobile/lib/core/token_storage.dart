// accessToken 저장소가 가져야 할 기능을 정의한 interface입니다.
// 나중에는 flutter_secure_storage 기반 구현으로 교체할 예정입니다.
abstract class TokenStorage {
  Future<String?> readAccessToken();

  Future<void> saveAccessToken(String accessToken);

  Future<void> clearAccessToken();
}

// Phase 1용 임시 token storage입니다.
// 앱을 끄면 값이 사라지므로 실제 로그인 유지 용도로는 쓰지 않습니다.
class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<void> saveAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  @override
  Future<void> clearAccessToken() async {
    _accessToken = null;
  }
}
