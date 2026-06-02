import '../models/host_payment_info.dart';
import '../models/order_history_item.dart';
import '../models/user.dart';

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.name,
    this.profileImageUrl,
  });

  final String name;
  final String? profileImageUrl;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'profileImageUrl': profileImageUrl,
    };
  }
}

class UpdatePaymentInfoRequest {
  const UpdatePaymentInfoRequest({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
  });

  final String bankName;
  final String accountNumber;
  final String accountHolderName;

  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
    };
  }
}

// /users/me와 /users/me/payment-info 계열 API를 위한 service입니다.
// AuthService는 로그인/회원가입을 담당하고, UserService는 로그인된 사용자 정보를 담당합니다.
abstract class UserService {
  Future<User> getMe();

  Future<User> updateMe(UpdateProfileRequest request);

  Future<HostPaymentInfo?> getPaymentInfo();

  Future<HostPaymentInfo> updatePaymentInfo(UpdatePaymentInfoRequest request);

  Future<List<OrderHistoryItem>> getOrderHistory();
}
