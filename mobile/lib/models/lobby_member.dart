import '../core/enums.dart';
import 'json_parsing.dart';

// Host와 Participant를 모두 포함하는 Lobby member model입니다.
class LobbyMember {
  const LobbyMember({
    required this.userId,
    required this.name,
    required this.roleInLobby,
    required this.membershipStatus,
    this.joinedAt,
    this.leftAt,
    this.lastReadMessageId,
    this.lastReadAt,
  });

  final int userId;
  final String name;
  final String roleInLobby;
  final String membershipStatus;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final int? lastReadMessageId;
  final DateTime? lastReadAt;

  bool get isHost => roleInLobby == RoleInLobby.host;

  bool get isActive => membershipStatus == MembershipStatus.active;

  factory LobbyMember.fromJson(Map<String, dynamic> json) {
    return LobbyMember(
      userId: parseJsonInt(json['userId'], 'userId'),
      name: json['name'] as String? ?? '',
      roleInLobby: json['roleInLobby'] as String? ?? RoleInLobby.participant,
      membershipStatus:
          json['membershipStatus'] as String? ?? MembershipStatus.active,
      joinedAt: parseNullableDateTime(json['joinedAt']),
      leftAt: parseNullableDateTime(json['leftAt']),
      lastReadMessageId:
          parseNullableJsonInt(json['lastReadMessageId'], 'lastReadMessageId'),
      lastReadAt: parseNullableDateTime(json['lastReadAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'roleInLobby': roleInLobby,
      'membershipStatus': membershipStatus,
      'joinedAt': joinedAt?.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'lastReadMessageId': lastReadMessageId,
      'lastReadAt': lastReadAt?.toIso8601String(),
    };
  }
}
