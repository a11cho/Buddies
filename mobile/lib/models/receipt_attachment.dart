import 'json_parsing.dart';

class ReceiptAttachment {
  const ReceiptAttachment({
    required this.lobbyId,
    required this.receiptImageUrl,
    required this.uploadedByUserId,
    this.uploadedAt,
  });

  final int lobbyId;
  final String receiptImageUrl;
  final int uploadedByUserId;
  final DateTime? uploadedAt;

  factory ReceiptAttachment.fromJson(Map<String, dynamic> json) {
    return ReceiptAttachment(
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      receiptImageUrl: json['receiptImageUrl'] as String? ?? '',
      uploadedByUserId: parseJsonInt(
        json['uploadedByUserId'] ?? 0,
        'uploadedByUserId',
      ),
      uploadedAt: parseNullableDateTime(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lobbyId': lobbyId,
      'receiptImageUrl': receiptImageUrl,
      'uploadedByUserId': uploadedByUserId,
      'uploadedAt': uploadedAt?.toIso8601String(),
    };
  }
}
