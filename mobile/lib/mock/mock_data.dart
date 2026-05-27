import '../core/enums.dart';
import '../models/lobby.dart';

// 백엔드 없이 LobbyListScreen을 확인하기 위한 임시 데이터입니다.
// Phase 3부터는 실제 Lobby model과 같은 구조를 사용합니다.
const mockLobbies = [
  Lobby(
    lobbyId: 10,
    hostUserId: 3,
    hostName: 'Junsu',
    hostTrustScore: 4.6,
    restaurantName: 'MOM\'S TOUCH',
    deliveryZone: 'N3',
    minimumOrderAmount: 23000,
    currentTotalAmount: 16000,
    remainingAmount: 7000,
    deliveryFee: 3000,
    participantCount: 2,
    orderStatus: LobbyStatus.waiting,
    lastReadMessageId: 1052,
    unreadCount: 3,
    members: [],
    cartItems: [],
    paymentRecords: [],
  ),
  Lobby(
    lobbyId: 11,
    hostUserId: 5,
    hostName: 'Mina',
    hostTrustScore: 4.9,
    restaurantName: 'Pizza School',
    deliveryZone: 'N2',
    minimumOrderAmount: 30000,
    currentTotalAmount: 31000,
    remainingAmount: 0,
    deliveryFee: 2500,
    participantCount: 3,
    orderStatus: LobbyStatus.locked,
    lastReadMessageId: 1050,
    unreadCount: 0,
    members: [],
    cartItems: [],
    paymentRecords: [],
  ),
];
