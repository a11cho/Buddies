import 'package:flutter/material.dart';

import '../core/enums.dart';

// Cart Lock 이후 member별 결제 상태를 보여줄 component입니다.
// Host만 confirm 버튼을 볼 수 있도록 canConfirm을 외부에서 계산해서 넘깁니다.
class PaymentRecordTile extends StatelessWidget {
  const PaymentRecordTile({
    required this.userName,
    required this.amount,
    required this.status,
    this.canConfirm = false,
    this.onConfirm,
    super.key,
  });

  final String userName;
  final int amount;
  final String status;
  final bool canConfirm;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaid = status == PaymentStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          userName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          'Amount $amount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(status),
              avatar: Icon(
                isPaid ? Icons.check_circle_outline : Icons.schedule_outlined,
                size: 16,
              ),
            ),
            if (canConfirm) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: isPaid ? null : onConfirm,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Confirm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
