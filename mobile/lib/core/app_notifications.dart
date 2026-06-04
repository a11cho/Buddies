import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/lobby.dart';
import '../models/user.dart';
import 'app_routes.dart';
import 'service_registry.dart';

final appRouteTracker = AppRouteTracker();

class AppRouteTracker extends NavigatorObserver {
  String? currentRouteName;
  Object? currentArguments;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setCurrentRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setCurrentRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _setCurrentRoute(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _setCurrentRoute(previousRoute);
  }

  void _setCurrentRoute(Route<dynamic>? route) {
    currentRouteName = route?.settings.name;
    currentArguments = route?.settings.arguments;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

class AppNotificationHost extends StatefulWidget {
  const AppNotificationHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  StreamSubscription<ChatMessage>? _messageSubscription;
  Timer? _syncTimer;
  Timer? _notificationDismissTimer;
  late final AnimationController _notificationController;
  late final Animation<Offset> _notificationOffset;
  String? _topNotificationText;
  bool _topNotificationIsSystem = false;
  int _notificationToken = 0;
  int? _subscribedLobbyId;
  int? _currentUserId;
  Lobby? _activeLobby;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _notificationOffset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _notificationController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    appRouteTracker.addListener(_handleRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncActiveLobbySubscription();
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _syncActiveLobbySubscription();
    });
  }

  @override
  void dispose() {
    appRouteTracker.removeListener(_handleRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _removeTopNotification();
    _notificationController.dispose();
    _clearSubscription(disconnect: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncActiveLobbySubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationText = _topNotificationText;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (notificationText != null)
          _TopNotificationBanner(
            offsetAnimation: _notificationOffset,
            text: notificationText,
            isSystem: _topNotificationIsSystem,
          ),
      ],
    );
  }

  void _handleRouteChanged() {
    _syncActiveLobbySubscription();
  }

  Future<void> _syncActiveLobbySubscription() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      final currentUser = await _loadCurrentUser();
      final activeLobby = await AppServices.lobbyService.getMyActiveLobby();
      if (!mounted) {
        return;
      }

      _currentUserId = currentUser.id;
      _activeLobby = activeLobby;
      if (activeLobby == null) {
        _clearSubscription(disconnect: true);
        return;
      }

      if (_subscribedLobbyId == activeLobby.lobbyId &&
          _messageSubscription != null) {
        return;
      }

      _clearSubscription(disconnect: true);
      _activeLobby = activeLobby;
      _subscribedLobbyId = activeLobby.lobbyId;
      _messageSubscription =
          AppServices.chatService.watchMessages(activeLobby.lobbyId).listen(
        _handleMessage,
        onError: (_) {
          // In-app notifications should not interrupt the current screen.
        },
      );
    } catch (_) {
      _clearSubscription(disconnect: true);
    } finally {
      _isSyncing = false;
    }
  }

  Future<User> _loadCurrentUser() async {
    try {
      return await AppServices.userService.getMe();
    } catch (_) {
      return AppServices.authService.getMe();
    }
  }

  void _clearSubscription({required bool disconnect}) {
    final lobbyId = _subscribedLobbyId;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _subscribedLobbyId = null;
    _activeLobby = null;
    if (disconnect && lobbyId != null) {
      unawaited(AppServices.chatService.disconnect(lobbyId));
    }
  }

  void _handleMessage(ChatMessage message) {
    if (!_shouldNotify(message)) {
      return;
    }

    final text = _notificationText(message);
    if (text == null || text.isEmpty) {
      return;
    }

    _showTopNotification(text, isSystem: message.isSystem);
  }

  void _showTopNotification(String text, {required bool isSystem}) {
    if (!mounted) {
      return;
    }

    _notificationDismissTimer?.cancel();
    _notificationToken += 1;
    final token = _notificationToken;

    setState(() {
      _topNotificationText = text;
      _topNotificationIsSystem = isSystem;
    });

    unawaited(_notificationController.forward(from: 0));
    _notificationDismissTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_hideTopNotification(token));
    });
  }

  Future<void> _hideTopNotification(int token) async {
    if (token != _notificationToken || _topNotificationText == null) {
      return;
    }

    await _notificationController.reverse();
    if (mounted && token == _notificationToken) {
      setState(_removeTopNotification);
    }
  }

  void _removeTopNotification() {
    _notificationToken += 1;
    _notificationDismissTimer?.cancel();
    _notificationDismissTimer = null;
    _topNotificationText = null;
  }

  bool _shouldNotify(ChatMessage message) {
    if (message.lobbyId != _subscribedLobbyId) {
      return false;
    }

    final currentUserId = _currentUserId;
    if (currentUserId != null && message.senderUserId == currentUserId) {
      return false;
    }

    final currentRoute = appRouteTracker.currentRouteName;
    final currentArguments = appRouteTracker.currentArguments;
    if (currentRoute == AppRoutes.chat && currentArguments == message.lobbyId) {
      return false;
    }

    return true;
  }

  String? _notificationText(ChatMessage message) {
    if (!message.isSystem) {
      final content = message.content?.trim();
      if (content != null && content.isNotEmpty) {
        return '${_senderName(message.senderUserId)}: $content';
      }
      if (message.isMedia) {
        return '${_senderName(message.senderUserId)} sent a photo.';
      }
      return null;
    }

    return _systemNotificationText(message);
  }

  String _systemNotificationText(ChatMessage message) {
    final metadata = message.eventMetadata;
    final targetName = _metadataText(
          metadata,
          const [
            'targetUserName',
            'targetName',
            'userName',
            'memberName',
            'newHostName',
          ],
        ) ??
        _senderName(message.targetUserId);
    final itemName = _metadataText(
      metadata,
      const ['itemName', 'cartItemName', 'menuName'],
    );
    final previousStatus = metadata['previousStatus']?.toString();
    final nextStatus =
        metadata['nextStatus']?.toString() ?? metadata['status']?.toString();

    switch (message.eventType) {
      case 'lobby.member_joined':
        return '$targetName joined the Lobby.';
      case 'lobby.member_left':
        return '$targetName left the Lobby.';
      case 'lobby.member_kicked':
        return '$targetName was removed from the Lobby.';
      case 'lobby.host_transferred':
        return '$targetName is now the Host.';
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
        return 'Lobby closed. Rating is available.';
      case 'lobby.canceled':
        return 'Lobby canceled.';
      case 'cart.locked':
        return 'Cart locked. Payment records are ready.';
      case 'cart.item_added':
        return '$targetName added ${itemName ?? 'an item'} to the cart.';
      case 'cart.item_updated':
        return '$targetName updated ${itemName ?? 'an item'} in the cart.';
      case 'cart.item_deleted':
        return '$targetName removed ${itemName ?? 'an item'} from the cart.';
      case 'payment.record_updated':
        return '$targetName payment record was updated.';
      default:
        return 'Lobby updated.';
    }
  }

  String _senderName(int? userId) {
    if (userId == null) {
      return 'A member';
    }
    final lobby = _activeLobby;
    if (lobby != null) {
      for (final member in lobby.members) {
        if (member.userId == userId) {
          return member.name;
        }
      }
      if (lobby.hostUserId == userId && lobby.hostName != null) {
        return lobby.hostName!;
      }
    }
    return 'User $userId';
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

class _TopNotificationBanner extends StatelessWidget {
  const _TopNotificationBanner({
    required this.offsetAnimation,
    required this.text,
    required this.isSystem,
  });

  final Animation<Offset> offsetAnimation;
  final String text;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: SlideTransition(
            position: offsetAnimation,
            child: Material(
              elevation: 10,
              shadowColor: Colors.black26,
              color: colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSystem
                          ? Icons.notifications_active_outlined
                          : Icons.chat_bubble_outline,
                      color: colorScheme.inversePrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
