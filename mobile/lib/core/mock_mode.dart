// 백엔드 API가 준비되기 전까지 mock data를 기준으로 화면을 개발하기 위한 플래그입니다.
// 실제 API를 붙일 때 이 값을 기준으로 service 구현을 교체할 수 있습니다.
const useMockMode = true;

// 실제 API 연결은 service별로 단계적으로 진행합니다.
// Auth/User/Lobby/Cart/Payment/Chat/Report/Rating/Help는 먼저 실제 API를 사용합니다.
const useMockAuthService = false;
const useMockUserService = false;
const useMockLobbyService = false;
const useMockCartService = false;
const useMockPaymentService = false;
const useMockChatService = false;
const useMockReportService = false;
const useMockRatingService = false;
const useMockHelpService = false;
