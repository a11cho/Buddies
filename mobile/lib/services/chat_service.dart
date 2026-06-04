import 'dart:typed_data';

import '../models/chat_history_response.dart';
import '../models/chat_message.dart';

class ChatImageAttachment {
  const ChatImageAttachment({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final Uint8List bytes;
}

class ChatConnectionInfo {
  const ChatConnectionInfo({
    required this.serverUrl,
    required this.subscribeDestination,
    required this.sendDestination,
    required this.errorDestination,
    this.heartbeatIncoming = 10000,
    this.heartbeatOutgoing = 10000,
  });

  final String serverUrl;
  final String subscribeDestination;
  final String sendDestination;
  final String errorDestination;
  final int heartbeatIncoming;
  final int heartbeatOutgoing;

  factory ChatConnectionInfo.fromServerUrl({
    required int lobbyId,
    required String serverUrl,
  }) {
    return ChatConnectionInfo(
      serverUrl: serverUrl,
      subscribeDestination: '/topic/lobbies/$lobbyId/chat',
      sendDestination: '/app/lobbies/$lobbyId/chat/send',
      errorDestination: '/user/queue/chat-errors',
    );
  }
}

class ChatValidation {
  const ChatValidation._();

  static const maxUserMessageLength = 500;
  static const defaultHistoryLimit = 50;
}

abstract class ChatService {
  Future<ChatConnectionInfo> getConnectionInfo(int lobbyId);

  Stream<ChatMessage> watchMessages(int lobbyId);

  Future<ChatHistoryResponse> getMessages(
    int lobbyId, {
    int limit = ChatValidation.defaultHistoryLimit,
    int? cursor,
  });

  Future<void> sendMessage(int lobbyId, String content);

  Future<void> sendMediaMessage(int lobbyId, String mediaUrl);

  Future<void> sendImageMessage(int lobbyId, ChatImageAttachment attachment);

  Future<void> markAsRead(int lobbyId, int messageId);

  Future<void> disconnect(int lobbyId);
}
