import 'package:flutter/material.dart';

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

class LobbyBrowserScreen extends StatelessWidget {
  const LobbyBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buddies'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _StatusCard(title: 'Delivery Zone', value: 'KAIST Campus'),
          _StatusCard(title: 'Active Lobby', value: 'No active lobby'),
          _StatusCard(title: 'Next Step', value: 'Connect REST API and WebSocket client'),
        ],
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

