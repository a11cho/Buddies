import 'package:flutter/material.dart';

// Lobby 목록에서 Lobby 하나를 보여주는 카드입니다.
// unreadCount는 사용자가 참여 중인 Lobby의 안 읽은 채팅 수 badge에 사용합니다.
class LobbyCard extends StatelessWidget {
  const LobbyCard({
    required this.restaurantName,
    required this.deliveryZone,
    required this.currentTotalAmount,
    required this.minimumOrderAmount,
    required this.remainingAmount,
    required this.participantCount,
    required this.orderStatus,
    this.unreadCount = 0,
    this.onTap,
    this.onJoin,
    this.canJoin = false,
    super.key,
  });

  final String restaurantName;
  final String deliveryZone;
  final int currentTotalAmount;
  final int minimumOrderAmount;
  final int remainingAmount;
  final int participantCount;
  final String orderStatus;
  final int unreadCount;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool canJoin;

  @override
  Widget build(BuildContext context) {
    final progress = minimumOrderAmount <= 0
        ? 0.0
        : (currentTotalAmount / minimumOrderAmount).clamp(0.0, 1.0).toDouble();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      restaurantName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    _UnreadBadge(count: unreadCount),
                    const SizedBox(width: 8),
                  ],
                  _StatusBadge(label: orderStatus),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoLabel(icon: Icons.place_outlined, label: deliveryZone),
                  _InfoLabel(
                    icon: Icons.group_outlined,
                    label: '$participantCount members',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                '$currentTotalAmount / $minimumOrderAmount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Remaining $remainingAmount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onJoin != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: canJoin ? onJoin : null,
                    icon: const Icon(Icons.login),
                    label: const Text('Join'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
