import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/cart_item.dart';
import '../../models/lobby.dart';
import '../../models/lobby_member.dart';
import '../../models/user.dart';
import '../../services/cart_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/payment_record_tile.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_card.dart';
import '../cart/cart_item_form_dialog.dart';

// Lobby 상세 화면입니다.
// CartItem 편집, Cart Lock, 결제 확인, Lobby 상태 전환을 함께 제공합니다.
class LobbyDetailScreen extends StatefulWidget {
  const LobbyDetailScreen({super.key});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  Future<_LobbyDetailData>? _detailFuture;
  _LobbyDetailData? _cachedDetailData;
  int? _lobbyId;
  bool _isJoining = false;
  bool _isLeavingLobby = false;
  bool _isCancelingLobby = false;
  bool _isLockingCart = false;
  bool _isUpdatingStatus = false;
  int? _confirmingPaymentRecordId;
  int? _kickingUserId;
  int? _transferringHostUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Navigator.pushNamed(..., arguments: lobbyId)로 받은 값을 읽습니다.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final nextLobbyId = arguments is int ? arguments : null;

    if (_lobbyId != nextLobbyId) {
      _lobbyId = nextLobbyId;
      _cachedDetailData = null;
      _detailFuture = nextLobbyId == null ? null : _loadDetail(nextLobbyId);
    }
  }

  Future<_LobbyDetailData> _loadDetail(int lobbyId) async {
    final user = await AppServices.authService.getMe();
    final lobby = await AppServices.lobbyService.getLobbyDetail(lobbyId);
    final allLobbies = await AppServices.lobbyService.getLobbies();
    final isInActiveLobby = allLobbies.any(
      (candidate) => _isCurrentUserInActiveLobby(candidate, user.id),
    );
    final data = _LobbyDetailData(
      lobby: lobby,
      currentUser: user,
      isInActiveLobby: isInActiveLobby,
    );
    _cachedDetailData = data;
    return data;
  }

  void _refreshDetail() {
    final lobbyId = _lobbyId;
    if (lobbyId == null) {
      return;
    }
    setState(() {
      _detailFuture = _loadDetail(lobbyId);
    });
  }

  Future<void> _openChat(Lobby lobby) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: lobby.lobbyId,
    );
    if (!mounted) {
      return;
    }
    _refreshDetail();
  }

  Future<void> _joinLobby(Lobby lobby) async {
    setState(() {
      _isJoining = true;
    });

    try {
      await AppServices.lobbyService.joinLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${lobby.restaurantName}.')),
      );
      _refreshDetail();
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
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _leaveLobby(Lobby lobby) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave Lobby'),
          content: const Text(
            'Leave this Lobby? Your cart items will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (shouldLeave != true) {
      return;
    }

    setState(() {
      _isLeavingLobby = true;
    });

    var didExitScreen = false;
    try {
      await AppServices.lobbyService.leaveLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${lobby.restaurantName}.')),
      );
      Navigator.pop(context, true);
      didExitScreen = true;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _isLeavingLobby = false;
        });
      }
    }
  }

  Future<void> _cancelLobby(Lobby lobby) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Lobby'),
          content: const Text(
            'Cancel this Lobby? Members will no longer be able to order here.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Cancel Lobby'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isCancelingLobby = true;
    });

    var didExitScreen = false;
    try {
      await AppServices.lobbyService.cancelLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Canceled ${lobby.restaurantName}.')),
      );
      Navigator.pop(context, true);
      didExitScreen = true;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted && !didExitScreen) {
        setState(() {
          _isCancelingLobby = false;
        });
      }
    }
  }

  Future<void> _addCartItem(Lobby lobby) async {
    final request = await showDialog<CartItemRequest>(
      context: context,
      builder: (context) => const CartItemFormDialog(),
    );
    if (request == null) {
      return;
    }

    try {
      await AppServices.cartService.addCartItem(lobby.lobbyId, request);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item added.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _editCartItem(Lobby lobby, CartItem item) async {
    final request = await showDialog<CartItemRequest>(
      context: context,
      builder: (context) => CartItemFormDialog(initialItem: item),
    );
    if (request == null) {
      return;
    }

    try {
      await AppServices.cartService.updateCartItem(
        lobby.lobbyId,
        item.cartItemId,
        request,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item updated.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteCartItem(Lobby lobby, CartItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete ${item.itemName}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await AppServices.cartService.deleteCartItem(
        lobby.lobbyId,
        item.cartItemId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart item deleted.')),
      );
      _refreshDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _lockCart(Lobby lobby) async {
    setState(() {
      _isLockingCart = true;
    });

    try {
      await AppServices.cartService.lockCart(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart locked.')),
      );
      _refreshDetail();
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
          _isLockingCart = false;
        });
      }
    }
  }

  Future<void> _kickMember(Lobby lobby, LobbyMember member) async {
    final shouldKick = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kick participant'),
          content: Text(
            'Kick ${member.name}? Their cart items will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Kick'),
            ),
          ],
        );
      },
    );
    if (shouldKick != true) {
      return;
    }

    setState(() {
      _kickingUserId = member.userId;
    });

    try {
      await AppServices.lobbyService.kickMember(lobby.lobbyId, member.userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} was kicked.')),
      );
      _refreshDetail();
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
          _kickingUserId = null;
        });
      }
    }
  }

  Future<void> _transferHost(Lobby lobby, LobbyMember member) async {
    final shouldTransfer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Transfer Host'),
          content: Text('Transfer Host role to ${member.name}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
    if (shouldTransfer != true) {
      return;
    }

    setState(() {
      _transferringHostUserId = member.userId;
    });

    try {
      await AppServices.lobbyService.transferHost(lobby.lobbyId, member.userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} is now the Host.')),
      );
      _refreshDetail();
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
          _transferringHostUserId = null;
        });
      }
    }
  }

  Future<void> _confirmPaymentRecord(Lobby lobby, int paymentRecordId) async {
    setState(() {
      _confirmingPaymentRecordId = paymentRecordId;
    });

    try {
      final result = await AppServices.paymentService.confirmPaymentRecord(
        lobby.lobbyId,
        paymentRecordId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.allPaymentsPaid
                ? 'Payment confirmed. All payments are paid.'
                : 'Payment confirmed.',
          ),
        ),
      );
      _refreshDetail();
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
          _confirmingPaymentRecordId = null;
        });
      }
    }
  }

  Future<void> _updateLobbyStatus(Lobby lobby, String newStatus) async {
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await AppServices.lobbyService.updateLobbyStatus(
        lobby.lobbyId,
        newStatus,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lobby status changed to $newStatus.')),
      );
      _refreshDetail();
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
          _isUpdatingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailFuture = _detailFuture;

    if (_lobbyId == null || detailFuture == null) {
      return AppScaffold(
        title: 'Lobby Detail',
        body: ErrorMessageView(
          message: 'Lobby id가 전달되지 않았습니다.',
          onRetry: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    return AppScaffold(
      title: 'Lobby Detail',
      body: FutureBuilder<_LobbyDetailData>(
        future: detailFuture,
        initialData: _cachedDetailData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingView(message: 'Loading lobby...');
          }

          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorMessageView(
              message: 'Lobby 상세 정보를 불러오지 못했습니다.',
              onRetry: _refreshDetail,
            );
          }

          final data = snapshot.data!;
          final lobby = data.lobby;
          final isMember = _isActiveMember(lobby, data.currentUser.id);
          final canJoin = lobby.canJoin && !isMember && !data.isInActiveLobby;
          final showJoinAction = lobby.canJoin && !isMember;
          final joinDisabledReason = showJoinAction && data.isInActiveLobby
              ? 'Already in a lobby'
              : null;
          final isHost = lobby.hostUserId == data.currentUser.id;
          final visibleMembers = _visibleMembers(lobby);
          final canLeaveLobby =
              isMember && !isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canCancelLobby =
              isMember && isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canEditCart = isMember && lobby.canEditCart;
          final shouldShowLockCart =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canKickMembers =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canTransferHost =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final memberActionInProgress =
              _kickingUserId != null || _transferringHostUserId != null;
          final canLockCart =
              shouldShowLockCart &&
              lobby.currentTotalAmount >= lobby.minimumOrderAmount;
          final lockDisabledReason = shouldShowLockCart && !canLockCart
              ? 'Minimum order amount has not been reached.'
              : null;
          final statusAction = _statusActionFor(lobby);

          return ListView(
            key: PageStorageKey<String>('lobby-detail-${lobby.lobbyId}'),
            padding: const EdgeInsets.all(16),
            children: [
              if (isMember)
                const _MyLobbyBanner(),
              StatusCard(title: 'Restaurant', value: lobby.restaurantName),
              StatusCard(
                title: 'Host',
                value: lobby.hostName ?? 'User ${lobby.hostUserId}',
              ),
              StatusCard(title: 'Delivery Zone', value: lobby.deliveryZone),
              StatusCard(title: 'Status', value: lobby.orderStatus),
              StatusCard(
                title: 'Order Total',
                value:
                    '${lobby.currentTotalAmount} / ${lobby.minimumOrderAmount}',
              ),
              StatusCard(
                title: 'Remaining Amount',
                value: '${lobby.remainingAmount}',
              ),
              StatusCard(
                title: 'Delivery Fee',
                value: '${lobby.deliveryFee}',
              ),
              if (isMember && lobby.unreadCount > 0)
                StatusCard(
                  title: 'Unread Chat',
                  value: '${lobby.unreadCount}',
                ),
              if (isMember) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openChat(lobby),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    lobby.unreadCount > 0
                        ? 'Open Chat (${lobby.unreadCount})'
                        : 'Open Chat',
                  ),
                ),
              ],
              if (canLeaveLobby || canCancelLobby) ...[
                const SizedBox(height: 8),
                _ExitLobbyAction(
                  label: canCancelLobby ? 'Cancel Lobby' : 'Leave Lobby',
                  icon: canCancelLobby
                      ? Icons.cancel_outlined
                      : Icons.logout_outlined,
                  isLoading: canCancelLobby
                      ? _isCancelingLobby
                      : _isLeavingLobby,
                  onPressed: canCancelLobby
                      ? () => _cancelLobby(lobby)
                      : () => _leaveLobby(lobby),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (visibleMembers.isEmpty)
                const _MutedText('No active members.')
              else
                for (final member in visibleMembers)
                  _MemberRow(
                    member: member,
                    canKick: canKickMembers &&
                        !member.isHost &&
                        !memberActionInProgress,
                    isKicking: _kickingUserId == member.userId,
                    canTransferHost: canTransferHost &&
                        !member.isHost &&
                        !memberActionInProgress,
                    isTransferringHost:
                        _transferringHostUserId == member.userId,
                    onKick: () => _kickMember(lobby, member),
                    onTransferHost: () => _transferHost(lobby, member),
                  ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'Cart Items',
                action: canEditCart
                    ? OutlinedButton.icon(
                        onPressed: () => _addCartItem(lobby),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              if (lobby.cartItems.isEmpty)
                const _MutedText('No cart items yet.')
              else
                for (final item in lobby.cartItems)
                  CartItemTile(
                    itemName: item.itemName,
                    unitPrice: item.unitPrice,
                    quantity: item.quantity,
                    subtotal: item.subtotal,
                    ownerName: _memberNameById(lobby, item.ownerUserId),
                    canEdit:
                        canEditCart && item.isOwnedBy(data.currentUser.id),
                    onEdit: () => _editCartItem(lobby, item),
                    onDelete: () => _deleteCartItem(lobby, item),
                  ),
              if (isMember && !lobby.canEditCart) ...[
                const SizedBox(height: 8),
                const _MutedText('Cart editing is unavailable after lock.'),
              ],
              if (shouldShowLockCart) ...[
                const SizedBox(height: 16),
                _LockCartAction(
                  canLock: canLockCart,
                  disabledReason: lockDisabledReason,
                  isLoading: _isLockingCart,
                  onLock: () => _lockCart(lobby),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Payment Records'),
              const SizedBox(height: 8),
              if (lobby.paymentRecords.isEmpty)
                const _MutedText('Payment records will appear after cart lock.')
              else
                for (final record in lobby.paymentRecords)
                  PaymentRecordTile(
                    userName: _memberNameById(lobby, record.userId),
                    amount: record.amount,
                    status: record.status,
                    canConfirm: isHost &&
                        lobby.orderStatus == LobbyStatus.locked &&
                        !record.isPaid &&
                        _confirmingPaymentRecordId == null,
                    onConfirm: () => _confirmPaymentRecord(
                      lobby,
                      record.paymentRecordId,
                    ),
                  ),
              if (isHost && statusAction != null) ...[
                const SizedBox(height: 16),
                _LobbyStatusAction(
                  action: statusAction,
                  isLoading: _isUpdatingStatus,
                  onPressed: () => _updateLobbyStatus(
                    lobby,
                    statusAction.nextStatus,
                  ),
                ),
              ],
              if (showJoinAction) ...[
                const SizedBox(height: 16),
                _JoinLobbyAction(
                  canJoin: canJoin,
                  disabledReason: joinDisabledReason,
                  isLoading: _isJoining,
                  onJoin: () => _joinLobby(lobby),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  bool _isActiveMember(Lobby lobby, int currentUserId) {
    return lobby.members.any(
      (member) => member.userId == currentUserId && member.isActive,
    );
  }

  bool _isCurrentUserInActiveLobby(Lobby lobby, int currentUserId) {
    final isActiveStatus = lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
    if (!isActiveStatus) {
      return false;
    }
    return _isActiveMember(lobby, currentUserId);
  }

  List<LobbyMember> _visibleMembers(Lobby lobby) {
    // LEFT/KICKED member는 서버 기록으로는 남을 수 있지만, 화면에는 현재 참여자만 보여줍니다.
    final members = lobby.members.where((member) => member.isActive).toList();
    members.sort((first, second) {
      final firstIsHost = first.isHost || first.userId == lobby.hostUserId;
      final secondIsHost = second.isHost || second.userId == lobby.hostUserId;
      if (firstIsHost != secondIsHost) {
        return firstIsHost ? -1 : 1;
      }

      final nameCompare = first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return first.userId.compareTo(second.userId);
    });
    return members;
  }

  String _memberNameById(Lobby lobby, int userId) {
    final activeMembers = lobby.members.where((member) => member.isActive);
    for (final member in activeMembers) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    for (final member in lobby.members) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    return 'User $userId';
  }

  _LobbyStatusActionData? _statusActionFor(Lobby lobby) {
    switch (lobby.orderStatus) {
      case LobbyStatus.locked:
        return _LobbyStatusActionData(
          label: 'Mark as Order Placed',
          icon: Icons.receipt_long_outlined,
          nextStatus: LobbyStatus.orderPlaced,
          enabled: lobby.allPaymentsPaid,
          disabledReason: lobby.allPaymentsPaid
              ? null
              : 'All payment records must be PAID first.',
        );
      case LobbyStatus.orderPlaced:
        return const _LobbyStatusActionData(
          label: 'Mark as Out for Delivery',
          icon: Icons.delivery_dining_outlined,
          nextStatus: LobbyStatus.outForDelivery,
          enabled: true,
        );
      case LobbyStatus.outForDelivery:
        return const _LobbyStatusActionData(
          label: 'Mark as Delivered',
          icon: Icons.check_circle_outline,
          nextStatus: LobbyStatus.delivered,
          enabled: true,
        );
      case LobbyStatus.delivered:
        return const _LobbyStatusActionData(
          label: 'Close Lobby',
          icon: Icons.done_all_outlined,
          nextStatus: LobbyStatus.closed,
          enabled: true,
        );
    }
    return null;
  }
}

class _LobbyDetailData {
  const _LobbyDetailData({
    required this.lobby,
    required this.currentUser,
    required this.isInActiveLobby,
  });

  final Lobby lobby;
  final User currentUser;
  final bool isInActiveLobby;
}

class _MyLobbyBanner extends StatelessWidget {
  const _MyLobbyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'My Lobby',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _ExitLobbyAction extends StatelessWidget {
  const _ExitLobbyAction({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.error,
        side: BorderSide(color: colorScheme.error),
      ),
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _LockCartAction extends StatelessWidget {
  const _LockCartAction({
    required this.canLock,
    required this.isLoading,
    required this.onLock,
    this.disabledReason,
  });

  final bool canLock;
  final bool isLoading;
  final VoidCallback onLock;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Lock Cart',
          icon: Icons.lock_outline,
          isLoading: isLoading,
          onPressed: canLock ? onLock : null,
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _LobbyStatusActionData {
  const _LobbyStatusActionData({
    required this.label,
    required this.icon,
    required this.nextStatus,
    required this.enabled,
    this.disabledReason,
  });

  final String label;
  final IconData icon;
  final String nextStatus;
  final bool enabled;
  final String? disabledReason;
}

class _LobbyStatusAction extends StatelessWidget {
  const _LobbyStatusAction({
    required this.action,
    required this.isLoading,
    required this.onPressed,
  });

  final _LobbyStatusActionData action;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = action.enabled && !isLoading ? onPressed : null;
    final child = isLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(action.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: effectiveOnPressed,
          icon: Icon(action.icon),
          label: child,
        ),
        if (!action.enabled && action.disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            action.disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _JoinLobbyAction extends StatelessWidget {
  const _JoinLobbyAction({
    required this.canJoin,
    required this.isLoading,
    required this.onJoin,
    this.disabledReason,
  });

  final bool canJoin;
  final bool isLoading;
  final VoidCallback onJoin;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    if (canJoin) {
      return PrimaryButton(
        label: 'Join Lobby',
        icon: Icons.login,
        isLoading: isLoading,
        onPressed: onJoin,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: 0.55,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.block),
            label: const Text('Unavailable'),
          ),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 6),
          Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canKick,
    required this.isKicking,
    required this.canTransferHost,
    required this.isTransferringHost,
    required this.onKick,
    required this.onTransferHost,
  });

  final LobbyMember member;
  final bool canKick;
  final bool isKicking;
  final bool canTransferHost;
  final bool isTransferringHost;
  final VoidCallback onKick;
  final VoidCallback onTransferHost;

  @override
  Widget build(BuildContext context) {
    final statusText = member.isActive
        ? member.membershipStatus
        : '${member.membershipStatus} member';
    final isProcessing = isKicking || isTransferringHost;
    final hasHostAction = canTransferHost || canKick;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(member.isHost ? Icons.star_outline : Icons.person_outline),
      title: Text(member.name),
      subtitle: Text(member.roleInLobby),
      trailing: isProcessing
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : hasHostAction
              ? PopupMenuButton<_MemberAction>(
                  tooltip: 'Member actions',
                  onSelected: (action) {
                    if (action == _MemberAction.transferHost) {
                      onTransferHost();
                    } else {
                      onKick();
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      if (canTransferHost)
                        const PopupMenuItem<_MemberAction>(
                          value: _MemberAction.transferHost,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.switch_account_outlined),
                            title: Text('Transfer Host'),
                          ),
                        ),
                      if (canKick)
                        const PopupMenuItem<_MemberAction>(
                          value: _MemberAction.kick,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.person_remove_outlined),
                            title: Text('Kick'),
                          ),
                        ),
                    ];
                  },
                )
              : Text(statusText),
    );
  }
}

enum _MemberAction {
  transferHost,
  kick,
}
