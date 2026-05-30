import 'json_parsing.dart';

// Host가 Participant에게 보여줄 외부 송금 계좌 정보입니다.
class HostPaymentInfo {
  const HostPaymentInfo({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    this.updatedAt,
  });

  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final DateTime? updatedAt;

  bool get isComplete =>
      bankName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty &&
      accountHolderName.trim().isNotEmpty;

  factory HostPaymentInfo.fromJson(Map<String, dynamic> json) {
    return HostPaymentInfo(
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      accountHolderName: json['accountHolderName'] as String? ?? '',
      updatedAt: parseNullableDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
