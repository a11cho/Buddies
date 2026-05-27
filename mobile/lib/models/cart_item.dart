import 'json_parsing.dart';

// Lobby 상세의 CartItem model입니다.
// detail response 예시에는 lobbyId가 빠져 있어 nullable로 둡니다.
class CartItem {
  const CartItem({
    required this.cartItemId,
    required this.ownerUserId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.lobbyId,
  });

  final int cartItemId;
  final int? lobbyId;
  final int ownerUserId;
  final String itemName;
  final int unitPrice;
  final int quantity;
  final int subtotal;

  bool isOwnedBy(int userId) => ownerUserId == userId;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final unitPrice = parseJsonInt(json['unitPrice'], 'unitPrice');
    final quantity = parseJsonInt(json['quantity'], 'quantity');

    return CartItem(
      cartItemId: parseJsonInt(json['cartItemId'], 'cartItemId'),
      lobbyId: parseNullableJsonInt(json['lobbyId'], 'lobbyId'),
      ownerUserId: parseJsonInt(json['ownerUserId'], 'ownerUserId'),
      itemName: json['itemName'] as String? ?? '',
      unitPrice: unitPrice,
      quantity: quantity,
      subtotal: parseNullableJsonInt(json['subtotal'], 'subtotal') ??
          unitPrice * quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cartItemId': cartItemId,
      'lobbyId': lobbyId,
      'ownerUserId': ownerUserId,
      'itemName': itemName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }
}
