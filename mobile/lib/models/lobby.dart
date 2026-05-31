import '../core/enums.dart';
import 'cart_item.dart';
import 'json_parsing.dart';
import 'lobby_member.dart';
import 'payment_record.dart';

// Lobby 목록과 상세 화면에서 공통으로 사용할 model입니다.
// 목록 API에는 members/cartItems/paymentRecords가 없을 수 있어 빈 배열로 처리합니다.
class Lobby {
  const Lobby({
    required this.lobbyId,
    required this.hostUserId,
    required this.restaurantName,
    required this.deliveryZone,
    required this.minimumOrderAmount,
    required this.currentTotalAmount,
    required this.remainingAmount,
    required this.deliveryFee,
    required this.orderStatus,
    required this.members,
    required this.cartItems,
    required this.paymentRecords,
    this.hostName,
    this.hostTrustScore,
    this.hostBankName,
    this.hostAccountNumber,
    this.hostAccountHolderName,
    this.participantCount,
    this.cartLockedAt,
    this.lastReadMessageId,
    this.unreadCount = 0,
  });

  final int lobbyId;
  final int hostUserId;
  final String? hostName;
  final double? hostTrustScore;
  final String? hostBankName;
  final String? hostAccountNumber;
  final String? hostAccountHolderName;
  final String restaurantName;
  final String deliveryZone;
  final int minimumOrderAmount;
  final int currentTotalAmount;
  final int remainingAmount;
  final int deliveryFee;
  final int? participantCount;
  final String orderStatus;
  final DateTime? cartLockedAt;
  final int? lastReadMessageId;
  final int unreadCount;
  final List<LobbyMember> members;
  final List<CartItem> cartItems;
  final List<PaymentRecord> paymentRecords;

  bool get canEditCart =>
      orderStatus == LobbyStatus.waiting && cartLockedAt == null;

  bool get canJoin =>
      orderStatus == LobbyStatus.waiting && cartLockedAt == null;

  bool get allPaymentsPaid =>
      paymentRecords.isNotEmpty &&
      paymentRecords.every((record) => record.isPaid);

  bool get hasHostPaymentInfo =>
      hostBankName?.trim().isNotEmpty == true &&
      hostAccountNumber?.trim().isNotEmpty == true &&
      hostAccountHolderName?.trim().isNotEmpty == true;

  Lobby copyWith({
    int? lobbyId,
    int? hostUserId,
    String? hostName,
    double? hostTrustScore,
    String? hostBankName,
    String? hostAccountNumber,
    String? hostAccountHolderName,
    String? restaurantName,
    String? deliveryZone,
    int? minimumOrderAmount,
    int? currentTotalAmount,
    int? remainingAmount,
    int? deliveryFee,
    int? participantCount,
    String? orderStatus,
    DateTime? cartLockedAt,
    int? lastReadMessageId,
    int? unreadCount,
    List<LobbyMember>? members,
    List<CartItem>? cartItems,
    List<PaymentRecord>? paymentRecords,
  }) {
    return Lobby(
      lobbyId: lobbyId ?? this.lobbyId,
      hostUserId: hostUserId ?? this.hostUserId,
      hostName: hostName ?? this.hostName,
      hostTrustScore: hostTrustScore ?? this.hostTrustScore,
      hostBankName: hostBankName ?? this.hostBankName,
      hostAccountNumber: hostAccountNumber ?? this.hostAccountNumber,
      hostAccountHolderName:
          hostAccountHolderName ?? this.hostAccountHolderName,
      restaurantName: restaurantName ?? this.restaurantName,
      deliveryZone: deliveryZone ?? this.deliveryZone,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      currentTotalAmount: currentTotalAmount ?? this.currentTotalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      participantCount: participantCount ?? this.participantCount,
      orderStatus: orderStatus ?? this.orderStatus,
      cartLockedAt: cartLockedAt ?? this.cartLockedAt,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      unreadCount: unreadCount ?? this.unreadCount,
      members: members ?? this.members,
      cartItems: cartItems ?? this.cartItems,
      paymentRecords: paymentRecords ?? this.paymentRecords,
    );
  }

  factory Lobby.fromJson(Map<String, dynamic> json) {
    final currentTotalAmount =
        parseJsonInt(json['currentTotalAmount'] ?? 0, 'currentTotalAmount');
    final minimumOrderAmount =
        parseJsonInt(json['minimumOrderAmount'] ?? 0, 'minimumOrderAmount');
    final computedRemaining = minimumOrderAmount - currentTotalAmount;

    return Lobby(
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      hostUserId: parseJsonInt(json['hostUserId'], 'hostUserId'),
      hostName: json['hostName'] as String?,
      hostTrustScore: json['hostTrustScore'] == null
          ? null
          : parseJsonDouble(json['hostTrustScore'], 'hostTrustScore'),
      hostBankName: json['hostBankName'] as String?,
      hostAccountNumber: json['hostAccountNumber'] as String?,
      hostAccountHolderName: json['hostAccountHolderName'] as String?,
      restaurantName: json['restaurantName'] as String? ?? '',
      deliveryZone: json['deliveryZone'] as String? ?? '',
      minimumOrderAmount: minimumOrderAmount,
      currentTotalAmount: currentTotalAmount,
      remainingAmount:
          parseNullableJsonInt(json['remainingAmount'], 'remainingAmount') ??
              (computedRemaining > 0 ? computedRemaining : 0),
      deliveryFee: parseJsonInt(json['deliveryFee'] ?? 0, 'deliveryFee'),
      participantCount:
          parseNullableJsonInt(json['participantCount'], 'participantCount'),
      orderStatus: json['orderStatus'] as String? ?? LobbyStatus.waiting,
      cartLockedAt: parseNullableDateTime(json['cartLockedAt']),
      lastReadMessageId:
          parseNullableJsonInt(json['lastReadMessageId'], 'lastReadMessageId'),
      unreadCount: parseJsonInt(json['unreadCount'] ?? 0, 'unreadCount'),
      members: parseJsonList(json['members'], LobbyMember.fromJson),
      cartItems: parseJsonList(json['cartItems'], CartItem.fromJson),
      paymentRecords:
          parseJsonList(json['paymentRecords'], PaymentRecord.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lobbyId': lobbyId,
      'hostUserId': hostUserId,
      'hostName': hostName,
      'hostTrustScore': hostTrustScore,
      'hostBankName': hostBankName,
      'hostAccountNumber': hostAccountNumber,
      'hostAccountHolderName': hostAccountHolderName,
      'restaurantName': restaurantName,
      'deliveryZone': deliveryZone,
      'minimumOrderAmount': minimumOrderAmount,
      'currentTotalAmount': currentTotalAmount,
      'remainingAmount': remainingAmount,
      'deliveryFee': deliveryFee,
      'participantCount': participantCount,
      'orderStatus': orderStatus,
      'cartLockedAt': cartLockedAt?.toIso8601String(),
      'lastReadMessageId': lastReadMessageId,
      'unreadCount': unreadCount,
      'members': members.map((member) => member.toJson()).toList(),
      'cartItems': cartItems.map((item) => item.toJson()).toList(),
      'paymentRecords':
          paymentRecords.map((record) => record.toJson()).toList(),
    };
  }
}
