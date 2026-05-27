import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../models/lobby.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/lobby_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_card.dart';

// 앱의 첫 화면입니다.
// 화면은 LobbyService만 알고, mock인지 실제 API인지는 service_registry가 결정합니다.
class LobbyListScreen extends StatefulWidget {
  const LobbyListScreen({super.key});

  @override
  State<LobbyListScreen> createState() => _LobbyListScreenState();
}

class _LobbyListScreenState extends State<LobbyListScreen> {
  late Future<List<Lobby>> _lobbiesFuture;

  @override
  void initState() {
    super.initState();
    _lobbiesFuture = _loadLobbies();
  }

  Future<List<Lobby>> _loadLobbies() {
    return AppServices.lobbyService.getLobbies();
  }

  void _refreshLobbies() {
    setState(() {
      _lobbiesFuture = _loadLobbies();
    });
  }

  Future<void> _joinLobby(Lobby lobby) async {
    try {
      await AppServices.lobbyService.joinLobby(lobby.lobbyId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lobby.restaurantName} selected')),
      );
      _refreshLobbies();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Buddies',
      actions: [
        IconButton(
          tooltip: 'Login',
          onPressed: () {
            // route 이름으로 LoginScreen으로 이동합니다.
            Navigator.pushNamed(context, AppRoutes.login);
          },
          icon: const Icon(Icons.person_outline),
        ),
      ],
      body: FutureBuilder<List<Lobby>>(
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

          final lobbies = snapshot.data ?? const <Lobby>[];
          if (lobbies.isEmpty) {
            return EmptyStateView(
              title: 'No active lobbies',
              message: 'Create the first lobby.',
              actionLabel: 'Refresh',
              onAction: _refreshLobbies,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const StatusCard(title: 'Delivery Zone', value: 'KAIST Campus'),
              StatusCard(
                title: 'Active Lobby',
                value: '${lobbies.length} mock lobbies',
              ),
              const StatusCard(title: 'Mock Mode', value: 'Enabled'),
              const SizedBox(height: 8),
              Text(
                'Lobby List',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final lobby in lobbies)
                LobbyCard(
                  restaurantName: lobby.restaurantName,
                  deliveryZone: lobby.deliveryZone,
                  currentTotalAmount: lobby.currentTotalAmount,
                  minimumOrderAmount: lobby.minimumOrderAmount,
                  remainingAmount: lobby.remainingAmount,
                  participantCount:
                      lobby.participantCount ?? lobby.members.length,
                  orderStatus: lobby.orderStatus,
                  unreadCount: lobby.unreadCount,
                  canJoin: lobby.canJoin,
                  onJoin: lobby.canJoin ? () => _joinLobby(lobby) : null,
                ),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Lobby 생성 화면으로 이동합니다.
          final didCreate = await Navigator.pushNamed(
            context,
            AppRoutes.createLobby,
          );
          if (didCreate == true) {
            _refreshLobbies();
          }
        },
        label: const Text('Create Lobby'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
