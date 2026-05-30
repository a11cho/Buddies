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
    final isPaid = status == PaymentStatus.paid;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(userName),
      subtitle: Text('Amount $amount'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(status),
            avatar: Icon(
              isPaid ? Icons.check_circle_outline : Icons.schedule_outlined,
            ),
          ),
          if (canConfirm) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: isPaid ? null : onConfirm,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Confirm'),
            ),
          ],
        ],
      ),
    );
  }
}
