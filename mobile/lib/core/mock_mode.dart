// 백엔드 API가 준비되기 전까지 mock data를 기준으로 화면을 개발하기 위한 플래그입니다.
// 실제 API를 붙일 때 이 값을 기준으로 service 구현을 교체할 수 있습니다.
const useMockMode = true;

// 실제 API 연결은 service별로 단계적으로 진행합니다.
// Auth/User는 먼저 실제 API를 사용하고, 나머지는 아직 mock service를 유지합니다.
const useMockAuthService = false;
const useMockUserService = false;
const useMockLobbyService = useMockMode;
const useMockCartService = useMockMode;
const useMockPaymentService = useMockMode;
const useMockChatService = useMockMode;
const useMockReportService = useMockMode;
const useMockRatingService = useMockMode;
const useMockHelpService = useMockMode;
