package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.auth.AuthException;
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
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "존재하지 않는 로비입니다."));
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
    }

    private CartItem findActiveItem(Long lobbyId, Long itemId) {
        return cartItemRepository.findByIdAndLobby_IdAndDeletedAtIsNull(itemId, lobbyId)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "장바구니 항목을 찾을 수 없습니다."));
    }

    private void requireActiveMember(Long lobbyId, Long userId) {
        if (lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE).isEmpty()) {
            throw new AuthException(HttpStatus.FORBIDDEN, "해당 로비에 대한 접근 권한이 없습니다.");
        }
    }

    private void requireCartEditable(Lobby lobby) {
        if (lobby.getOrderStatus() != LobbyOrderStatus.WAITING || lobby.isCartLocked() || lobby.getDeletedAt() != null) {
            throw new AuthException(HttpStatus.CONFLICT, "현재 로비에서는 장바구니를 변경할 수 없습니다.");
        }
    }

    private void requireOwner(CartItem item, Long userId) {
        if (!item.getOwner().getId().equals(userId)) {
            throw new AuthException(HttpStatus.FORBIDDEN, "장바구니 항목 소유자만 변경할 수 있습니다.");
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
