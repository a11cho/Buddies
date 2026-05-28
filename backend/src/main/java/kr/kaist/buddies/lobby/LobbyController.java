package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/lobbies")
public class LobbyController {
    private final LobbyService lobbyService;

    public LobbyController(LobbyService lobbyService) {
        this.lobbyService = lobbyService;
    }

    @GetMapping
    public List<LobbySummaryResponse> list(
        @CurrentUser AuthenticatedUser user,
        @RequestParam(required = false) String deliveryLocation,
        @RequestParam(required = false) String restaurantName
    ) {
        return lobbyService.list(user.id(), deliveryLocation, restaurantName);
    }

    @PostMapping
    public LobbyResponse create(@CurrentUser AuthenticatedUser user, @Valid @RequestBody CreateLobbyRequest request) {
        return lobbyService.create(user.id(), request);
    }

    @GetMapping("/{lobbyId}")
    public LobbyResponse get(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.get(user.id(), lobbyId);
    }

    @PostMapping("/{lobbyId}/join")
    public LobbyMembershipResponse join(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.join(user.id(), lobbyId);
    }

    @PostMapping("/{lobbyId}/leave")
    public LobbyMembershipResponse leave(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.leave(user.id(), lobbyId);
    }

    @PostMapping("/{lobbyId}/cart/lock")
    public LockCartResponse lockCart(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.lockCart(user.id(), lobbyId);
    }

    @PatchMapping("/{lobbyId}/status")
    public LobbyStatusResponse updateStatus(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @Valid @RequestBody UpdateLobbyStatusRequest request) {
        return lobbyService.updateStatus(user.id(), lobbyId, request);
    }

    @PostMapping("/{lobbyId}/transfer-host")
    public TransferHostResponse transferHost(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @Valid @RequestBody TransferHostRequest request) {
        return lobbyService.transferHost(user.id(), lobbyId, request);
    }

    @PostMapping("/{lobbyId}/kick")
    public KickParticipantResponse kick(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId, @Valid @RequestBody KickMemberRequest request) {
        return lobbyService.kick(user.id(), lobbyId, request);
    }

    @DeleteMapping("/{lobbyId}")
    public DeleteLobbyResponse delete(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.delete(user.id(), lobbyId);
    }

    public record CreateLobbyRequest(
        @NotBlank String restaurantName,
        @NotBlank String deliveryLocation,
        @PositiveOrZero long minimumOrderAmount,
        @PositiveOrZero long deliveryFee
    ) {}
    public record UpdateLobbyStatusRequest(@NotBlank String newStatus) {}
    public record TransferHostRequest(@NotNull Long newHostUserId) {}
    public record KickMemberRequest(@NotNull Long targetUserId, String reason) {}
    public record LobbySummaryResponse(
        Long lobbyId,
        Long hostUserId,
        String hostName,
        double hostTrustScore,
        String restaurantName,
        String deliveryLocation,
        long minimumOrderAmount,
        long currentTotalAmount,
        long remainingAmount,
        long participantCount,
        String orderStatus,
        Long lastReadMessageId,
        long unreadCount
    ) {}
    public record LobbyResponse(
        Long lobbyId,
        Long hostUserId,
        String restaurantName,
        String deliveryLocation,
        long minimumOrderAmount,
        long currentTotalAmount,
        long deliveryFee,
        long participantCount,
        String orderStatus,
        String cartLockedAt,
        Long lastReadMessageId,
        long unreadCount
    ) {}
    public record LobbyMembershipResponse(
        Long lobbyId,
        Long userId,
        String roleInLobby,
        String membershipStatus,
        String joinedAt,
        String leftAt
    ) {}
    public record LockCartResponse(Long lobbyId, String previousStatus, String orderStatus, String cartLockedAt) {}
    public record LobbyStatusResponse(Long lobbyId, String previousStatus, String newStatus) {}
    public record KickParticipantResponse(Long lobbyId, Long kickedUserId, String membershipStatus, Long kickedBy) {}
    public record TransferHostResponse(
        Long lobbyId,
        Long previousHostUserId,
        Long newHostUserId,
        String previousHostMembershipStatus,
        String newHostRole
    ) {}
    public record DeleteLobbyResponse(Long lobbyId, String previousStatus, String newStatus, String deletedAt) {}
    public record MessageResponse(String message) {}
}
