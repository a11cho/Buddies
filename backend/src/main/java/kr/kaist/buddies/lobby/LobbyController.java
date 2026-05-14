package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
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
        return new LobbyResponse(1L, request.restaurantName(), request.deliveryZoneId(), "WAITING", false);
    }

    @GetMapping("/{lobbyId}")
    public LobbyResponse get(@PathVariable Long lobbyId) {
        return new LobbyResponse(lobbyId, "Sample Restaurant", 1L, "WAITING", false);
    }

    @PostMapping("/{lobbyId}/join")
    public MessageResponse join(@PathVariable Long lobbyId) {
        return new MessageResponse("Joined lobby " + lobbyId);
    }

    @PostMapping("/{lobbyId}/leave")
    public MessageResponse leave(@PathVariable Long lobbyId) {
        return new MessageResponse("Left lobby " + lobbyId);
    }

    @PostMapping("/{lobbyId}/lock-cart")
    public MessageResponse lockCart(@PathVariable Long lobbyId) {
        return new MessageResponse("Cart locked for lobby " + lobbyId);
    }

    @PatchMapping("/{lobbyId}/status")
    public MessageResponse updateStatus(@PathVariable Long lobbyId, @Valid @RequestBody UpdateLobbyStatusRequest request) {
        return new MessageResponse("Lobby " + lobbyId + " status changed to " + request.status());
    }

    @PostMapping("/{lobbyId}/host-transfer")
    public MessageResponse transferHost(@PathVariable Long lobbyId, @Valid @RequestBody TransferHostRequest request) {
        return new MessageResponse("Lobby " + lobbyId + " host transferred to " + request.newHostUserId());
    }

    @PostMapping("/{lobbyId}/kick")
    public MessageResponse kick(@PathVariable Long lobbyId, @Valid @RequestBody KickMemberRequest request) {
        return new MessageResponse("User " + request.userId() + " kicked from lobby " + lobbyId);
    }

    public record CreateLobbyRequest(
        @NotBlank String restaurantName,
        @NotNull Long deliveryZoneId,
        @PositiveOrZero long minimumOrderAmount,
        @PositiveOrZero long deliveryFeeAmount
    ) {}
    public record UpdateLobbyStatusRequest(@NotBlank String status) {}
    public record TransferHostRequest(@NotNull Long newHostUserId) {}
    public record KickMemberRequest(@NotNull Long userId, String reason) {}
    public record LobbySummaryResponse(Long id, String restaurantName, Long deliveryZoneId, String status, boolean cartLocked) {}
    public record LobbyResponse(Long id, String restaurantName, Long deliveryZoneId, String status, boolean cartLocked) {}
    public record MessageResponse(String message) {}
}

