import '../models/order_history_item.dart';
import '../models/user.dart';

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.name,
    this.profileImageUrl,
  });

  final String name;
  final String? profileImageUrl;
}

// /users/me 계열 API를 위한 service입니다.
// AuthService는 로그인/회원가입을 담당하고, UserService는 로그인된 사용자 정보를 담당합니다.
abstract class UserService {
  Future<User> getMe();

  Future<User> updateMe(UpdateProfileRequest request);

  Future<List<OrderHistoryItem>> getOrderHistory();
}
