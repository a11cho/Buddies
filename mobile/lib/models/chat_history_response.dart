import 'chat_message.dart';
import 'json_parsing.dart';

// GET /lobbies/{lobbyId}/chat/messages 응답 model입니다.
// 메시지 배열뿐 아니라 현재 사용자의 마지막 읽음 메시지 ID도 함께 받습니다.
class ChatHistoryResponse {
  const ChatHistoryResponse({
    required this.messages,
    this.hasMore = false,
    this.lastReadMessageId,
    this.nextCursor,
  });

  final int? lastReadMessageId;
  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextCursor;

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      lastReadMessageId:
          parseNullableJsonInt(json['lastReadMessageId'], 'lastReadMessageId'),
      messages: parseJsonList(json['messages'], ChatMessage.fromJson),
      hasMore: json['hasMore'] as bool? ?? false,
      nextCursor: parseNullableJsonInt(json['nextCursor'], 'nextCursor'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastReadMessageId': lastReadMessageId,
      'messages': messages.map((message) => message.toJson()).toList(),
      'hasMore': hasMore,
      'nextCursor': nextCursor,
    };
  }
}
