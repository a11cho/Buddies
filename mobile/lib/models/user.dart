import '../core/enums.dart';
import 'json_parsing.dart';

// 로그인한 사용자 또는 Lobby member와 연결되는 사용자 model입니다.
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.trustScore,
    required this.status,
    this.profileImageUrl,
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final String? profileImageUrl;
  final double trustScore;
  final String status;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: parseJsonInt(json['id'] ?? json['userId'], 'id'),
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      trustScore: parseJsonDouble(json['trustScore'], 'trustScore'),
      status: json['status'] as String? ?? UserStatus.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'trustScore': trustScore,
      'status': status,
    };
  }
}
