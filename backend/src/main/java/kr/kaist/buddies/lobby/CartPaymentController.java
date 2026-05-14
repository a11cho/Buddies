package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/lobbies/{lobbyId}")
public class CartPaymentController {
    @PostMapping("/cart-items")
    public CartItemResponse addItem(@PathVariable Long lobbyId, @Valid @RequestBody CartItemRequest request) {
        return new CartItemResponse(1L, lobbyId, request.name(), request.quantity(), request.unitPrice());
    }

    @PatchMapping("/cart-items/{itemId}")
    public CartItemResponse updateItem(@PathVariable Long lobbyId, @PathVariable Long itemId, @Valid @RequestBody CartItemRequest request) {
        return new CartItemResponse(itemId, lobbyId, request.name(), request.quantity(), request.unitPrice());
    }

    @PostMapping("/cart-items/{itemId}/delete")
    public MessageResponse deleteItem(@PathVariable Long lobbyId, @PathVariable Long itemId) {
        return new MessageResponse("Cart item " + itemId + " deleted from lobby " + lobbyId);
    }

    @GetMapping("/payment-records")
    public List<PaymentRecordResponse> paymentRecords(@PathVariable Long lobbyId) {
        return List.of();
    }

    @PostMapping("/payment-records/{paymentRecordId}/confirm")
    public MessageResponse confirmPayment(@PathVariable Long lobbyId, @PathVariable Long paymentRecordId) {
        return new MessageResponse("Payment " + paymentRecordId + " confirmed for lobby " + lobbyId);
    }

    @GetMapping("/payment-deeplinks")
    public PaymentDeeplinkResponse paymentDeeplinks(@PathVariable Long lobbyId) {
        return new PaymentDeeplinkResponse("supertoss://send", "kakaotalk://kakaopay/money/to");
    }

    public record CartItemRequest(@NotBlank String name, @Positive int quantity, @Positive long unitPrice) {}
    public record CartItemResponse(Long id, Long lobbyId, String name, int quantity, long unitPrice) {}
    public record PaymentRecordResponse(Long id, Long userId, long amount, String status) {}
    public record PaymentDeeplinkResponse(String tossUrl, String kakaoPayUrl) {}
    public record MessageResponse(String message) {}
}

