import 'package:flutter/material.dart';

// Lobby 목록에서 Lobby 하나를 보여주는 카드입니다.
class LobbyCard extends StatelessWidget {
  const LobbyCard({
    required this.restaurantName,
    required this.deliveryZone,
    required this.currentTotalAmount,
    required this.minimumOrderAmount,
    required this.remainingAmount,
    required this.participantCount,
    required this.orderStatus,
    this.isMyLobby = false,
    this.onTap,
    this.onJoin,
    this.canJoin = false,
    this.showJoinAction = false,
    this.joinDisabledReason,
    super.key,
  });

  final String restaurantName;
  final String deliveryZone;
  final int currentTotalAmount;
  final int minimumOrderAmount;
  final int remainingAmount;
  final int participantCount;
  final String orderStatus;
  final bool isMyLobby;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool canJoin;
  final bool showJoinAction;
  final String? joinDisabledReason;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = minimumOrderAmount <= 0
        ? 0.0
        : (currentTotalAmount / minimumOrderAmount).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0054FF).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          deliveryZone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: orderStatus),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isMyLobby) ...[
                    const _MyLobbyBadge(),
                    const SizedBox(width: 8),
                  ],
                  _InfoLabel(
                    icon: Icons.group_outlined,
                    label: '$participantCount',
                  ),
                  const Spacer(),
                  Text(
                    '₩$currentTotalAmount / ₩$minimumOrderAmount',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFDDE7FF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF0054FF)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                remainingAmount <= 0
                    ? 'Minimum reached'
                    : 'Remaining $remainingAmount',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              if (showJoinAction) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!canJoin && joinDisabledReason != null)
                      Expanded(
                        child: Text(
                          joinDisabledReason!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: canJoin
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0054FF)
                                      .withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Tooltip(
                        message: joinDisabledReason ?? 'Join this lobby',
                        child: FilledButton.tonalIcon(
                          onPressed: canJoin ? onJoin : null,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                canJoin ? const Color(0xFF0054FF) : null,
                            foregroundColor: canJoin ? Colors.white : null,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: Icon(
                            canJoin ? Icons.login : Icons.block,
                            size: 18,
                          ),
                          label: Text(canJoin ? 'Join' : 'Locked'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MyLobbyBadge extends StatelessWidget {
  const _MyLobbyBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: const Color(0xFF0054FF),
            ),
            const SizedBox(width: 4),
            Text(
              'My Lobby',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF0054FF),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
        ),
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
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF0054FF),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
