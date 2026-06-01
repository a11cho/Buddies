// 실제 REST API 연결 단계에서 사용할 기본 설정입니다.
// 지금 Phase 1에서는 구조만 잡아두고, 화면은 mock data를 사용합니다.
class ApiClientConfig {
  const ApiClientConfig({
    this.baseUrl = 'https://10.0.2.2:8443',
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
  // 예: /lobbies -> https://10.0.2.2:8443/lobbies
  Uri buildUri(String path) {
    final baseUri = Uri.parse(config.baseUrl);
    final normalizedBase =
        baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(path: '$normalizedBase$normalizedPath');
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
