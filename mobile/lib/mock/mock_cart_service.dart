import '../core/enums.dart';
import '../models/cart_item.dart';
import '../models/lobby.dart';
import '../models/payment_record.dart';
import '../services/cart_service.dart';
import 'mock_data_store.dart';

class MockCartService implements CartService {
  MockCartService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<CartItemMutationResult> addCartItem(
    int lobbyId,
    CartItemRequest request,
  ) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    _ensureCartEditable(lobby);

    final newItem = CartItem(
      cartItemId: _store.nextCartItemId++,
      lobbyId: lobbyId,
      ownerUserId: _store.currentUser.id,
      itemName: request.itemName,
      unitPrice: request.unitPrice,
      quantity: request.quantity,
      subtotal: request.unitPrice * request.quantity,
    );
    final updatedItems = [...lobby.cartItems, newItem];
    final updatedTotal = _calculateCurrentTotal(updatedItems);
    _store.replaceLobby(
      lobby.copyWith(
        cartItems: updatedItems,
        currentTotalAmount: updatedTotal,
        remainingAmount: _calculateRemaining(
          lobby.minimumOrderAmount,
          updatedTotal,
        ),
      ),
    );

    return CartItemMutationResult(
      cartItem: newItem,
      currentTotalAmount: updatedTotal,
    );
  }

  @override
  Future<CartItemMutationResult> updateCartItem(
    int lobbyId,
    int cartItemId,
    CartItemRequest request,
  ) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    _ensureCartEditable(lobby);
    if (!lobby.cartItems.any((item) => item.cartItemId == cartItemId)) {
      throw StateError('CartItem not found: $cartItemId');
    }

    late CartItem updatedItem;
    final updatedItems = lobby.cartItems.map((item) {
      if (item.cartItemId != cartItemId) {
        return item;
      }
      if (!item.isOwnedBy(_store.currentUser.id)) {
        throw StateError('Only the owner can update this CartItem.');
      }
      updatedItem = item.copyWith(
        itemName: request.itemName,
        unitPrice: request.unitPrice,
        quantity: request.quantity,
        subtotal: request.unitPrice * request.quantity,
      );
      return updatedItem;
    }).toList();

    final updatedTotal = _calculateCurrentTotal(updatedItems);
    _store.replaceLobby(
      lobby.copyWith(
        cartItems: updatedItems,
        currentTotalAmount: updatedTotal,
        remainingAmount: _calculateRemaining(
          lobby.minimumOrderAmount,
          updatedTotal,
        ),
      ),
    );

    return CartItemMutationResult(
      cartItem: updatedItem,
      currentTotalAmount: updatedTotal,
    );
  }

  @override
  Future<DeleteCartItemResult> deleteCartItem(int lobbyId, int cartItemId) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsActiveMember(lobby);
    _ensureCartEditable(lobby);

    final targetItem = lobby.cartItems.firstWhere(
      (item) => item.cartItemId == cartItemId,
      orElse: () => throw StateError('CartItem not found: $cartItemId'),
    );
    if (!targetItem.isOwnedBy(_store.currentUser.id)) {
      throw StateError('Only the owner can delete this CartItem.');
    }

    final updatedItems = lobby.cartItems
        .where((item) => item.cartItemId != cartItemId)
        .toList();
    final updatedTotal = _calculateCurrentTotal(updatedItems);
    final deletedAt = DateTime.now();
    _store.replaceLobby(
      lobby.copyWith(
        cartItems: updatedItems,
        currentTotalAmount: updatedTotal,
        remainingAmount: _calculateRemaining(
          lobby.minimumOrderAmount,
          updatedTotal,
        ),
      ),
    );

    return DeleteCartItemResult(
      cartItemId: cartItemId,
      lobbyId: lobbyId,
      deletedAt: deletedAt,
      currentTotalAmount: updatedTotal,
    );
  }

  @override
  Future<LockCartResult> lockCart(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    _ensureCurrentUserIsHost(lobby);
    if (lobby.orderStatus != LobbyStatus.waiting) {
      throw StateError('Only WAITING lobbies can be locked.');
    }
    if (lobby.currentTotalAmount < lobby.minimumOrderAmount) {
      throw StateError('Minimum order amount has not been reached.');
    }

    final lockedAt = DateTime.now();
    final paymentRecords = _buildPaymentRecords(lobby);
    _store.replaceLobby(
      lobby.copyWith(
        orderStatus: LobbyStatus.locked,
        cartLockedAt: lockedAt,
        paymentRecords: paymentRecords,
      ),
    );

    return LockCartResult(
      lobbyId: lobbyId,
      previousStatus: LobbyStatus.waiting,
      orderStatus: LobbyStatus.locked,
      cartLockedAt: lockedAt,
    );
  }

  void _ensureCartEditable(Lobby lobby) {
    if (!lobby.canEditCart) {
      throw StateError('Cart can only be edited before lock.');
    }
  }

  void _ensureCurrentUserIsHost(Lobby lobby) {
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can perform this action.');
    }
  }

  void _ensureCurrentUserIsActiveMember(Lobby lobby) {
    final isActiveMember = lobby.members.any(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
    if (!isActiveMember) {
      throw StateError('Only active Lobby members can edit CartItems.');
    }
  }

  int _calculateCurrentTotal(List<CartItem> items) {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }

  int _calculateRemaining(int minimumOrderAmount, int currentTotalAmount) {
    final remaining = minimumOrderAmount - currentTotalAmount;
    return remaining > 0 ? remaining : 0;
  }

  List<PaymentRecord> _buildPaymentRecords(Lobby lobby) {
    final activeMembers =
        lobby.members.where((member) => member.isActive).toList();
    final memberCount = activeMembers.isEmpty ? 1 : activeMembers.length;
    final deliveryShare = lobby.deliveryFee ~/ memberCount;

    return activeMembers.map((member) {
      final itemTotal = lobby.cartItems
          .where((item) => item.ownerUserId == member.userId)
          .fold(0, (sum, item) => sum + item.subtotal);
      final isHost = member.userId == lobby.hostUserId;
      return PaymentRecord(
        paymentRecordId: _store.nextPaymentRecordId++,
        lobbyId: lobby.lobbyId,
        userId: member.userId,
        amount: itemTotal + deliveryShare,
        status: isHost ? PaymentStatus.paid : PaymentStatus.unpaid,
        confirmedByHostId: isHost ? lobby.hostUserId : null,
        confirmedAt: isHost ? DateTime.now() : null,
      );
    }).toList();
  }
}
