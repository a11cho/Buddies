class OrderHistoryParticipant {
  const OrderHistoryParticipant({
    required this.userId,
    required this.name,
  });

  final int userId;
  final String name;
}

// /users/me/order-history 응답에 맞춘 주문 이력 model입니다.
// mock에서는 평가 대상자 선택을 위해 participants도 함께 들고 있습니다.
class OrderHistoryItem {
  const OrderHistoryItem({
    required this.lobbyId,
    required this.currentUserId,
    required this.restaurantName,
    required this.hostName,
    required this.participantCount,
    required this.totalAmount,
    required this.myAmount,
    required this.canRate,
    required this.participants,
    required this.rateableParticipants,
    this.deliveredAt,
    this.receiptImageUrl,
  });

  final int lobbyId;
  final int currentUserId;
  final String restaurantName;
  final DateTime? deliveredAt;
  final String hostName;
  final int participantCount;
  final int totalAmount;
  final int myAmount;
  final String? receiptImageUrl;
  final bool canRate;
  final List<OrderHistoryParticipant> participants;
  final List<OrderHistoryParticipant> rateableParticipants;
}
