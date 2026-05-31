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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(itemName),
      subtitle: Text(
        [
          '$unitPrice x $quantity',
          if (ownerName != null) ownerName!,
        ].join(' - '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$subtotal'),
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    );
  }
}
