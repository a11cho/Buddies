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
    this.trustScore,
  });

  final int userId;
  final String name;
  final String roleInLobby;
  final String membershipStatus;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final int? lastReadMessageId;
  final DateTime? lastReadAt;
  final double? trustScore;

  bool get isHost => roleInLobby == RoleInLobby.host;

  bool get isActive => membershipStatus == MembershipStatus.active;

  LobbyMember copyWith({
    int? userId,
    String? name,
    String? roleInLobby,
    String? membershipStatus,
    DateTime? joinedAt,
    DateTime? leftAt,
    int? lastReadMessageId,
    DateTime? lastReadAt,
    double? trustScore,
  }) {
    return LobbyMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      roleInLobby: roleInLobby ?? this.roleInLobby,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      trustScore: trustScore ?? this.trustScore,
    );
  }

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
      trustScore: _parseTrustScore(json),
    );
  }

  static double? _parseTrustScore(Map<String, dynamic> json) {
    final value = json['trustScore'] ??
        json['rate'] ??
        json['rating'] ??
        json['averageRating'] ??
        json['trust_score'];
    return value == null ? null : parseJsonDouble(value, 'trustScore');
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
      'trustScore': trustScore,
    };
  }
}
