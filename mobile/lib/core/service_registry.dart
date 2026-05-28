import '../mock/mock_services.dart';
import '../services/services.dart';
import 'mock_mode.dart';
import 'token_storage.dart';

// 화면은 이 registry를 통해 service를 사용합니다.
// mock인지 실제 API인지 교체하는 일은 이 파일에서만 처리합니다.
class AppServices {
  AppServices._();

  static final AuthService authService = _buildAuthService();
  static final LobbyService lobbyService = _buildLobbyService();
  static final CartService cartService = _buildCartService();
  static final PaymentService paymentService = _buildPaymentService();
  static final ChatService chatService = _buildChatService();
  static final TokenStorage tokenStorage = InMemoryTokenStorage();

  static AuthService _buildAuthService() {
    if (useMockMode) {
      return MockAuthService();
    }
    throw UnimplementedError('ApiAuthService is not implemented yet.');
  }

  static LobbyService _buildLobbyService() {
    if (useMockMode) {
      return MockLobbyService();
    }
    throw UnimplementedError('ApiLobbyService is not implemented yet.');
  }

  static CartService _buildCartService() {
    if (useMockMode) {
      return MockCartService();
    }
    throw UnimplementedError('ApiCartService is not implemented yet.');
  }

  static PaymentService _buildPaymentService() {
    if (useMockMode) {
      return MockPaymentService();
    }
    throw UnimplementedError('ApiPaymentService is not implemented yet.');
  }

  static ChatService _buildChatService() {
    if (useMockMode) {
      return MockChatService();
    }
    throw UnimplementedError('ApiChatService is not implemented yet.');
  }
}
