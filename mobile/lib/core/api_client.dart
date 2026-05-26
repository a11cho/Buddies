// 실제 REST API 연결 단계에서 사용할 기본 설정입니다.
// 지금 Phase 1에서는 구조만 잡아두고, 화면은 mock data를 사용합니다.
class ApiClientConfig {
  const ApiClientConfig({
    this.baseUrl = 'http://10.0.2.2:8080/api',
  });

  final String baseUrl;
}

// API 호출을 직접 구현하기 전, 공통 URL 생성 책임만 먼저 분리한 뼈대입니다.
// 이후 Dio/http를 붙이면 Screen -> Service -> ApiClient 흐름으로 확장합니다.
class ApiClient {
  const ApiClient({
    this.config = const ApiClientConfig(),
  });

  final ApiClientConfig config;

  // baseUrl과 endpoint path를 안전하게 합쳐 Uri로 만듭니다.
  // 예: /lobbies -> http://10.0.2.2:8080/api/lobbies
  Uri buildUri(String path) {
    final baseUri = Uri.parse(config.baseUrl);
    final normalizedBase = baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(path: '$normalizedBase$normalizedPath');
  }
}
