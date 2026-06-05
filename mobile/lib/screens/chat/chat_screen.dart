import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/chat_history_response.dart';
import '../../models/chat_message.dart';
import '../../models/lobby.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../report/report_dialog.dart';

// Lobby 안에서 사용하는 Chat 화면입니다.
// REST로 이전 메시지를 읽고, ChatService stream으로 새 메시지를 받아 화면에 반영합니다.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Future<_ChatScreenData>? _chatFuture;
  _ChatScreenData? _chatData;
  int? _lobbyId;
  StreamSubscription<ChatMessage>? _messageSubscription;
  int? _subscribedLobbyId;
  bool _isSending = false;
  bool _isLoadingOlderMessages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // LobbyDetailScreen에서 Navigator.pushNamed(..., arguments: lobbyId)로 넘긴 값을 읽습니다.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final nextLobbyId = arguments is int ? arguments : null;

    if (_lobbyId != nextLobbyId) {
      _lobbyId = nextLobbyId;
      _chatData = null;
      _chatFuture = nextLobbyId == null ? null : _loadChat(nextLobbyId);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
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
    _subscribeToMessages(lobbyId);
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
      hasMore: history.hasMore,
      nextCursor: history.nextCursor,
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
      _chatData = null;
      _chatFuture = _loadChat(lobbyId);
    });
  }

  Future<void> _sendMessage() async {
    final lobbyId = _lobbyId;
    final currentData = _chatData;
    final content = _messageController.text.trim();
    if (lobbyId == null || content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await AppServices.chatService.sendMessage(
        lobbyId,
        content,
      );
      if (!mounted) {
        return;
      }
      _messageController.clear();
      if (currentData == null) {
        _refreshChat();
      }
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

  Future<void> _attachMedia() async {
    final lobbyId = _lobbyId;
    if (lobbyId == null || _isSending) {
      return;
    }

    final source = await _chooseImageSource();
    if (source == null || !mounted) {
      return;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (pickedImage == null || !mounted) {
      return;
    }

    final attachment = await _attachmentFromPickedImage(pickedImage);
    if (attachment == null || !mounted) {
      return;
    }

    final currentData = _chatData;
    setState(() {
      _isSending = true;
    });

    try {
      await AppServices.chatService.sendImageMessage(
        lobbyId,
        attachment,
      );
      if (!mounted) {
        return;
      }
      if (currentData == null) {
        _refreshChat();
      }
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

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Photo Library'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_camera_outlined),
                  ),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<ChatImageAttachment?> _attachmentFromPickedImage(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be 5 MB or smaller.')),
        );
      }
      return null;
    }

    final contentType = image.mimeType ?? _inferImageContentType(image.name);
    if (contentType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPEG, PNG, GIF, or WebP images are supported.'),
          ),
        );
      }
      return null;
    }

    return ChatImageAttachment(
      filename: image.name.isEmpty ? 'chat-image.jpg' : image.name,
      contentType: contentType,
      bytes: bytes,
    );
  }

  String? _inferImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _loadOlderMessages(_ChatScreenData data) async {
    final cursor = data.nextCursor;
    if (cursor == null || _isLoadingOlderMessages) {
      return;
    }

    setState(() {
      _isLoadingOlderMessages = true;
    });

    try {
      final history = await AppServices.chatService.getMessages(
        data.lobby.lobbyId,
        cursor: cursor,
      );
      if (!mounted) {
        return;
      }
      final mergedMessages = _mergeMessages(
        olderMessages: history.messages,
        currentMessages: data.messages,
      );
      final nextData = data.copyWith(
        messages: mergedMessages,
        hasMore: history.hasMore,
        nextCursor: history.nextCursor,
      );
      setState(() {
        _chatData = nextData;
        _chatFuture = SynchronousFuture(nextData);
      });
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
          _isLoadingOlderMessages = false;
        });
      }
    }
  }

  List<ChatMessage> _mergeMessages({
    required List<ChatMessage> olderMessages,
    required List<ChatMessage> currentMessages,
  }) {
    final messagesById = <int, ChatMessage>{};
    for (final message in [...olderMessages, ...currentMessages]) {
      messagesById[message.id] = message;
    }
    return messagesById.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
  }

  void _subscribeToMessages(int lobbyId) {
    if (_subscribedLobbyId == lobbyId && _messageSubscription != null) {
      return;
    }
    _messageSubscription?.cancel();
    _subscribedLobbyId = lobbyId;
    _messageSubscription =
        AppServices.chatService.watchMessages(lobbyId).listen(
      _handleIncomingMessage,
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      },
    );
  }

  void _handleIncomingMessage(ChatMessage message) {
    if (!mounted || message.lobbyId != _lobbyId) {
      return;
    }
    final currentData = _chatData;
    if (currentData == null) {
      _refreshChat();
      return;
    }

    final nextMessages = _mergeMessages(
      olderMessages: currentData.messages,
      currentMessages: [message],
    );
    final latestMessageId = _latestMessageId(nextMessages);
    final nextData = currentData.copyWith(
      messages: nextMessages,
      lastReadMessageId: latestMessageId ?? currentData.lastReadMessageId,
    );
    setState(() {
      _chatData = nextData;
      _chatFuture = SynchronousFuture(nextData);
    });
    if (latestMessageId != null) {
      unawaited(
          AppServices.chatService.markAsRead(message.lobbyId, latestMessageId));
    }
    _scrollToBottom();
  }

  Future<void> _reportMessage(_ChatScreenData data, ChatMessage message) async {
    final reportedUserId = message.senderUserId;
    if (reportedUserId == null) {
      return;
    }

    final didSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ReportDialog(
          lobbyId: data.lobby.lobbyId,
          reportedUserId: reportedUserId,
          reportedUserName: _memberNameById(data.lobby, reportedUserId) ??
              'User $reportedUserId',
          reportedMessageId: message.id,
          messagePreview: message.content ?? message.mediaUrl,
        );
      },
    );
    if (!mounted || didSubmit != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
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
          _chatData = data;
          if (!data.canAccessChat) {
            return ErrorMessageView(
              message: 'Active Lobby member만 Chat을 사용할 수 있습니다.',
              onRetry: _refreshChat,
            );
          }

          return DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF5F5FA)),
            child: Column(
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
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          children: _buildMessageRows(data),
                        ),
                ),
                _ChatInputBar(
                  controller: _messageController,
                  isSending: _isSending,
                  onAttachMedia: _attachMedia,
                  onSend: _sendMessage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMessageRows(_ChatScreenData data) {
    final rows = <Widget>[];
    var unreadDividerInserted = false;

    if (data.hasMore) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            onPressed:
                _isLoadingOlderMessages ? null : () => _loadOlderMessages(data),
            icon: _isLoadingOlderMessages
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history),
            label: const Text('Load older messages'),
          ),
        ),
      );
    }

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
          child: _MessageRow(
            message: message,
            currentUser: data.currentUser,
            senderName: _memberNameById(data.lobby, message.senderUserId),
            displayContent: _displayContentForMessage(data.lobby, message),
            onReport: () => _reportMessage(data, message),
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

  String? _displayContentForMessage(Lobby lobby, ChatMessage message) {
    if (!message.isSystem) {
      return message.content;
    }

    final content = message.content?.trim();
    if (content != null && content.isNotEmpty) {
      return content;
    }

    return _systemEventContent(lobby, message);
  }

  String _systemEventContent(Lobby lobby, ChatMessage message) {
    final metadata = message.eventMetadata;
    final targetName = _systemEventTargetName(lobby, message, metadata);
    final itemName = _metadataText(
      metadata,
      const ['itemName', 'cartItemName', 'menuName'],
    );
    final previousStatus = metadata['previousStatus']?.toString();
    final nextStatus =
        metadata['nextStatus']?.toString() ?? metadata['status']?.toString();

    switch (message.eventType) {
      case 'lobby.member_joined':
        return '${targetName ?? 'A member'} joined the Lobby.';
      case 'lobby.member_left':
        return '${targetName ?? 'A member'} left the Lobby.';
      case 'lobby.member_kicked':
        return '${targetName ?? 'A member'} was removed from the Lobby.';
      case 'lobby.host_transferred':
        return '${targetName ?? 'A member'} is now the Host.';
      case 'lobby.status_updated':
        if (previousStatus != null && nextStatus != null) {
          return 'Lobby status changed from '
              '${_formatStatus(previousStatus)} to ${_formatStatus(nextStatus)}.';
        }
        if (nextStatus != null) {
          return 'Lobby status changed to ${_formatStatus(nextStatus)}.';
        }
        return 'Lobby status changed.';
      case 'lobby.closed':
        return 'Lobby closed.';
      case 'lobby.canceled':
        return 'Lobby canceled.';
      case 'cart.locked':
        return 'Cart locked. Payment records are ready.';
      case 'cart.item_added':
        return '${targetName ?? 'A member'} added '
            '${itemName ?? 'an item'} to the cart.';
      case 'cart.item_updated':
        return '${targetName ?? 'A member'} updated '
            '${itemName ?? 'an item'} in the cart.';
      case 'cart.item_deleted':
        return '${targetName ?? 'A member'} removed '
            '${itemName ?? 'an item'} from the cart.';
      case 'payment.record_updated':
        return '${targetName ?? 'A member'} payment record was updated.';
      case 'receipt.attached':
        return '${targetName ?? 'The host'} attached the receipt.';
      default:
        return 'Lobby updated.';
    }
  }

  String? _systemEventTargetName(
    Lobby lobby,
    ChatMessage message,
    Map<String, Object?> metadata,
  ) {
    return _metadataText(
          metadata,
          const [
            'targetUserName',
            'targetName',
            'userName',
            'memberName',
            'newHostName',
          ],
        ) ??
        _memberNameById(lobby, message.targetUserId);
  }

  String? _metadataText(Map<String, Object?> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String _formatStatus(String value) {
    return value
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.currentUser,
    required this.displayContent,
    required this.onReport,
    this.senderName,
  });

  final ChatMessage message;
  final User currentUser;
  final String? displayContent;
  final String? senderName;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isSentBy(currentUser.id);
    final canReport =
        message.senderUserId != null && !isMine && !message.isSystem;

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: canReport
              ? () {
                  _showMessageActions(context);
                }
              : null,
          child: ChatMessageBubble(
            messageType: message.messageType,
            isMine: isMine,
            content: displayContent,
            mediaUrl: message.mediaUrl,
            senderName: senderName,
          ),
        ),
      ],
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report message'),
            onTap: () {
              Navigator.pop(context);
              onReport();
            },
          ),
        );
      },
    );
  }
}

class _ChatScreenData {
  const _ChatScreenData({
    required this.lobby,
    required this.currentUser,
    required this.messages,
    required this.canAccessChat,
    this.hasMore = false,
    this.lastReadMessageId,
    this.nextCursor,
  });

  final Lobby lobby;
  final User currentUser;
  final int? lastReadMessageId;
  final List<ChatMessage> messages;
  final bool canAccessChat;
  final bool hasMore;
  final int? nextCursor;

  _ChatScreenData copyWith({
    Lobby? lobby,
    User? currentUser,
    int? lastReadMessageId,
    List<ChatMessage>? messages,
    bool? canAccessChat,
    bool? hasMore,
    int? nextCursor,
  }) {
    return _ChatScreenData(
      lobby: lobby ?? this.lobby,
      currentUser: currentUser ?? this.currentUser,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      messages: messages ?? this.messages,
      canAccessChat: canAccessChat ?? this.canAccessChat,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
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
    required this.onAttachMedia,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onAttachMedia;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Attach photo',
              onPressed: isSending ? null : onAttachMedia,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEEEEEE),
                foregroundColor: colorScheme.onSurfaceVariant,
                fixedSize: const Size.square(38),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.photo_library_outlined),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: ChatValidation.maxUserMessageLength,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: const Color(0xFFEEEEEE),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  isDense: true,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isSending
                    ? null
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF0054FF).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: IconButton.filled(
                tooltip: 'Send',
                onPressed: isSending ? null : onSend,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0054FF),
                  fixedSize: const Size.square(38),
                  padding: EdgeInsets.zero,
                ),
                icon: isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
