import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../mock/mock_data.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/lobby_card.dart';
import '../../widgets/status_card.dart';

// 앱의 첫 화면입니다.
// 지금은 mock lobby 목록을 보여주고, 이후 LobbyService.getLobbies()로 교체합니다.
class LobbyListScreen extends StatelessWidget {
  const LobbyListScreen({super.key});

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StatusCard(title: 'Delivery Zone', value: 'KAIST Campus'),
          StatusCard(
            title: 'Active Lobby',
            value: '${mockLobbies.length} mock lobbies',
          ),
          const StatusCard(title: 'Mock Mode', value: 'Enabled'),
          const SizedBox(height: 8),
          Text(
            'Lobby List',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final lobby in mockLobbies)
            LobbyCard(
              restaurantName: lobby.restaurantName,
              deliveryZone: lobby.deliveryZone,
              currentTotalAmount: lobby.currentTotalAmount,
              minimumOrderAmount: lobby.minimumOrderAmount,
              remainingAmount: lobby.remainingAmount,
              participantCount: lobby.participantCount ?? lobby.members.length,
              orderStatus: lobby.orderStatus,
              unreadCount: lobby.unreadCount,
              canJoin: lobby.canJoin,
              onJoin: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${lobby.restaurantName} selected')),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Lobby 생성 화면으로 이동합니다.
          Navigator.pushNamed(context, AppRoutes.createLobby);
        },
        label: const Text('Create Lobby'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
