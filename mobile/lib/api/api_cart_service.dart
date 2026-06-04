import '../core/api_client.dart';
import '../models/cart_item.dart';
import '../models/json_parsing.dart';
import '../services/cart_service.dart';

class ApiCartService implements CartService {
  ApiCartService({
    required ApiClient apiClient,
    this.lobbyBasePath = '/lobbies',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String lobbyBasePath;

  @override
  Future<CartItemMutationResult> addCartItem(
    int lobbyId,
    CartItemRequest request,
  ) async {
    final response = await _apiClient.post(
      '$lobbyBasePath/$lobbyId/cart-items',
      body: request.toJson(),
    );
    return _mutationResultFromJson(response);
  }

  @override
  Future<CartItemMutationResult> updateCartItem(
    int lobbyId,
    int cartItemId,
    CartItemRequest request,
  ) async {
    final response = await _apiClient.patch(
      '$lobbyBasePath/$lobbyId/cart-items/$cartItemId',
      body: request.toJson(),
    );
    return _mutationResultFromJson(response);
  }

  @override
  Future<DeleteCartItemResult> deleteCartItem(
    int lobbyId,
    int cartItemId,
  ) async {
    final response = await _apiClient.delete(
      '$lobbyBasePath/$lobbyId/cart-items/$cartItemId',
    );
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid delete cart item response.',
    );
    final deletedAt = parseNullableDateTime(json['deletedAt']);
    if (deletedAt == null) {
      throw ApiException(
        message: 'Delete cart item response did not include deletedAt.',
        responseBody: response,
      );
    }

    return DeleteCartItemResult(
      cartItemId: parseJsonInt(json['cartItemId'], 'cartItemId'),
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      deletedAt: deletedAt,
      currentTotalAmount:
          parseJsonInt(json['currentTotalAmount'], 'currentTotalAmount'),
    );
  }

  @override
  Future<LockCartResult> lockCart(int lobbyId) async {
    final response = await _apiClient.post('$lobbyBasePath/$lobbyId/cart/lock');
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid lock cart response.',
    );
    final cartLockedAt = parseNullableDateTime(json['cartLockedAt']);
    if (cartLockedAt == null) {
      throw ApiException(
        message: 'Lock cart response did not include cartLockedAt.',
        responseBody: response,
      );
    }

    return LockCartResult(
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      previousStatus: json['previousStatus'] as String? ?? '',
      orderStatus: json['orderStatus'] as String? ?? '',
      cartLockedAt: cartLockedAt,
    );
  }

  CartItemMutationResult _mutationResultFromJson(Object? response) {
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid cart item mutation response.',
    );
    return CartItemMutationResult(
      cartItem: CartItem.fromJson(json),
      currentTotalAmount:
          parseJsonInt(json['currentTotalAmount'], 'currentTotalAmount'),
    );
  }
}
