package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.lobby.CartPaymentController.CartItemRequest;
import kr.kaist.buddies.lobby.CartPaymentController.CartItemResponse;
import kr.kaist.buddies.lobby.CartPaymentController.DeleteCartItemResponse;
import kr.kaist.buddies.lobby.domain.CartItem;
import kr.kaist.buddies.lobby.domain.CartItemRepository;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import kr.kaist.buddies.lobby.domain.LobbyOrderStatus;
import kr.kaist.buddies.lobby.domain.LobbyRepository;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CartService {
    private final CartItemRepository cartItemRepository;
    private final LobbyRepository lobbyRepository;
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final UserRepository userRepository;
    private final LobbyEventPublisher lobbyEventPublisher;

    public CartService(
        CartItemRepository cartItemRepository,
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        UserRepository userRepository,
        LobbyEventPublisher lobbyEventPublisher
    ) {
        this.cartItemRepository = cartItemRepository;
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.userRepository = userRepository;
        this.lobbyEventPublisher = lobbyEventPublisher;
    }

    @Transactional(readOnly = true)
    public List<CartItemResponse> listItems(Long userId, Long lobbyId) {
        requireActiveMember(lobbyId, userId);
        return cartItemRepository.findByLobby_IdAndDeletedAtIsNullOrderByCreatedAtAsc(lobbyId).stream()
            .map(item -> toResponse(item, item.getLobby().getCurrentTotalAmount()))
            .toList();
    }

    @Transactional
    public CartItemResponse addItem(Long userId, Long lobbyId, CartItemRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireCartEditable(lobby);
        User owner = findUser(userId);
        requireActiveMember(lobbyId, userId);

        CartItem item = cartItemRepository.save(new CartItem(
            lobby,
            owner,
            request.itemName().trim(),
            request.unitPrice(),
            request.quantity()
        ));
        long currentTotalAmount = refreshLobbyTotal(lobby);
        lobbyEventPublisher.cartItemAdded(lobbyId, userId, owner.getName(), item.getItemName());
        return toResponse(item, currentTotalAmount);
    }

    @Transactional
    public CartItemResponse updateItem(Long userId, Long lobbyId, Long itemId, CartItemRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireCartEditable(lobby);
        requireActiveMember(lobbyId, userId);
        CartItem item = findActiveItem(lobbyId, itemId);
        requireOwner(item, userId);

        item.update(request.itemName().trim(), request.unitPrice(), request.quantity(), Instant.now());
        long currentTotalAmount = refreshLobbyTotal(lobby);
        lobbyEventPublisher.cartItemUpdated(lobbyId, userId, item.getOwner().getName(), item.getItemName());
        return toResponse(item, currentTotalAmount);
    }

    @Transactional
    public DeleteCartItemResponse deleteItem(Long userId, Long lobbyId, Long itemId) {
        Lobby lobby = findLobby(lobbyId);
        requireCartEditable(lobby);
        requireActiveMember(lobbyId, userId);
        CartItem item = findActiveItem(lobbyId, itemId);
        requireOwner(item, userId);

        Instant deletedAt = Instant.now();
        String itemName = item.getItemName();
        item.delete(deletedAt);
        long currentTotalAmount = refreshLobbyTotal(lobby);
        lobbyEventPublisher.cartItemDeleted(lobbyId, userId, item.getOwner().getName(), itemName);
        return new DeleteCartItemResponse(itemId, lobbyId, deletedAt.toString(), currentTotalAmount);
    }

    @Transactional
    public void deleteActiveItemsOwnedBy(Long lobbyId, Long ownerId) {
        Lobby lobby = findLobby(lobbyId);
        Instant now = Instant.now();
        cartItemRepository.findByLobby_IdAndOwner_IdAndDeletedAtIsNull(lobbyId, ownerId)
            .forEach(item -> item.delete(now));
        refreshLobbyTotal(lobby);
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> LobbyErrorCode.LOBBY_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> LobbyErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED));
    }

    private CartItem findActiveItem(Long lobbyId, Long itemId) {
        return cartItemRepository.findByIdAndLobby_IdAndDeletedAtIsNull(itemId, lobbyId)
            .orElseThrow(() -> LobbyErrorCode.CART_ITEM_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private void requireActiveMember(Long lobbyId, Long userId) {
        if (lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE).isEmpty()) {
            throw LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN);
        }
    }

    private void requireCartEditable(Lobby lobby) {
        if (lobby.getOrderStatus() != LobbyOrderStatus.WAITING || lobby.isCartLocked() || lobby.getDeletedAt() != null) {
            throw LobbyErrorCode.CART_NOT_EDITABLE.exception(HttpStatus.CONFLICT);
        }
    }

    private void requireOwner(CartItem item, Long userId) {
        if (!item.getOwner().getId().equals(userId)) {
            throw LobbyErrorCode.CART_ITEM_OWNER_REQUIRED.exception(HttpStatus.FORBIDDEN);
        }
    }

    private long refreshLobbyTotal(Lobby lobby) {
        long currentTotalAmount = cartItemRepository.sumActiveSubtotalByLobbyId(lobby.getId());
        lobby.updateCurrentTotalAmount(currentTotalAmount, Instant.now());
        return currentTotalAmount;
    }

    private CartItemResponse toResponse(CartItem item, long currentTotalAmount) {
        return new CartItemResponse(
            item.getId(),
            item.getLobby().getId(),
            item.getOwner().getId(),
            item.getItemName(),
            item.getUnitPrice(),
            item.getQuantity(),
            item.getSubtotal(),
            currentTotalAmount
        );
    }
}
