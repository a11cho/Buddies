import '../core/api_client.dart';
import '../models/host_payment_info.dart';
import '../models/order_history_item.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class ApiUserService implements UserService {
  ApiUserService({
    required ApiClient apiClient,
    this.userBasePath = '/api/users',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String userBasePath;

  @override
  Future<User> getMe() async {
    final response = await _apiClient.get('$userBasePath/me');
    return User.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid profile response.',
      ),
    );
  }

  @override
  Future<User> updateMe(UpdateProfileRequest request) async {
    final response = await _apiClient.patch(
      '$userBasePath/me',
      body: request.toJson(),
    );
    return User.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid profile update response.',
      ),
    );
  }

  @override
  Future<HostPaymentInfo?> getPaymentInfo() async {
    try {
      final response = await _apiClient.get('$userBasePath/me/payment-info');
      return HostPaymentInfo.fromJson(
        ApiResponseParser.requireObject(
          response,
          message: 'Invalid payment info response.',
        ),
      );
    } on ApiException catch (error) {
      // 현재 backend에 payment-info endpoint가 없으면 404가 옵니다.
      // 화면에서는 이것을 "등록된 계좌 없음" 상태로 다룹니다.
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<HostPaymentInfo> updatePaymentInfo(
    UpdatePaymentInfoRequest request,
  ) async {
    final response = await _apiClient.patch(
      '$userBasePath/me/payment-info',
      body: request.toJson(),
    );
    return HostPaymentInfo.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid payment info update response.',
      ),
    );
  }

  @override
  Future<List<OrderHistoryItem>> getOrderHistory() async {
    final currentUser = await getMe();
    final response = await _apiClient.get('$userBasePath/me/order-history');
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid order history response.',
    );
    final items = ApiResponseParser.requireList(
      json['items'],
      message: 'Invalid order history items response.',
    );

    return items
        .map(
          (item) => OrderHistoryItem.fromJson(
            item as Map<String, dynamic>,
            currentUserId: currentUser.id,
          ),
        )
        .toList();
  }
}
