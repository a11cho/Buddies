import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/enums.dart';
import '../../core/service_registry.dart';
import '../../models/lobby.dart';
import '../../models/user.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_select_field.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/lobby_card.dart';
import '../../widgets/loading_view.dart';

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
      myActiveLobbyId: myActiveLobby?.lobbyId,
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
      centerTitle: true,
      titleWidget: Image.asset(
        'assets/images/buddies_logo_name.png',
        height: 34,
        fit: BoxFit.contain,
      ),
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

          return DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF5F5FA)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
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
                const SizedBox(height: 18),
                _LobbyListHeader(count: lobbies.length),
                const SizedBox(height: 10),
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
                      myActiveLobbyId: data.myActiveLobbyId,
                      isCurrentUserInActiveLobby: data.isInActiveLobby,
                      onTap: () => _openLobbyDetail(lobby.lobbyId),
                      onJoin: () => _joinLobby(lobby),
                    ),
                const SizedBox(height: 96),
              ],
            ),
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

class _LobbyListHeader extends StatelessWidget {
  const _LobbyListHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Lobbies',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
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
        ? const Color(0xFF0054FF)
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = canCreate ? Colors.white : colorScheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: canCreate
                ? [
                    BoxShadow(
                      color: const Color(0xFF0054FF).withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: FloatingActionButton.extended(
            onPressed: canCreate ? onCreate : null,
            tooltip: disabledReason ?? 'Create Lobby',
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: 0,
            icon: Icon(canCreate ? Icons.add : Icons.lock_outline),
            label: const Text('Create Lobby'),
          ),
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
    this.myActiveLobbyId,
    required this.hasPaymentInfo,
  });

  final List<Lobby> lobbies;
  final User currentUser;
  final bool isInActiveLobby;
  final int? myActiveLobbyId;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: restaurantController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onApply(),
              decoration: InputDecoration(
                hintText: 'Search restaurant',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF0054FF),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F3FA),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD9E4FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF0054FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD9E4FF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: BuddiesSelectField<String>(
                    label: 'Delivery Zone',
                    value: selectedDeliveryZone,
                    valueLabel: selectedDeliveryZone == _allDeliveryZonesFilter
                        ? 'All delivery zones'
                        : selectedDeliveryZone,
                    prefixIcon: Icons.place_outlined,
                    dense: true,
                    options: [
                      const BuddiesSelectOption<String>(
                        value: _allDeliveryZonesFilter,
                        label: 'All delivery zones',
                      ),
                      for (final zone in DeliveryZone.values)
                        BuddiesSelectOption<String>(
                          value: zone,
                          label: zone,
                        ),
                    ],
                    onChanged: onDeliveryZoneChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Clear filters',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0054FF).withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0054FF),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyCardContainer extends StatelessWidget {
  const _LobbyCardContainer({
    required this.lobby,
    required this.currentUserId,
    required this.myActiveLobbyId,
    required this.isCurrentUserInActiveLobby,
    required this.onTap,
    required this.onJoin,
  });

  final Lobby lobby;
  final int currentUserId;
  final int? myActiveLobbyId;
  final bool isCurrentUserInActiveLobby;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final isMember = lobby.lobbyId == myActiveLobbyId ||
        lobby.members.any(
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
      isMyLobby: isMember,
      canJoin: canJoin,
      showJoinAction: showJoinAction,
      joinDisabledReason: joinDisabledReason,
      onTap: onTap,
      onJoin: canJoin ? onJoin : null,
    );
  }
}
