import 'json_parsing.dart';

class OrderHistoryParticipant {
  const OrderHistoryParticipant({
    required this.userId,
    required this.name,
  });

  final int userId;
  final String name;

  factory OrderHistoryParticipant.fromJson(Map<String, dynamic> json) {
    return OrderHistoryParticipant(
      userId: parseJsonInt(json['userId'] ?? json['id'], 'userId'),
      name: json['name'] as String? ?? '',
    );
  }
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

  factory OrderHistoryItem.fromJson(
    Map<String, dynamic> json, {
    required int currentUserId,
  }) {
    return OrderHistoryItem(
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      currentUserId: currentUserId,
      restaurantName: json['restaurantName'] as String? ?? '',
      hostName: json['hostName'] as String? ?? '',
      participantCount: parseJsonInt(
        json['participantCount'] ?? 0,
        'participantCount',
      ),
      totalAmount: parseJsonInt(json['totalAmount'] ?? 0, 'totalAmount'),
      myAmount: parseJsonInt(json['myAmount'] ?? 0, 'myAmount'),
      canRate: json['canRate'] as bool? ?? false,
      participants: parseJsonList(
        json['participants'],
        OrderHistoryParticipant.fromJson,
      ),
      rateableParticipants: parseJsonList(
        json['rateableParticipants'],
        OrderHistoryParticipant.fromJson,
      ),
      deliveredAt: parseNullableDateTime(json['deliveredAt']),
      receiptImageUrl: json['receiptImageUrl'] as String?,
    );
  }
}
