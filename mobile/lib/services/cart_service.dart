import '../models/cart_item.dart';

class CartItemRequest {
  const CartItemRequest({
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
  });

  final String itemName;
  final int unitPrice;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }
}

class CartItemMutationResult {
  const CartItemMutationResult({
    required this.cartItem,
    required this.currentTotalAmount,
  });

  final CartItem cartItem;
  final int currentTotalAmount;
}

class DeleteCartItemResult {
  const DeleteCartItemResult({
    required this.cartItemId,
    required this.lobbyId,
    required this.deletedAt,
    required this.currentTotalAmount,
  });

  final int cartItemId;
  final int lobbyId;
  final DateTime deletedAt;
  final int currentTotalAmount;
}

class LockCartResult {
  const LockCartResult({
    required this.lobbyId,
    required this.previousStatus,
    required this.orderStatus,
    required this.cartLockedAt,
  });

  final int lobbyId;
  final String previousStatus;
  final String orderStatus;
  final DateTime cartLockedAt;
}

abstract class CartService {
  Future<CartItemMutationResult> addCartItem(
    int lobbyId,
    CartItemRequest request,
  );

  Future<CartItemMutationResult> updateCartItem(
    int lobbyId,
    int cartItemId,
    CartItemRequest request,
  );

  Future<DeleteCartItemResult> deleteCartItem(int lobbyId, int cartItemId);

  Future<LockCartResult> lockCart(int lobbyId);
}
