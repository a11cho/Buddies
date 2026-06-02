import '../api/api_auth_service.dart';
import '../api/api_user_service.dart';
import '../mock/mock_services.dart';
import '../services/services.dart';
import 'api_client.dart';
import 'mock_mode.dart';
import 'token_storage.dart';

// 화면은 이 registry를 통해 service를 사용합니다.
// mock인지 실제 API인지 교체하는 일은 이 파일에서만 처리합니다.
class AppServices {
  AppServices._();

  static final TokenStorage tokenStorage = InMemoryTokenStorage();
  static final ApiClient apiClient = ApiClientFactory.create(
    tokenStorage: tokenStorage,
  );

  static final AuthService authService = _buildAuthService();
  static final UserService userService = _buildUserService();
  static final LobbyService lobbyService = _buildLobbyService();
  static final CartService cartService = _buildCartService();
  static final PaymentService paymentService = _buildPaymentService();
  static final ChatService chatService = _buildChatService();
  static final ReportService reportService = _buildReportService();
  static final RatingService ratingService = _buildRatingService();
  static final HelpService helpService = _buildHelpService();

  static AuthService _buildAuthService() {
    if (useMockAuthService) {
      return MockAuthService();
    }
    return ApiAuthService(apiClient: apiClient);
  }

  static UserService _buildUserService() {
    if (useMockUserService) {
      return MockUserService();
    }
    return ApiUserService(apiClient: apiClient);
  }

  static LobbyService _buildLobbyService() {
    if (useMockLobbyService) {
      return MockLobbyService();
    }
    throw UnimplementedError('ApiLobbyService is not implemented yet.');
  }

  static CartService _buildCartService() {
    if (useMockCartService) {
      return MockCartService();
    }
    throw UnimplementedError('ApiCartService is not implemented yet.');
  }

  static PaymentService _buildPaymentService() {
    if (useMockPaymentService) {
      return MockPaymentService();
    }
    throw UnimplementedError('ApiPaymentService is not implemented yet.');
  }

  static ChatService _buildChatService() {
    if (useMockChatService) {
      return MockChatService();
    }
    throw UnimplementedError('ApiChatService is not implemented yet.');
  }

  static ReportService _buildReportService() {
    if (useMockReportService) {
      return MockReportService();
    }
    throw UnimplementedError('ApiReportService is not implemented yet.');
  }

  static RatingService _buildRatingService() {
    if (useMockRatingService) {
      return MockRatingService();
    }
    throw UnimplementedError('ApiRatingService is not implemented yet.');
  }

  static HelpService _buildHelpService() {
    if (useMockHelpService) {
      return MockHelpService();
    }
    throw UnimplementedError('ApiHelpService is not implemented yet.');
  }
}
