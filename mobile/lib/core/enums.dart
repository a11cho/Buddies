// User 계정 상태입니다.
// SUSPENDED 또는 BANNED 사용자는 주요 기능 접근이 제한될 수 있습니다.
class UserStatus {
  const UserStatus._();

  static const active = 'ACTIVE';
  static const suspended = 'SUSPENDED';
  static const banned = 'BANNED';
}

// Lobby 안에서의 역할입니다.
class RoleInLobby {
  const RoleInLobby._();

  static const host = 'HOST';
  static const participant = 'PARTICIPANT';
}

// Lobby membership 상태입니다.
class MembershipStatus {
  const MembershipStatus._();

  static const active = 'ACTIVE';
  static const left = 'LEFT';
  static const kicked = 'KICKED';
  static const removedByTransfer = 'REMOVED_BY_TRANSFER';
}

// Lobby 상태 문자열을 한 곳에서 관리합니다.
// 화면에서 'WAITING' 같은 문자열을 직접 비교하면 오타를 찾기 어렵습니다.
class LobbyStatus {
  const LobbyStatus._();

  static const waiting = 'WAITING';
  static const locked = 'LOCKED';
  static const orderPlaced = 'ORDER_PLACED';
  static const outForDelivery = 'OUT_FOR_DELIVERY';
  static const delivered = 'DELIVERED';
  static const closed = 'CLOSED';
  static const canceled = 'CANCELED';
}

// 배달 위치 후보입니다.
// 서버와 주고받는 JSON field 이름은 deliveryZone이고, 값은 아래 문자열 중 하나입니다.
class DeliveryZone {
  const DeliveryZone._();

  static const n3 = 'N3';
  static const n2 = 'N2';
  static const north = 'NORTH';
  static const west = 'WEST';

  static const values = [
    n3,
    n2,
    north,
    west,
  ];
}

// PaymentRecord 상태입니다.
// Cart Lock 이후 송금 확인 UI에서 사용합니다.
class PaymentStatus {
  const PaymentStatus._();

  static const unpaid = 'UNPAID';
  static const paid = 'PAID';
}

// Chat message 종류입니다.
// USER, SYSTEM, MEDIA에 따라 말풍선 UI가 달라질 예정입니다.
class ChatMessageType {
  const ChatMessageType._();

  static const user = 'USER';
  static const system = 'SYSTEM';
  static const media = 'MEDIA';
}
