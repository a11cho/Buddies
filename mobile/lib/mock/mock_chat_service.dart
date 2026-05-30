import '../core/enums.dart';
import '../models/chat_history_response.dart';
import '../models/chat_message.dart';
import '../models/lobby.dart';
import '../services/chat_service.dart';
import 'mock_data_store.dart';

class MockChatService implements ChatService {
  MockChatService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  static const _restrictedKeywords = [
    'badword',
    'spamword',
    '욕설금지',
  ];
  static const _rateLimitWindow = Duration(seconds: 10);
  static const _rateLimitMessageCount = 5;

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
  Future<ChatHistoryResponse> getMessages(
    int lobbyId, {
    int limit = ChatValidation.defaultHistoryLimit,
    int? cursor,
  }) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    final messages = List<ChatMessage>.from(_store.findMessages(lobbyId))
      ..sort((left, right) => left.id.compareTo(right.id));
    final page = _pageMessages(messages, limit: limit, cursor: cursor);
    return ChatHistoryResponse(
      lastReadMessageId: lobby.lastReadMessageId,
      messages: page.messages,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<ChatMessage> sendMessage(int lobbyId, String content) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    _validateUserMessage(lobbyId, content);

    final message = ChatMessage(
      id: _store.nextMessageId++,
      lobbyId: lobbyId,
      senderUserId: _store.currentUser.id,
      messageType: ChatMessageType.user,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _store.findMessages(lobbyId).add(message);
    _recordUserMessage(lobbyId);
    await markAsRead(lobbyId, message.id);
    return message;
  }

  @override
  Future<ChatMessage> sendMediaMessage(int lobbyId, String mediaUrl) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    _validateMediaMessage(lobbyId, mediaUrl);

    final message = ChatMessage(
      id: _store.nextMessageId++,
      lobbyId: lobbyId,
      senderUserId: _store.currentUser.id,
      messageType: ChatMessageType.media,
      mediaUrl: mediaUrl.trim(),
      createdAt: DateTime.now(),
    );
    _store.findMessages(lobbyId).add(message);
    _recordUserMessage(lobbyId);
    await markAsRead(lobbyId, message.id);
    return message;
  }

  void _validateUserMessage(int lobbyId, String content) {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw StateError('Message content is required.');
    }
    if (_store.currentUser.status != UserStatus.active) {
      throw StateError('ACCOUNT_RESTRICTED');
    }
    if (trimmedContent.length > ChatValidation.maxUserMessageLength) {
      throw StateError('MESSAGE_TOO_LONG');
    }
    final lowerContent = trimmedContent.toLowerCase();
    final hasRestrictedKeyword = _restrictedKeywords.any(
      (keyword) => lowerContent.contains(keyword.toLowerCase()),
    );
    if (hasRestrictedKeyword) {
      throw StateError('RESTRICTED_KEYWORD');
    }
    if (_isRateLimited(lobbyId)) {
      throw StateError('RATE_LIMITED');
    }
  }

  void _validateMediaMessage(int lobbyId, String mediaUrl) {
    final trimmedMediaUrl = mediaUrl.trim();
    if (trimmedMediaUrl.isEmpty) {
      throw StateError('Media attachment is required.');
    }
    if (_store.currentUser.status != UserStatus.active) {
      throw StateError('ACCOUNT_RESTRICTED');
    }
    if (_isRateLimited(lobbyId)) {
      throw StateError('RATE_LIMITED');
    }
  }

  bool _isRateLimited(int lobbyId) {
    final now = DateTime.now();
    final key = _sendRateLimitKey(lobbyId);
    final timestamps = _store.chatSendTimestampsByLobbyUser.putIfAbsent(
      key,
      () => [],
    );
    timestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );
    return timestamps.length >= _rateLimitMessageCount;
  }

  void _recordUserMessage(int lobbyId) {
    final key = _sendRateLimitKey(lobbyId);
    _store.chatSendTimestampsByLobbyUser.putIfAbsent(key, () => []).add(
          DateTime.now(),
        );
  }

  String _sendRateLimitKey(int lobbyId) {
    return '$lobbyId:${_store.currentUser.id}';
  }

  _MessagePage _pageMessages(
    List<ChatMessage> messages, {
    required int limit,
    int? cursor,
  }) {
    final safeLimit = limit <= 0 ? ChatValidation.defaultHistoryLimit : limit;
    final beforeCursor = cursor == null
        ? messages
        : messages.where((message) => message.id < cursor).toList();
    if (beforeCursor.length <= safeLimit) {
      return _MessagePage(
        messages: beforeCursor,
        hasMore: false,
        nextCursor: beforeCursor.isEmpty ? null : beforeCursor.first.id,
      );
    }

    final page = beforeCursor.sublist(beforeCursor.length - safeLimit);
    return _MessagePage(
      messages: page,
      hasMore: true,
      nextCursor: page.first.id,
    );
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

class _MessagePage {
  const _MessagePage({
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final int? nextCursor;
}
