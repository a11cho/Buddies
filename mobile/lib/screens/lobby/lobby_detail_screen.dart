import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/lobby.dart';
import '../../models/lobby_member.dart';
import '../../models/user.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_card.dart';

// Phase 6에서는 LobbyCard를 눌렀을 때 이동할 최소 상세 화면만 제공합니다.
// CartItem 수정/삭제와 결제 처리는 Phase 7, 8에서 이 화면에 이어 붙입니다.
class LobbyDetailScreen extends StatefulWidget {
  const LobbyDetailScreen({super.key});

  @override
  State<LobbyDetailScreen> createState() => _LobbyDetailScreenState();
}

class _LobbyDetailScreenState extends State<LobbyDetailScreen> {
  Future<_LobbyDetailData>? _detailFuture;
  int? _lobbyId;
  bool _isJoining = false;

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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isMember)
                const _MyLobbyBanner(),
              StatusCard(title: 'Restaurant', value: lobby.restaurantName),
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
