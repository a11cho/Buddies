import 'dart:convert';

import '../core/enums.dart';
import 'json_parsing.dart';

// Lobby 채팅 메시지 model입니다.
// SYSTEM/MEDIA 메시지는 content나 mediaUrl이 null일 수 있어 nullable로 둡니다.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.lobbyId,
    required this.messageType,
    this.senderUserId,
    this.content,
    this.mediaUrl,
    this.createdAt,
    this.eventType,
    this.targetUserId,
    this.eventMetadata = const {},
  });

  final int id;
  final int lobbyId;
  final int? senderUserId;
  final String messageType;
  final String? content;
  final String? mediaUrl;
  final DateTime? createdAt;
  final String? eventType;
  final int? targetUserId;
  final Map<String, Object?> eventMetadata;

  bool get isSystem => messageType == ChatMessageType.system;

  bool get isMedia => messageType == ChatMessageType.media;

  bool isSentBy(int userId) => senderUserId == userId;

  ChatMessage copyWith({
    int? id,
    int? lobbyId,
    int? senderUserId,
    String? messageType,
    String? content,
    String? mediaUrl,
    DateTime? createdAt,
    String? eventType,
    int? targetUserId,
    Map<String, Object?>? eventMetadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      lobbyId: lobbyId ?? this.lobbyId,
      senderUserId: senderUserId ?? this.senderUserId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      eventType: eventType ?? this.eventType,
      targetUserId: targetUserId ?? this.targetUserId,
      eventMetadata: eventMetadata ?? this.eventMetadata,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: parseJsonInt(json['id'], 'id'),
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      senderUserId: parseNullableJsonInt(json['senderUserId'], 'senderUserId'),
      messageType: json['messageType'] as String? ?? ChatMessageType.user,
      content: json['content'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      createdAt: parseNullableDateTime(json['createdAt']),
      eventType: json['eventType'] as String?,
      targetUserId: parseNullableJsonInt(json['targetUserId'], 'targetUserId'),
      eventMetadata: _parseEventMetadata(json['eventMetadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lobbyId': lobbyId,
      'senderUserId': senderUserId,
      'messageType': messageType,
      'content': content,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt?.toIso8601String(),
      'eventType': eventType,
      'targetUserId': targetUserId,
      'eventMetadata': eventMetadata,
    };
  }

  static Map<String, Object?> _parseEventMetadata(Object? value) {
    if (value is String) {
      try {
        return _parseEventMetadata(jsonDecode(value));
      } on FormatException {
        return const {};
      }
    }
    if (value is Map<String, dynamic>) {
      return Map<String, Object?>.from(value);
    }
    if (value is Map) {
      final metadata = <String, Object?>{};
      value.forEach((key, metadataValue) {
        metadata[key.toString()] = metadataValue;
      });
      return metadata;
    }
    return const {};
  }
}
