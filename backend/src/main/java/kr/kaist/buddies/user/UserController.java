package kr.kaist.buddies.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.Map;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping
public class UserController {
    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/users/me")
    public ProfileResponse profile(@CurrentUser AuthenticatedUser user) {
        return userService.profile(user.id());
    }

    @PatchMapping("/users/me")
    public ProfileResponse updateProfile(@CurrentUser AuthenticatedUser user, @RequestBody Map<String, Object> request) {
        return userService.updateProfile(user.id(), request);
    }

    @GetMapping("/users/me/order-history")
    public OrderHistoryResponse orderHistory(@CurrentUser AuthenticatedUser user) {
        return userService.orderHistory(user.id());
    }

    @PostMapping("/ratings")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse createRating(@CurrentUser AuthenticatedUser user, @Valid @RequestBody RatingRequest request) {
        return userService.createRating(user.id(), request);
    }

    @GetMapping("/help/faqs")
    public List<FaqResponse> faqs() {
        return userService.faqs();
    }

    @PostMapping("/support/tickets")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse createSupportTicket(@CurrentUser AuthenticatedUser user, @Valid @RequestBody SupportTicketRequest request) {
        return userService.createSupportTicket(user.id(), request);
    }

    public record UpdateProfileRequest(@NotBlank String name, String profileImageUrl) {}
    public record RatingRequest(Long lobbyId, Long targetUserId, @Min(1) @Max(5) int rating, String feedback) {}
    public record SupportTicketRequest(@NotBlank String category, @NotBlank String title, @NotBlank String body, Long lobbyId) {}
    public record ProfileResponse(Long id, String email, String name, String role, String profileImageUrl, double trustScore, String status) {}
    public record OrderHistoryResponse(List<OrderHistoryItem> items) {}
    public record OrderHistoryItem(Long lobbyId, String restaurantName, String deliveryLocation, String deliveredAt, String hostName, int participantCount, long totalAmount, long myAmount, String receiptImageUrl, boolean canRate) {}
    public record FaqResponse(String key, String answer) {}
    public record MessageResponse(String message) {}
}
