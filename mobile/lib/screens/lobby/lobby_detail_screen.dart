import 'package:flutter/material.dart';

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
// Phase 7부터 CartItem 추가/수정/삭제와 Cart Lock 진입점을 함께 제공합니다.
class LobbyDetailScreen extends StatefulWidget {
  const LobbyDetailScreen({super.key});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  Future<_LobbyDetailData>? _detailFuture;
  int? _lobbyId;
  bool _isJoining = false;
  bool _isLockingCart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Navigator.pushNamed(..., arguments: lobbyId)로 받은 값을 읽습니다.
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final nextLobbyId = arguments is int ? arguments : null;

    if (_lobbyId != nextLobbyId) {
      _lobbyId = nextLobbyId;
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
    return _LobbyDetailData(
      lobby: lobby,
      currentUser: user,
      isInActiveLobby: isInActiveLobby,
    );
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading lobby...');
          }

          if (snapshot.hasError) {
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
          final canEditCart = isMember && lobby.canEditCart;
          final shouldShowLockCart =
              isHost && lobby.orderStatus == LobbyStatus.waiting;
          final canLockCart =
              shouldShowLockCart &&
              lobby.currentTotalAmount >= lobby.minimumOrderAmount;
          final lockDisabledReason = shouldShowLockCart && !canLockCart
              ? 'Minimum order amount has not been reached.'
              : null;

          return ListView(
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
              const SizedBox(height: 8),
              Text(
                'Members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final member in lobby.members)
                _MemberRow(member: member),
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
                  ),
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

  String _memberNameById(Lobby lobby, int userId) {
    for (final member in lobby.members) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    return 'User $userId';
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
  const _MemberRow({required this.member});

  final LobbyMember member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(member.isHost ? Icons.star_outline : Icons.person_outline),
      title: Text(member.name),
      subtitle: Text(member.roleInLobby),
      trailing: Text(member.membershipStatus),
    );
  }
}
