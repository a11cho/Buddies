import '../core/enums.dart';
import 'json_parsing.dart';

// Cart Lock 이후 member별 송금/확인 상태를 나타내는 model입니다.
class PaymentRecord {
  const PaymentRecord({
    required this.paymentRecordId,
    required this.userId,
    required this.amount,
    required this.status,
    this.lobbyId,
    this.confirmedByHostId,
    this.confirmedAt,
  });

  final int paymentRecordId;
  final int? lobbyId;
  final int userId;
  final int amount;
  final String status;
  final int? confirmedByHostId;
  final DateTime? confirmedAt;

  bool get isPaid => status == PaymentStatus.paid;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      paymentRecordId:
          parseJsonInt(json['paymentRecordId'], 'paymentRecordId'),
      lobbyId: parseNullableJsonInt(json['lobbyId'], 'lobbyId'),
      userId: parseJsonInt(json['userId'], 'userId'),
      amount: parseJsonInt(json['amount'], 'amount'),
      status: json['status'] as String? ?? PaymentStatus.unpaid,
      confirmedByHostId:
          parseNullableJsonInt(json['confirmedByHostId'], 'confirmedByHostId'),
      confirmedAt: parseNullableDateTime(json['confirmedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentRecordId': paymentRecordId,
      'lobbyId': lobbyId,
      'userId': userId,
      'amount': amount,
      'status': status,
      'confirmedByHostId': confirmedByHostId,
      'confirmedAt': confirmedAt?.toIso8601String(),
    };
  }
}
