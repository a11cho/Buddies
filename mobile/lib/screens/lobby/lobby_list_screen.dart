import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/lobby.dart';
import '../../models/user.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/lobby_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_card.dart';
import '../../widgets/text_input_field.dart';

const _allDeliveryZonesFilter = 'ALL';

// 앱의 첫 화면입니다.
// 화면은 LobbyService만 알고, mock인지 실제 API인지는 service_registry가 결정합니다.
class LobbyListScreen extends StatefulWidget {
  const LobbyListScreen({super.key});

  @override
  State<LobbyListScreen> createState() => _LobbyListScreenState();
}

class _LobbyListScreenState extends State<LobbyListScreen> {
  final TextEditingController _restaurantFilterController =
      TextEditingController();
  String _selectedDeliveryZoneFilter = _allDeliveryZonesFilter;
  late Future<_LobbyListData> _lobbiesFuture;

  @override
  void initState() {
    super.initState();
    _lobbiesFuture = _loadLobbies();
  }

  @override
  void dispose() {
    _restaurantFilterController.dispose();
    super.dispose();
  }

  Future<_LobbyListData> _loadLobbies() async {
    final currentUser = await AppServices.authService.getMe();
    final paymentInfo = await AppServices.userService.getPaymentInfo();
    final myActiveLobby = await AppServices.lobbyService.getMyActiveLobby();
    final lobbies = await AppServices.lobbyService.getLobbies(
      restaurantName: _normalizeFilter(_restaurantFilterController.text),
      deliveryZone: _selectedDeliveryZoneFilter == _allDeliveryZonesFilter
          ? null
          : _selectedDeliveryZoneFilter,
    );
    final visibleLobbies = _buildVisibleLobbies(
      myActiveLobby: myActiveLobby,
      filteredLobbies: lobbies,
    );
    return _LobbyListData(
      lobbies: visibleLobbies,
      currentUser: currentUser,
      isInActiveLobby: myActiveLobby != null,
      hasPaymentInfo: paymentInfo?.isComplete == true,
    );
  }

  void _refreshLobbies() {
    setState(() {
      _lobbiesFuture = _loadLobbies();
    });
  }

  void _clearFilters() {
    _restaurantFilterController.clear();
    _selectedDeliveryZoneFilter = _allDeliveryZonesFilter;
    _refreshLobbies();
  }

  String? _normalizeFilter(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Lobby> _buildVisibleLobbies({
    required Lobby? myActiveLobby,
    required List<Lobby> filteredLobbies,
  }) {
    if (myActiveLobby == null) {
      return filteredLobbies;
    }

    // 검색 가능한 Lobby는 WAITING만 받고, 내가 속한 active Lobby는 별도 조회로 최상단에 둡니다.
    final otherLobbies = filteredLobbies
        .where((lobby) => lobby.lobbyId != myActiveLobby.lobbyId)
        .toList();
    return [
      myActiveLobby,
      ...otherLobbies,
    ];
  }

  Future<void> _openLobbyDetail(int lobbyId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.lobbyDetail,
      arguments: lobbyId,
    );
    _refreshLobbies();
  }

  Future<void> _joinLobby(Lobby lobby) async {
    try {
      await AppServices.lobbyService.joinLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${lobby.restaurantName}.')),
      );
      await _openLobbyDetail(lobby.lobbyId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openCreateLobby() async {
    final didCreate = await Navigator.pushNamed(
      context,
      AppRoutes.createLobby,
    );
    if (didCreate == true) {
      _refreshLobbies();
    }
  }

  Future<void> _openProfile() async {
    await Navigator.pushNamed(context, AppRoutes.profile);
    if (!mounted) {
      return;
    }
    // Profile 안에서 계좌 정보가 바뀔 수 있으므로 돌아오면 Create Lobby 가능 여부를 다시 계산합니다.
    _refreshLobbies();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buddies',
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: _openProfile,
          icon: const Icon(Icons.person_outline),
        ),
      ],
      body: FutureBuilder<_LobbyListData>(
        future: _lobbiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading lobbies...');
          }

          if (snapshot.hasError) {
            return ErrorMessageView(
              message: 'Lobby 목록을 불러오지 못했습니다.',
              onRetry: _refreshLobbies,
            );
          }

          final data = snapshot.data!;
          final lobbies = data.lobbies;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatusCard(
                title: 'Active Lobby',
                value: '${lobbies.length} mock lobbies',
              ),
              const StatusCard(title: 'Mock Mode', value: 'Enabled'),
              const SizedBox(height: 8),
              _FilterSection(
                restaurantController: _restaurantFilterController,
                selectedDeliveryZone: _selectedDeliveryZoneFilter,
                onDeliveryZoneChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedDeliveryZoneFilter = value;
                  });
                },
                onApply: _refreshLobbies,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 16),
              Text(
                'Lobby List',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (lobbies.isEmpty)
                SizedBox(
                  height: 280,
                  child: EmptyStateView(
                    title: 'No matching lobbies',
                    message: 'Change the filter or create a new lobby.',
                    actionLabel: 'Clear filters',
                    onAction: _clearFilters,
                  ),
                )
              else
                for (final lobby in lobbies)
                  _LobbyCardContainer(
                    lobby: lobby,
                    currentUserId: data.currentUser.id,
                    isCurrentUserInActiveLobby: data.isInActiveLobby,
                    onTap: () => _openLobbyDetail(lobby.lobbyId),
                    onJoin: () => _joinLobby(lobby),
                  ),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_LobbyListData>(
        future: _lobbiesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final data = snapshot.data!;
          final createDisabledReason = data.isInActiveLobby
              ? 'Already in a lobby'
              : !data.hasPaymentInfo
                  ? 'Payment info required'
                  : null;
          return _CreateLobbyFab(
            canCreate: createDisabledReason == null,
            disabledReason: createDisabledReason,
            onCreate: _openCreateLobby,
          );
        },
      ),
    );
  }
}

class _CreateLobbyFab extends StatelessWidget {
  const _CreateLobbyFab({
    required this.canCreate,
    required this.onCreate,
    this.disabledReason,
  });

  final bool canCreate;
  final String? disabledReason;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = canCreate
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor =
        canCreate ? colorScheme.onPrimaryContainer : colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          onPressed: canCreate ? onCreate : null,
          tooltip: disabledReason ?? 'Create Lobby',
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: canCreate ? 6 : 0,
          icon: Icon(canCreate ? Icons.add : Icons.lock_outline),
          label: const Text('Create Lobby'),
        ),
        if (!canCreate && disabledReason != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              disabledReason!,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LobbyListData {
  const _LobbyListData({
    required this.lobbies,
    required this.currentUser,
    required this.isInActiveLobby,
    required this.hasPaymentInfo,
  });

  final List<Lobby> lobbies;
  final User currentUser;
  final bool isInActiveLobby;
  final bool hasPaymentInfo;
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.restaurantController,
    required this.selectedDeliveryZone,
    required this.onDeliveryZoneChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController restaurantController;
  final String selectedDeliveryZone;
  final ValueChanged<String?> onDeliveryZoneChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextInputField(
          controller: restaurantController,
          label: 'Restaurant filter',
          hintText: 'Pizza',
          prefixIcon: Icons.search,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedDeliveryZone,
          decoration: const InputDecoration(
            labelText: 'Delivery zone filter',
            prefixIcon: Icon(Icons.place_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: _allDeliveryZonesFilter,
              child: Text('All zones'),
            ),
            for (final zone in DeliveryZone.values)
              DropdownMenuItem<String>(
                value: zone,
                child: Text(zone),
              ),
          ],
          onChanged: onDeliveryZoneChanged,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Apply filters'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LobbyCardContainer extends StatelessWidget {
  const _LobbyCardContainer({
    required this.lobby,
    required this.currentUserId,
    required this.isCurrentUserInActiveLobby,
    required this.onTap,
    required this.onJoin,
  });

  final Lobby lobby;
  final int currentUserId;
  final bool isCurrentUserInActiveLobby;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final isMember = lobby.members.any(
      (member) => member.userId == currentUserId && member.isActive,
    );
    final canJoin = lobby.canJoin && !isMember && !isCurrentUserInActiveLobby;
    final showJoinAction = lobby.canJoin && !isMember;
    final joinDisabledReason = showJoinAction && isCurrentUserInActiveLobby
        ? 'Already in a lobby'
        : null;

    return LobbyCard(
      restaurantName: lobby.restaurantName,
      deliveryZone: lobby.deliveryZone,
      currentTotalAmount: lobby.currentTotalAmount,
      minimumOrderAmount: lobby.minimumOrderAmount,
      remainingAmount: lobby.remainingAmount,
      participantCount: lobby.participantCount ?? lobby.members.length,
      orderStatus: lobby.orderStatus,
      unreadCount: isMember ? lobby.unreadCount : 0,
      isMyLobby: isMember,
      canJoin: canJoin,
      showJoinAction: showJoinAction,
      joinDisabledReason: joinDisabledReason,
      onTap: onTap,
      onJoin: canJoin ? onJoin : null,
    );
  }
}
