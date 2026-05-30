import 'package:flutter/material.dart';

import '../../core/service_registry.dart';
import '../../models/order_history_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/error_message_view.dart';
import '../../widgets/loading_view.dart';
import 'rating_dialog.dart';

// CLOSED/CANCELED Lobby를 제한된 정보로 보여주는 주문 이력 화면입니다.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<OrderHistoryItem>> _loadHistory() async {
    return AppServices.userService.getOrderHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Order History',
      body: FutureBuilder<List<OrderHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading order history...');
          }

          if (snapshot.hasError) {
            return ErrorMessageView(
              message: 'Order history를 불러오지 못했습니다.',
              onRetry: _refreshHistory,
            );
          }

          final lobbies = snapshot.data!;
          if (lobbies.isEmpty) {
            return const EmptyStateView(
              title: 'No order history',
              message: 'Closed or canceled orders will appear here.',
              icon: Icons.history,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lobbies.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _HistoryTile(
                item: lobbies[index],
                onRate: () => _openRatingDialog(lobbies[index]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openRatingDialog(OrderHistoryItem item) async {
    final didRate = await showDialog<bool>(
      context: context,
      builder: (context) => RatingDialog(historyItem: item),
    );
    if (!mounted || didRate != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating submitted.')),
    );
    _refreshHistory();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.onRate,
  });

  final OrderHistoryItem item;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(item.restaurantName),
              subtitle: Text(
                '#${item.lobbyId}  ${_formatDate(item.deliveredAt)} - '
                'Host ${item.hostName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              trailing: Text('${item.totalAmount} KRW'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('My ${item.myAmount} KRW')),
                Chip(label: Text('${item.participantCount} members')),
                if (item.receiptImageUrl == null)
                  const Chip(label: Text('No receipt')),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: item.canRate ? onRate : null,
                icon: const Icon(Icons.star_outline),
                label: Text(item.canRate ? 'Rate user' : 'Rated'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Unknown date';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
