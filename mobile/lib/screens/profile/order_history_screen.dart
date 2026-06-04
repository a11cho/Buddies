import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/service_registry.dart';
import '../../models/order_history_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/buddies_style.dart';
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
      appBarBackgroundColor: AppColors.background,
      body: BuddiesScreenBody(
        child: FutureBuilder<List<OrderHistoryItem>>(
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
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _HistoryTile(
                  item: lobbies[index],
                  onRate: () => _openRatingDialog(lobbies[index]),
                );
              },
            );
          },
        ),
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
    final textTheme = Theme.of(context).textTheme;

    return BuddiesCard(
      padding: const EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.primaryBlue,
                ),
              ),
              title: Text(
                item.restaurantName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '#${item.lobbyId}  ${_formatDate(item.deliveredAt)} - '
                'Host ${item.hostName}',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: Text(
                '${item.totalAmount} KRW',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HistoryChip(label: 'My ${item.myAmount} KRW'),
                _HistoryChip(label: '${item.participantCount} members'),
                if (item.receiptImageUrl == null)
                  const _HistoryChip(label: 'No receipt'),
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

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppColors.inputBorder),
      backgroundColor: AppColors.softBlue,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
