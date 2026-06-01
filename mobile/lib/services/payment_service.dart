import '../models/payment_record.dart';

abstract class PaymentService {
  Future<PaymentRecord> confirmPaymentRecord(
    int lobbyId,
    int paymentRecordId,
  );
}
