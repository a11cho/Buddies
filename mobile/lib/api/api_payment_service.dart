import '../core/api_client.dart';
import '../models/payment_record.dart';
import '../services/payment_service.dart';

class ApiPaymentService implements PaymentService {
  ApiPaymentService({
    required ApiClient apiClient,
    this.lobbyBasePath = '/lobbies',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String lobbyBasePath;

  @override
  Future<PaymentRecord> confirmPaymentRecord(
    int lobbyId,
    int paymentRecordId,
  ) async {
    final response = await _apiClient.post(
      '$lobbyBasePath/$lobbyId/payment-records/$paymentRecordId/confirm',
    );
    return PaymentRecord.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid payment record response.',
      ),
    );
  }
}
