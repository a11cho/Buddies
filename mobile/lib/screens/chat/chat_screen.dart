import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/chat_history_response.dart';
import '../../models/chat_message.dart';
import '../../models/lobby.dart';
import '../../models/user.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';

// Lobby 안에서 사용하는 Chat 화면입니다.
// 현재는 MockChatService의 메시지 목록을 사용하고, 이후 WebSocket/STOMP로 교체할 수 있게 service만 호출합니다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Future<_ChatScreenData>? _chatFuture;
  int? _lobbyId;
  bool _isSending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // LobbyDetailScreen에서 Navigator.pushNamed(..., arguments: lobbyId)로 넘긴 값을 읽습니다.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final nextLobbyId = arguments is int ? arguments : null;

    if (_lobbyId != nextLobbyId) {
      _lobbyId = nextLobbyId;
      _chatFuture = nextLobbyId == null ? null : _loadChat(nextLobbyId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ChatScreenData> _loadChat(int lobbyId) async {
    final currentUser = await AppServices.authService.getMe();
    final lobby = await AppServices.lobbyService.getLobbyDetail(lobbyId);
    final canAccessChat = _canAccessChat(lobby, currentUser.id);
    if (!canAccessChat) {
      return _ChatScreenData(
        lobby: lobby,
        currentUser: currentUser,
        lastReadMessageId: null,
        messages: const [],
        canAccessChat: false,
      );
    }

    final history = await AppServices.chatService.getMessages(lobbyId);
    await _markLatestMessageAsRead(lobbyId, history);
    if (mounted) {
      _scrollToBottom();
    }

    return _ChatScreenData(
      lobby: lobby,
      currentUser: currentUser,
      lastReadMessageId: history.lastReadMessageId,
      messages: history.messages,
      canAccessChat: true,
    );
  }

  Future<void> _markLatestMessageAsRead(
    int lobbyId,
    ChatHistoryResponse history,
  ) async {
    final latestMessageId = _latestMessageId(history.messages);
    if (latestMessageId == null) {
      return;
    }
    final lastReadMessageId = history.lastReadMessageId;
    if (lastReadMessageId != null && lastReadMessageId >= latestMessageId) {
      return;
    }
    await AppServices.chatService.markAsRead(lobbyId, latestMessageId);
  }

  void _refreshChat() {
    final lobbyId = _lobbyId;
    if (lobbyId == null) {
      return;
    }
    setState(() {
      _chatFuture = _loadChat(lobbyId);
    });
  }

  Future<void> _sendMessage() async {
    final lobbyId = _lobbyId;
    final content = _messageController.text.trim();
    if (lobbyId == null || content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await AppServices.chatService.sendMessage(lobbyId, content);
      if (!mounted) {
        return;
      }
      _messageController.clear();
      _refreshChat();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatFuture = _chatFuture;

    if (_lobbyId == null || chatFuture == null) {
      return AppScaffold(
        title: 'Chat',
        body: ErrorMessageView(
          message: 'Lobby id가 전달되지 않았습니다.',
          onRetry: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    return AppScaffold(
      title: 'Chat',
      body: FutureBuilder<_ChatScreenData>(
        future: chatFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading chat...');
          }

          if (snapshot.hasError) {
            return ErrorMessageView(
              message: 'Chat 메시지를 불러오지 못했습니다.',
              onRetry: _refreshChat,
            );
          }

          final data = snapshot.data!;
          if (!data.canAccessChat) {
            return ErrorMessageView(
              message: 'Active Lobby member만 Chat을 사용할 수 있습니다.',
              onRetry: _refreshChat,
            );
          }

          return Column(
            children: [
              Expanded(
                child: data.messages.isEmpty
                    ? const EmptyStateView(
                        title: 'No messages yet',
                        message: 'Send the first message in this Lobby.',
                        icon: Icons.chat_bubble_outline,
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: _buildMessageRows(data),
                      ),
              ),
              _ChatInputBar(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMessageRows(_ChatScreenData data) {
    final rows = <Widget>[];
    var unreadDividerInserted = false;

    for (final message in data.messages) {
      final shouldShowUnreadDivider = !unreadDividerInserted &&
          _isUnreadMessage(message, data.lastReadMessageId);
      if (shouldShowUnreadDivider) {
        rows.add(const _UnreadDivider());
        unreadDividerInserted = true;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatMessageBubble(
            messageType: message.messageType,
            isMine: message.isSentBy(data.currentUser.id),
            content: message.content,
            mediaUrl: message.mediaUrl,
            senderName: _memberNameById(data.lobby, message.senderUserId),
          ),
        ),
      );
    }

    return rows;
  }

  bool _isUnreadMessage(ChatMessage message, int? lastReadMessageId) {
    if (lastReadMessageId == null) {
      return true;
    }
    return message.id > lastReadMessageId;
  }

  int? _latestMessageId(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return null;
    }
    return messages
        .map((message) => message.id)
        .reduce((left, right) => left > right ? left : right);
  }

  bool _canAccessChat(Lobby lobby, int currentUserId) {
    final isActiveLobby = lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
    if (!isActiveLobby) {
      return false;
    }
    return lobby.members.any(
      (member) => member.userId == currentUserId && member.isActive,
    );
  }

  String? _memberNameById(Lobby lobby, int? userId) {
    if (userId == null) {
      return null;
    }
    for (final member in lobby.members) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    return 'User $userId';
  }
}

class _ChatScreenData {
  const _ChatScreenData({
    required this.lobby,
    required this.currentUser,
    required this.messages,
    required this.canAccessChat,
    this.lastReadMessageId,
  });

  final Lobby lobby;
  final User currentUser;
  final int? lastReadMessageId;
  final List<ChatMessage> messages;
  final bool canAccessChat;
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Unread messages',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
