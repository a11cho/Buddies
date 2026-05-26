import '../core/enums.dart';

// Lobby 목록 화면에 보여줄 최소 mock 데이터 형태입니다.
// 아직 model Phase 전이므로 실제 Lobby model 대신 preview 전용 class를 둡니다.
class MockLobbyPreview {
  const MockLobbyPreview({
    required this.lobbyId,
    required this.restaurantName,
    required this.deliveryZone,
    required this.currentTotalAmount,
    required this.minimumOrderAmount,
    required this.participantCount,
    required this.orderStatus,
  });

  final int lobbyId;
  final String restaurantName;
  final String deliveryZone;
  final int currentTotalAmount;
  final int minimumOrderAmount;
  final int participantCount;
  final String orderStatus;

  // 남은 주문 금액은 음수가 되면 UI가 어색하므로 0에서 멈추게 합니다.
  int get remainingAmount {
    final remaining = minimumOrderAmount - currentTotalAmount;
    return remaining > 0 ? remaining : 0;
  }

  // SDD 기준으로 WAITING 상태에서만 새 참여가 가능합니다.
  bool get canJoin => orderStatus == LobbyStatus.waiting;
}

// 백엔드 없이 LobbyListScreen을 확인하기 위한 임시 데이터입니다.
const mockLobbyPreviews = [
  MockLobbyPreview(
    lobbyId: 10,
    restaurantName: 'MOM\'S TOUCH',
    deliveryZone: 'N3',
    currentTotalAmount: 16000,
    minimumOrderAmount: 23000,
    participantCount: 2,
    orderStatus: LobbyStatus.waiting,
  ),
  MockLobbyPreview(
    lobbyId: 11,
    restaurantName: 'Pizza School',
    deliveryZone: 'N2',
    currentTotalAmount: 31000,
    minimumOrderAmount: 30000,
    participantCount: 3,
    orderStatus: LobbyStatus.locked,
  ),
];
