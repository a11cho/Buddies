import 'package:flutter/material.dart';

import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../widgets/text_input_field.dart';

// CartItem 추가/수정에 함께 사용하는 dialog입니다.
// 저장 버튼을 누르면 화면이 CartItemRequest를 받아 service에 전달합니다.
class CartItemFormDialog extends StatefulWidget {
  const CartItemFormDialog({
    this.initialItem,
    super.key,
  });

  final CartItem? initialItem;

  @override
  State<CartItemFormDialog> createState() => _CartItemFormDialogState();
}

class _CartItemFormDialogState extends State<CartItemFormDialog> {
  late final TextEditingController _itemNameController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _quantityController;
  String? _errorText;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _itemNameController = TextEditingController(
      text: initialItem?.itemName ?? '',
    );
    _unitPriceController = TextEditingController(
      text: initialItem?.unitPrice.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: initialItem?.quantity.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _unitPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: const Color(0xFFF5F5FA),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Text(_isEditing ? 'Edit item' : 'Add item'),
      content: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextInputField(
                  controller: _itemNameController,
                  label: 'Item name',
                  prefixIcon: Icons.fastfood_outlined,
                ),
                const SizedBox(height: 12),
                TextInputField(
                  controller: _unitPriceController,
                  label: 'Unit price',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 12),
                TextInputField(
                  controller: _quantityController,
                  label: 'Quantity',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.numbers_outlined,
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0054FF),
              foregroundColor: Colors.white,
            ),
            child: Text(_isEditing ? 'Save' : 'Add'),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final itemName = _itemNameController.text.trim();
    final unitPrice = int.tryParse(_unitPriceController.text.trim());
    final quantity = int.tryParse(_quantityController.text.trim());

    if (itemName.isEmpty ||
        unitPrice == null ||
        unitPrice <= 0 ||
        quantity == null ||
        quantity <= 0) {
      setState(() {
        _errorText =
            'Item name, positive unit price, and quantity are required.';
      });
      return;
    }

    Navigator.pop(
      context,
      CartItemRequest(
        itemName: itemName,
        unitPrice: unitPrice,
        quantity: quantity,
      ),
    );
  }
}
