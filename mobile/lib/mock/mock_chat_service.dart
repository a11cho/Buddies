import '../models/chat_history_response.dart';
import '../models/chat_message.dart';
import '../core/enums.dart';
import '../services/chat_service.dart';
import 'mock_data_store.dart';

class MockChatService implements ChatService {
  MockChatService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<ChatConnectionInfo> getConnectionInfo(int lobbyId) async {
    return ChatConnectionInfo(
      serverUrl: 'ws://localhost:8080/ws',
      subscribeDestination: '/topic/lobbies/$lobbyId/chat',
      sendDestination: '/app/lobbies/$lobbyId/chat/send',
      errorDestination: '/user/queue/chat-errors',
    );
  }

  @override
  Future<ChatHistoryResponse> getMessages(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    return ChatHistoryResponse(
      lastReadMessageId: lobby.lastReadMessageId,
      messages: List<ChatMessage>.from(_store.findMessages(lobbyId)),
    );
  }

  @override
  Future<ChatMessage> sendMessage(int lobbyId, String content) async {
    if (content.trim().isEmpty) {
      throw StateError('Message content is required.');
    }

    final message = ChatMessage(
      id: _store.nextMessageId++,
      lobbyId: lobbyId,
      senderUserId: _store.currentUser.id,
      messageType: ChatMessageType.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _store.findMessages(lobbyId).add(message);
    await markAsRead(lobbyId, message.id);
    return message;
  }

  @override
  Future<void> markAsRead(int lobbyId, int messageId) async {
    final lobby = _store.findLobby(lobbyId);
    final messages = _store.findMessages(lobbyId);
    final unreadCount =
        messages.where((message) => message.id > messageId).length;
    final readAt = DateTime.now();

    final updatedMembers = lobby.members.map((member) {
      if (member.userId != _store.currentUser.id) {
        return member;
      }
      return member.copyWith(
        lastReadMessageId: messageId,
        lastReadAt: readAt,
      );
    }).toList();

    _store.replaceLobby(
      lobby.copyWith(
        lastReadMessageId: messageId,
        unreadCount: unreadCount,
        members: updatedMembers,
      ),
    );
  }
}
