package kr.kaist.buddies.lobby;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import kr.kaist.buddies.auth.domain.HostPaymentInfo;
import kr.kaist.buddies.auth.domain.HostPaymentInfoRepository;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/lobbies")
public class LobbyController {
    private final JdbcTemplate jdbcTemplate;
    private final HostPaymentInfoRepository hostPaymentInfoRepository;

    public LobbyController(JdbcTemplate jdbcTemplate, HostPaymentInfoRepository hostPaymentInfoRepository) {
        this.jdbcTemplate = jdbcTemplate;
        this.hostPaymentInfoRepository = hostPaymentInfoRepository;
    }

    @GetMapping
    public List<LobbySummaryResponse> list() {
        return List.of();
    }

    @PostMapping
    public LobbyResponse create(@Valid @RequestBody CreateLobbyRequest request) {
        // TODO: Read host user id from JWT and enforce one active lobby per user.
        return new LobbyResponse(1L, request.restaurantName(), request.deliveryLocation(), "WAITING", false, 0L, request.minimumOrderAmount(), null, null, null);
    }

    @GetMapping("/{lobbyId}")
    public LobbyResponse get(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        if (!isActiveLobbyMember(lobbyId, user.id())) {
            throw new AuthException(HttpStatus.FORBIDDEN, "로비 멤버만 로비 상세 정보를 조회할 수 있습니다.");
        }
        return findLobby(lobbyId);
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
    public MessageResponse lockCart(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        if (!hostPaymentInfoRepository.existsByUser_Id(user.id())) {
            throw new AuthException(HttpStatus.CONFLICT, "Cart Locking 전에 계좌 정보를 등록해야 합니다.");
        }
        return new MessageResponse("Cart locked for lobby " + lobbyId);
    }

    @PatchMapping("/{lobbyId}/status")
    public MessageResponse updateStatus(@PathVariable Long lobbyId, @Valid @RequestBody UpdateLobbyStatusRequest request) {
        return new MessageResponse("Lobby " + lobbyId + " status changed to " + request.newStatus());
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
        @PositiveOrZero long deliveryFee
    ) {}
    public record UpdateLobbyStatusRequest(@NotBlank String newStatus) {}
    public record TransferHostRequest(@NotNull Long newHostUserId) {}
    public record KickMemberRequest(@NotNull Long targetUserId, String reason) {}
    public record LobbySummaryResponse(Long id, String restaurantName, String deliveryLocation, String orderStatus, boolean cartLocked) {}
    public record LobbyResponse(
        Long id,
        String restaurantName,
        String deliveryLocation,
        String orderStatus,
        boolean cartLocked,
        long currentTotalAmount,
        long minimumOrderAmount,
        String hostBankName,
        String hostAccountNumber,
        String hostAccountHolderName
    ) {}
    public record MessageResponse(String message) {}

    private LobbyResponse findLobby(Long lobbyId) {
        List<LobbyResponse> lobbies = jdbcTemplate.query(
            """
            SELECT id, host_user_id, restaurant_name, delivery_location, order_status,
                   cart_locked_at, current_total_amount, minimum_order_amount
            FROM lobbies
            WHERE id = ? AND deleted_at IS NULL
            """,
            (rs, rowNum) -> mapLobby(rs),
            lobbyId
        );
        if (lobbies.isEmpty()) {
            throw new AuthException(HttpStatus.NOT_FOUND, "대상 로비를 찾을 수 없습니다.");
        }
        return lobbies.getFirst();
    }

    private LobbyResponse mapLobby(ResultSet rs) throws SQLException {
        String orderStatus = rs.getString("order_status");
        Long hostUserId = rs.getLong("host_user_id");
        HostPaymentInfo paymentInfo = exposesHostPaymentInfo(orderStatus)
            ? hostPaymentInfoRepository.findByUser_Id(hostUserId).orElse(null)
            : null;
        return new LobbyResponse(
            rs.getLong("id"),
            rs.getString("restaurant_name"),
            rs.getString("delivery_location"),
            orderStatus,
            rs.getTimestamp("cart_locked_at") != null,
            rs.getLong("current_total_amount"),
            rs.getLong("minimum_order_amount"),
            paymentInfo == null ? null : paymentInfo.getBankName(),
            paymentInfo == null ? null : paymentInfo.getAccountNumber(),
            paymentInfo == null ? null : paymentInfo.getAccountHolderName()
        );
    }

    private boolean exposesHostPaymentInfo(String orderStatus) {
        return !"WAITING".equals(orderStatus) && !"CANCELED".equals(orderStatus) && !"CLOSED".equals(orderStatus);
    }

    private boolean isActiveLobbyMember(Long lobbyId, Long userId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM lobby_memberships WHERE lobby_id = ? AND user_id = ? AND status = 'ACTIVE'",
            Integer.class,
            lobbyId,
            userId
        );
        return count != null && count > 0;
    }
}
