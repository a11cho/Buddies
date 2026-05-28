import '../core/enums.dart';
import '../models/chat_history_response.dart';
import '../models/chat_message.dart';
import '../models/lobby.dart';
import '../services/chat_service.dart';
import 'mock_data_store.dart';

class MockChatService implements ChatService {
  MockChatService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<ChatConnectionInfo> getConnectionInfo(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
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
    _ensureCurrentUserIsActiveMember(lobby);
    final messages = List<ChatMessage>.from(_store.findMessages(lobbyId))
      ..sort((left, right) => left.id.compareTo(right.id));
    return ChatHistoryResponse(
      lastReadMessageId: lobby.lastReadMessageId,
      messages: messages,
    );
  }

  @override
  Future<ChatMessage> sendMessage(int lobbyId, String content) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
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
    _ensureCurrentUserIsActiveMember(lobby);
    final messages = _store.findMessages(lobbyId);
    final nextLastReadMessageId =
        _maxReadMessageId(lobby.lastReadMessageId, messageId);
    final unreadCount = messages
        .where((message) => message.id > nextLastReadMessageId)
        .length;
    final readAt = DateTime.now();

    final updatedMembers = lobby.members.map((member) {
      if (member.userId != _store.currentUser.id) {
        return member;
      }
      return member.copyWith(
        lastReadMessageId: nextLastReadMessageId,
        lastReadAt: readAt,
      );
    }).toList();

    _store.replaceLobby(
      lobby.copyWith(
        lastReadMessageId: nextLastReadMessageId,
        unreadCount: unreadCount,
        members: updatedMembers,
      ),
    );
  }

  void _ensureCurrentUserIsActiveMember(Lobby lobby) {
    final isActiveLobby = lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
    if (!isActiveLobby) {
      throw StateError('Chat is only available in active Lobbies.');
    }
    final isActiveMember = lobby.members.any(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
    if (!isActiveMember) {
      throw StateError('Only active Lobby members can use Chat.');
    }
  }

  int _maxReadMessageId(int? currentMessageId, int nextMessageId) {
    if (currentMessageId == null) {
      return nextMessageId;
    }
    return currentMessageId > nextMessageId ? currentMessageId : nextMessageId;
  }
}
