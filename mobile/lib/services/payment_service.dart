class ConfirmPaymentResult {
  const ConfirmPaymentResult({
    required this.paymentRecordId,
    required this.lobbyId,
    required this.userId,
    required this.amount,
    required this.previousStatus,
    required this.status,
    required this.confirmedByHostId,
    required this.confirmedAt,
    required this.allPaymentsPaid,
  });

  final int paymentRecordId;
  final int lobbyId;
  final int userId;
  final int amount;
  final String previousStatus;
  final String status;
  final int confirmedByHostId;
  final DateTime confirmedAt;
  final bool allPaymentsPaid;
}

abstract class PaymentService {
  Future<ConfirmPaymentResult> confirmPaymentRecord(
    int lobbyId,
    int paymentRecordId,
  );
}
