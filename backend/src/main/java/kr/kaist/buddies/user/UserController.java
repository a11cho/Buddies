package kr.kaist.buddies.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class UserController {
    @GetMapping("/users/me")
    public ProfileResponse profile() {
        return new ProfileResponse(1L, "dev@kaist.ac.kr", "Development User", "USER", null, 0.0, "ACTIVE");
    }

    @PatchMapping("/users/me")
    public ProfileResponse updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        // TODO: Prevent user-controlled changes to email, role, trustScore, and status in service layer.
        return new ProfileResponse(1L, "dev@kaist.ac.kr", request.name(), "USER", request.profileImageUrl(), 0.0, "ACTIVE");
    }

    @GetMapping("/users/me/order-history")
    public OrderHistoryResponse orderHistory() {
        return new OrderHistoryResponse(List.of());
    }

    @PostMapping("/ratings")
    public MessageResponse createRating(@Valid @RequestBody RatingRequest request) {
        return new MessageResponse("Rating accepted");
    }

    @GetMapping("/help/faqs")
    public List<FaqResponse> faqs() {
        return List.of(new FaqResponse("payment", "P2P settlement is handled outside the app."));
    }

    @PostMapping("/support/tickets")
    public MessageResponse createSupportTicket(@Valid @RequestBody SupportTicketRequest request) {
        return new MessageResponse("Support ticket created");
    }

    public record UpdateProfileRequest(@NotBlank String name, String profileImageUrl) {}
    public record RatingRequest(Long lobbyId, Long targetUserId, @Min(1) @Max(5) int rating, String feedback) {}
    public record SupportTicketRequest(@NotBlank String category, @NotBlank String title, @NotBlank String body, Long lobbyId) {}
    public record ProfileResponse(Long id, String email, String name, String role, String profileImageUrl, double trustScore, String status) {}
    public record OrderHistoryResponse(List<OrderHistoryItem> items) {}
    public record OrderHistoryItem(Long lobbyId, String restaurantName, String deliveredAt, String hostName, int participantCount, long totalAmount, long myAmount, String receiptImageUrl, boolean canRate) {}
    public record FaqResponse(String key, String answer) {}
    public record MessageResponse(String message) {}
}
