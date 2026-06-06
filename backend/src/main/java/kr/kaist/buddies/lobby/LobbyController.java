package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.util.List;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
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
    private final ReceiptAttachmentService receiptAttachmentService;

    public LobbyController(LobbyService lobbyService, ReceiptAttachmentService receiptAttachmentService) {
        this.lobbyService = lobbyService;
        this.receiptAttachmentService = receiptAttachmentService;
    }

    @GetMapping
    public List<LobbySummaryResponse> list(
        @CurrentUser AuthenticatedUser user,
        @RequestParam(required = false) String deliveryZone,
        @RequestParam(required = false) String restaurantName
    ) {
        return lobbyService.list(user.id(), deliveryZone, restaurantName);
    }

    @PostMapping
    public LobbyResponse create(@CurrentUser AuthenticatedUser user, @Valid @RequestBody CreateLobbyRequest request) {
        return lobbyService.create(user.id(), request);
    }

    @GetMapping("/me/active")
    public ResponseEntity<LobbySummaryResponse> activeLobby(@CurrentUser AuthenticatedUser user) {
        return lobbyService.activeLobby(user.id())
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.noContent().build());
    }

    @GetMapping("/me")
    public List<MyLobbyResponse> myLobbies(@CurrentUser AuthenticatedUser user) {
        return lobbyService.myLobbies(user.id());
    }

    @GetMapping("/{lobbyId}")
    public LobbyResponse get(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.get(user.id(), lobbyId);
    }

    @GetMapping("/{lobbyId}/members")
    public List<LobbyMemberResponse> members(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return lobbyService.members(user.id(), lobbyId);
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

    @PostMapping("/{lobbyId}/receipt/upload-url")
    public ReceiptUploadUrlResponse receiptUploadUrl(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @Valid @RequestBody ReceiptUploadUrlRequest request
    ) {
        return receiptAttachmentService.issueUploadUrl(user.id(), lobbyId, request);
    }

    @PostMapping("/{lobbyId}/receipt")
    public ReceiptResponse attachReceipt(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @Valid @RequestBody ReceiptAttachRequest request
    ) {
        return receiptAttachmentService.attach(user.id(), lobbyId, request);
    }

    @GetMapping("/{lobbyId}/receipt")
    public ReceiptResponse receipt(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        return receiptAttachmentService.get(user.id(), lobbyId);
    }

    public record CreateLobbyRequest(
        @NotBlank String restaurantName,
        @NotBlank String deliveryZone,
        @PositiveOrZero long minimumOrderAmount,
        @PositiveOrZero long deliveryFee
    ) {}
    public record UpdateLobbyStatusRequest(@NotBlank String newStatus) {}
    public record TransferHostRequest(@NotNull Long newHostUserId) {}
    public record KickMemberRequest(@NotNull Long targetUserId, String reason) {}
    public record ReceiptUploadUrlRequest(@NotBlank String filename, @NotBlank String contentType, Long fileSizeBytes) {}
    public record ReceiptAttachRequest(
        @NotBlank String receiptImageUrl,
        String originalFilename,
        @NotBlank String contentType,
        Long fileSizeBytes,
        String checksum
    ) {}
    public record LobbySummaryResponse(
        Long lobbyId,
        Long hostUserId,
        String hostName,
        double hostTrustScore,
        String restaurantName,
        String deliveryZone,
        long minimumOrderAmount,
        long currentTotalAmount,
        long remainingAmount,
        long deliveryFee,
        long participantCount,
        String orderStatus,
        Long lastReadMessageId,
        long unreadCount
    ) {}
    public record LobbyResponse(
        Long lobbyId,
        Long hostUserId,
        String restaurantName,
        String deliveryZone,
        long minimumOrderAmount,
        long currentTotalAmount,
        long deliveryFee,
        long participantCount,
        String orderStatus,
        String cartLockedAt,
        Long lastReadMessageId,
        long unreadCount,
        String hostBankName,
        String hostAccountNumber,
        String hostAccountHolderName
    ) {}
    public record LobbyMembershipResponse(
        Long lobbyId,
        Long userId,
        String roleInLobby,
        String membershipStatus,
        String joinedAt,
        String leftAt
    ) {}
    public record LobbyMemberResponse(
        Long userId,
        String name,
        String roleInLobby,
        String membershipStatus,
        String joinedAt,
        String leftAt,
        Long lastReadMessageId,
        String lastReadAt,
        double trustScore
    ) {}
    public record MyLobbyResponse(
        Long lobbyId,
        String restaurantName,
        String deliveryZone,
        long minimumOrderAmount,
        long currentTotalAmount,
        long remainingAmount,
        long deliveryFee,
        String orderStatus,
        String hostName,
        long participantCount,
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
    public record ReceiptUploadUrlResponse(String uploadUrl, String mediaUrl, long expiresIn) {}
    public record ReceiptResponse(Long lobbyId, String receiptImageUrl, Long uploadedByUserId, String uploadedAt) {}
    public record MessageResponse(String message) {}
}
