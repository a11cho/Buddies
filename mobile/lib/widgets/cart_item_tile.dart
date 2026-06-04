import 'package:flutter/material.dart';

// Lobby 상세 화면에서 CartItem 하나를 보여줄 component입니다.
// 수정/삭제 가능 여부는 화면에서 계산해서 canEdit으로 넘깁니다.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.ownerName,
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String itemName;
  final int unitPrice;
  final int quantity;
  final int subtotal;
  final String? ownerName;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          itemName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          [
            '₩$unitPrice x $quantity',
            if (ownerName != null) ownerName!,
          ].join(' - '),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₩$subtotal',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (canEdit) ...[
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
