package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.util.List;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/lobbies/{lobbyId}")
public class CartPaymentController {
    private final CartService cartService;
    private final PaymentService paymentService;

    public CartPaymentController(CartService cartService, PaymentService paymentService) {
        this.cartService = cartService;
        this.paymentService = paymentService;
    }

    @GetMapping("/cart-items")
    public List<CartItemResponse> listItems(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return cartService.listItems(user.id(), lobbyId);
    }

    @PostMapping("/cart-items")
    public CartItemResponse addItem(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @Valid @RequestBody CartItemRequest request) {
        return cartService.addItem(user.id(), lobbyId, request);
    }

    @PatchMapping("/cart-items/{itemId}")
    public CartItemResponse updateItem(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @PathVariable Long itemId, @Valid @RequestBody CartItemRequest request) {
        return cartService.updateItem(user.id(), lobbyId, itemId, request);
    }

    @DeleteMapping("/cart-items/{itemId}")
    public DeleteCartItemResponse deleteItem(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @PathVariable Long itemId) {
        return cartService.deleteItem(user.id(), lobbyId, itemId);
    }

    @GetMapping("/payment-records")
    public List<PaymentRecordResponse> paymentRecords(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return paymentService.list(user.id(), lobbyId);
    }

    @PostMapping("/payment-records/{paymentRecordId}/confirm")
    public PaymentRecordResponse confirmPayment(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @PathVariable Long paymentRecordId
    ) {
        return paymentService.confirm(user.id(), lobbyId, paymentRecordId);
    }

    public record CartItemRequest(@NotBlank String itemName, @NotNull @Positive Long unitPrice, @NotNull @Positive Integer quantity) {}
    public record CartItemResponse(Long cartItemId, Long lobbyId, Long ownerUserId, String itemName, long unitPrice, int quantity, long subtotal, long currentTotalAmount) {}
    public record DeleteCartItemResponse(Long cartItemId, Long lobbyId, String deletedAt, long currentTotalAmount) {}
    public record PaymentRecordResponse(
        Long paymentRecordId,
        Long lobbyId,
        Long userId,
        long amount,
        String status,
        Long confirmedByHostId,
        String confirmedAt
    ) {}
    public record MessageResponse(String message) {}
}
