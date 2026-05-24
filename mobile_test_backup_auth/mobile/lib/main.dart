import 'package:flutter/material.dart';
import 'api_client.dart';

void main() {
  runApp(const BuddiesApp());
}

class BuddiesApp extends StatelessWidget {
  const BuddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddies',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const LobbyBrowserScreen(),
    );
  }
}

class LobbyBrowserScreen extends StatefulWidget {
  const LobbyBrowserScreen({super.key});

  @override
  State<LobbyBrowserScreen> createState() => _LobbyBrowserScreenState();
}

class _LobbyBrowserScreenState extends State<LobbyBrowserScreen> {
  final BuddiesApiClient _apiClient = BuddiesApiClient();
  late final Future<List<LobbySummary>> _lobbies = _apiClient.getLobbies();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buddies'),
      ),
      body: FutureBuilder<List<LobbySummary>>(
        future: _lobbies,
        builder: (context, snapshot) {
          final lobbies = snapshot.data ?? const <LobbySummary>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _StatusCard(title: 'Delivery Zone', value: 'KAIST Campus'),
              _StatusCard(title: 'Open Lobbies', value: '${lobbies.length} loaded from API'),
              _StatusCard(title: 'Connection', value: snapshot.hasError ? 'API unavailable' : 'REST API ready'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Create Lobby'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

