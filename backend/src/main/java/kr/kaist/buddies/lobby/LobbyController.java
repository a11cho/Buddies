package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/lobbies")
public class LobbyController {
    @GetMapping
    public List<LobbySummaryResponse> list() {
        return List.of();
    }

    @PostMapping
    public LobbyResponse create(@Valid @RequestBody CreateLobbyRequest request) {
        // TODO: Read host user id from JWT and enforce one active lobby per user.
        return new LobbyResponse(1L, request.restaurantName(), request.deliveryLocation(), "WAITING", false, 0L, request.minimumOrderAmount());
    }

    @GetMapping("/{lobbyId}")
    public LobbyResponse get(@PathVariable Long lobbyId) {
        return new LobbyResponse(lobbyId, "Sample Restaurant", "KAIST", "WAITING", false, 0L, 23000L);
    }

    @PostMapping("/{lobbyId}/join")
    public MessageResponse join(@PathVariable Long lobbyId) {
        return new MessageResponse("Joined lobby " + lobbyId);
    }

    @PostMapping("/{lobbyId}/leave")
    public MessageResponse leave(@PathVariable Long lobbyId) {
        return new MessageResponse("Left lobby " + lobbyId);
    }

    @PostMapping("/{lobbyId}/cart/lock")
    public MessageResponse lockCart(@PathVariable Long lobbyId) {
        return new MessageResponse("Cart locked for lobby " + lobbyId);
    }

    @PatchMapping("/{lobbyId}/status")
    public MessageResponse updateStatus(@PathVariable Long lobbyId, @Valid @RequestBody UpdateLobbyStatusRequest request) {
        return new MessageResponse("Lobby " + lobbyId + " status changed to " + request.orderStatus());
    }

    @PostMapping("/{lobbyId}/transfer-host")
    public MessageResponse transferHost(@PathVariable Long lobbyId, @Valid @RequestBody TransferHostRequest request) {
        return new MessageResponse("Lobby " + lobbyId + " host transferred to " + request.newHostUserId());
    }

    @PostMapping("/{lobbyId}/kick")
    public MessageResponse kick(@PathVariable Long lobbyId, @Valid @RequestBody KickMemberRequest request) {
        return new MessageResponse("User " + request.targetUserId() + " kicked from lobby " + lobbyId);
    }

    @DeleteMapping("/{lobbyId}")
    public MessageResponse delete(@PathVariable Long lobbyId) {
        // TODO: Finalize cart item retention policy for CLOSED/CANCELED lobbies.
        return new MessageResponse("Lobby " + lobbyId + " closed or canceled");
    }

    public record CreateLobbyRequest(
        @NotBlank String restaurantName,
        @NotBlank String deliveryLocation,
        @PositiveOrZero long minimumOrderAmount,
        @PositiveOrZero long deliveryFee,
        String hostBankAccount,
        String tossDeepLink,
        String kakaoPayDeepLink
    ) {}
    public record UpdateLobbyStatusRequest(@NotBlank String orderStatus) {}
    public record TransferHostRequest(@NotNull Long newHostUserId) {}
    public record KickMemberRequest(@NotNull Long targetUserId, String reason) {}
    public record LobbySummaryResponse(Long id, String restaurantName, String deliveryLocation, String orderStatus, boolean cartLocked) {}
    public record LobbyResponse(Long id, String restaurantName, String deliveryLocation, String orderStatus, boolean cartLocked, long currentTotalAmount, long minimumOrderAmount) {}
    public record MessageResponse(String message) {}
}
