import '../models/chat_history_response.dart';
import '../models/chat_message.dart';

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
}

abstract class ChatService {
  Future<ChatConnectionInfo> getConnectionInfo(int lobbyId);

  Future<ChatHistoryResponse> getMessages(int lobbyId);

  Future<ChatMessage> sendMessage(int lobbyId, String content);

  Future<void> markAsRead(int lobbyId, int messageId);
}
