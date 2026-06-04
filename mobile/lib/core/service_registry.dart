import '../api/api_auth_service.dart';
import '../api/api_chat_service.dart';
import '../api/api_cart_service.dart';
import '../api/api_help_service.dart';
import '../api/api_lobby_service.dart';
import '../api/api_payment_service.dart';
import '../api/api_rating_service.dart';
import '../api/api_report_service.dart';
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
    return ApiLobbyService(apiClient: apiClient);
  }

  static CartService _buildCartService() {
    if (useMockCartService) {
      return MockCartService();
    }
    return ApiCartService(apiClient: apiClient);
  }

  static PaymentService _buildPaymentService() {
    if (useMockPaymentService) {
      return MockPaymentService();
    }
    return ApiPaymentService(apiClient: apiClient);
  }

  static ChatService _buildChatService() {
    if (useMockChatService) {
      return MockChatService();
    }
    return ApiChatService(apiClient: apiClient);
  }

  static ReportService _buildReportService() {
    if (useMockReportService) {
      return MockReportService();
    }
    return ApiReportService(apiClient: apiClient);
  }

  static RatingService _buildRatingService() {
    if (useMockRatingService) {
      return MockRatingService();
    }
    return ApiRatingService(apiClient: apiClient);
  }

  static HelpService _buildHelpService() {
    if (useMockHelpService) {
      return MockHelpService();
    }
    return ApiHelpService(apiClient: apiClient);
  }
}
