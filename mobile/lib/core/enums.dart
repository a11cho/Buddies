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
