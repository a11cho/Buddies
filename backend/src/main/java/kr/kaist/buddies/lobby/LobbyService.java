package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.chat.ChatReadService;
import kr.kaist.buddies.lobby.LobbyController.CreateLobbyRequest;
import kr.kaist.buddies.lobby.LobbyController.DeleteLobbyResponse;
import kr.kaist.buddies.lobby.LobbyController.KickMemberRequest;
import kr.kaist.buddies.lobby.LobbyController.KickParticipantResponse;
import kr.kaist.buddies.lobby.LobbyController.LobbyStatusResponse;
import kr.kaist.buddies.lobby.LobbyController.LobbyMembershipResponse;
import kr.kaist.buddies.lobby.LobbyController.LobbyResponse;
import kr.kaist.buddies.lobby.LobbyController.LobbySummaryResponse;
import kr.kaist.buddies.lobby.LobbyController.LockCartResponse;
import kr.kaist.buddies.lobby.LobbyController.TransferHostResponse;
import kr.kaist.buddies.lobby.LobbyController.TransferHostRequest;
import kr.kaist.buddies.lobby.LobbyController.UpdateLobbyStatusRequest;
import kr.kaist.buddies.lobby.domain.DeliveryLocation;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.lobby.domain.LobbyMemberRole;
import kr.kaist.buddies.lobby.domain.LobbyMembership;
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
public class LobbyService {
    private final LobbyRepository lobbyRepository;
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final UserRepository userRepository;
    private final CartService cartService;
    private final ChatReadService chatReadService;
    private final PaymentService paymentService;

    public LobbyService(
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        UserRepository userRepository,
        CartService cartService,
        ChatReadService chatReadService,
        PaymentService paymentService
    ) {
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.userRepository = userRepository;
        this.cartService = cartService;
        this.chatReadService = chatReadService;
        this.paymentService = paymentService;
    }

    @Transactional(readOnly = true)
    public List<LobbySummaryResponse> list(Long userId, String deliveryLocation, String restaurantName) {
        DeliveryLocation location = parseDeliveryLocationOrNull(deliveryLocation);
        String normalizedRestaurantName = normalizeSearchText(restaurantName);
        return lobbyRepository.searchAvailable(location, normalizedRestaurantName).stream()
            .map(lobby -> toSummaryResponse(lobby, userId))
            .toList();
    }

    @Transactional
    public LobbyResponse create(Long userId, CreateLobbyRequest request) {
        User host = findUser(userId);
        rejectIfUserHasActiveLobby(userId);

        DeliveryLocation location = parseDeliveryLocation(request.deliveryLocation());
        Lobby lobby = lobbyRepository.save(new Lobby(
            host,
            request.restaurantName().trim(),
            location,
            request.minimumOrderAmount(),
            request.deliveryFee()
        ));
        lobbyMembershipRepository.save(new LobbyMembership(lobby, host, LobbyMemberRole.HOST));
        return toResponse(lobby, userId);
    }

    @Transactional(readOnly = true)
    public LobbyResponse get(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        requireActiveMember(lobbyId, userId);
        return toResponse(lobby, userId);
    }

    @Transactional
    public LobbyMembershipResponse join(Long userId, Long lobbyId) {
        User user = findUser(userId);
        Lobby lobby = findLobby(lobbyId);
        rejectIfUserHasActiveLobby(userId);
        if (!lobby.isOpenForJoin()) {
            throw new AuthException(HttpStatus.CONFLICT, "참여할 수 없는 로비입니다.");
        }

        LobbyMembership membership = lobbyMembershipRepository.save(new LobbyMembership(lobby, user, LobbyMemberRole.PARTICIPANT));
        return toMembershipResponse(membership);
    }

    @Transactional
    public LobbyMembershipResponse leave(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        if (!membership.isParticipant()) {
            throw new AuthException(HttpStatus.FORBIDDEN, "Host는 이 API로 로비를 나갈 수 없습니다.");
        }
        if (lobby.isCartLocked() || lobby.getOrderStatus() != LobbyOrderStatus.WAITING) {
            throw new AuthException(HttpStatus.CONFLICT, "이미 잠긴 로비에서는 직접 나갈 수 없습니다.");
        }

        membership.leave(Instant.now());
        cartService.deleteActiveItemsOwnedBy(lobbyId, userId);
        return toMembershipResponse(membership);
    }

    @Transactional
    public LockCartResponse lockCart(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        if (!lobby.isOpenForJoin()) {
            throw new AuthException(HttpStatus.CONFLICT, "잠글 수 없는 로비 상태입니다.");
        }
        if (lobby.getCurrentTotalAmount() < lobby.getMinimumOrderAmount()) {
            throw new AuthException(HttpStatus.CONFLICT, "최소 주문 금액을 충족하지 못했습니다.");
        }

        String previousStatus = lobby.getOrderStatus().name();
        lobby.lockCart(Instant.now());
        paymentService.createOrRefreshForLockedLobby(lobby, userId);
        return new LockCartResponse(lobbyId, previousStatus, lobby.getOrderStatus().name(), lobby.getCartLockedAt().toString());
    }

    @Transactional
    public LobbyStatusResponse updateStatus(Long userId, Long lobbyId, UpdateLobbyStatusRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        LobbyOrderStatus nextStatus = parseOrderStatus(request.newStatus());
        validateStatusTransition(lobby, nextStatus);
        if (nextStatus == LobbyOrderStatus.ORDER_PLACED && !paymentService.allPayableRecordsPaid(lobbyId)) {
            throw new AuthException(HttpStatus.CONFLICT, "모든 정산 기록이 PAID 상태가 아닙니다.");
        }

        String previousStatus = lobby.getOrderStatus().name();
        lobby.changeStatus(nextStatus, Instant.now());
        return new LobbyStatusResponse(lobbyId, previousStatus, nextStatus.name());
    }

    @Transactional
    public TransferHostResponse transferHost(Long userId, Long lobbyId, TransferHostRequest request) {
        Lobby lobby = findLobby(lobbyId);
        LobbyMembership currentHost = requireHost(lobbyId, userId);
        if (lobby.getOrderStatus() != LobbyOrderStatus.WAITING || lobby.isCartLocked()) {
            throw new AuthException(HttpStatus.CONFLICT, "현재 로비 상태에서는 Host 권한을 위임할 수 없습니다.");
        }
        LobbyMembership newHost = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, request.newHostUserId(), LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "위임할 참여자를 찾을 수 없습니다."));
        if (!newHost.isParticipant()) {
            throw new AuthException(HttpStatus.CONFLICT, "Host 권한은 Participant에게만 위임할 수 있습니다.");
        }

        Instant now = Instant.now();
        currentHost.removeByTransfer(now);
        newHost.makeHost();
        lobby.transferHost(newHost.getUser(), now);
        cartService.deleteActiveItemsOwnedBy(lobbyId, userId);
        return new TransferHostResponse(
            lobbyId,
            userId,
            request.newHostUserId(),
            currentHost.getStatus().name(),
            newHost.getRoleInLobby().name()
        );
    }

    @Transactional
    public KickParticipantResponse kick(Long userId, Long lobbyId, KickMemberRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        if (lobby.getOrderStatus() == LobbyOrderStatus.ORDER_PLACED
            || lobby.getOrderStatus() == LobbyOrderStatus.OUT_FOR_DELIVERY
            || lobby.getOrderStatus() == LobbyOrderStatus.DELIVERED
            || lobby.isClosedOrCanceled()) {
            throw new AuthException(HttpStatus.CONFLICT, "현재 로비 상태에서는 참여자를 강퇴할 수 없습니다.");
        }
        LobbyMembership target = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, request.targetUserId(), LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "강퇴할 참여자를 찾을 수 없습니다."));
        if (!target.isParticipant()) {
            throw new AuthException(HttpStatus.CONFLICT, "Host는 강퇴할 수 없습니다.");
        }

        target.kick(Instant.now());
        if (lobby.getOrderStatus() == LobbyOrderStatus.WAITING) {
            cartService.deleteActiveItemsOwnedBy(lobbyId, request.targetUserId());
        } else if (lobby.getOrderStatus() == LobbyOrderStatus.LOCKED) {
            paymentService.markInactiveForUser(lobbyId, request.targetUserId());
        }
        return new KickParticipantResponse(lobbyId, request.targetUserId(), target.getStatus().name(), userId);
    }

    @Transactional
    public DeleteLobbyResponse delete(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        String previousStatus = lobby.getOrderStatus().name();
        LobbyOrderStatus nextStatus;
        if (lobby.getOrderStatus() == LobbyOrderStatus.WAITING && !lobby.isCartLocked()) {
            nextStatus = LobbyOrderStatus.CANCELED;
        } else if (lobby.getOrderStatus() == LobbyOrderStatus.DELIVERED) {
            nextStatus = LobbyOrderStatus.CLOSED;
        } else {
            throw new AuthException(HttpStatus.CONFLICT, "현재 상태에서는 로비를 종료할 수 없습니다.");
        }

        lobby.changeStatus(nextStatus, Instant.now());
        return new DeleteLobbyResponse(lobbyId, previousStatus, nextStatus.name(), lobby.getDeletedAt().toString());
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "존재하지 않는 로비입니다."));
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
    }

    private void rejectIfUserHasActiveLobby(Long userId) {
        if (lobbyMembershipRepository.existsActiveLobbyForUser(userId)) {
            throw new AuthException(HttpStatus.CONFLICT, "이미 참여 중인 로비가 있습니다.");
        }
    }

    private LobbyMembership requireActiveMember(Long lobbyId, Long userId) {
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.FORBIDDEN, "해당 로비에 대한 접근 권한이 없습니다."));
    }

    private LobbyMembership requireHost(Long lobbyId, Long userId) {
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        if (!membership.isHost()) {
            throw new AuthException(HttpStatus.FORBIDDEN, "Host 권한이 필요합니다.");
        }
        return membership;
    }

    private DeliveryLocation parseDeliveryLocation(String value) {
        if (value == null || value.isBlank()) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "배달 위치가 올바르지 않습니다.");
        }
        try {
            return DeliveryLocation.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "배달 위치가 올바르지 않습니다.");
        }
    }

    private DeliveryLocation parseDeliveryLocationOrNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return parseDeliveryLocation(value);
    }

    private LobbyOrderStatus parseOrderStatus(String value) {
        if (value == null || value.isBlank()) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "로비 상태가 올바르지 않습니다.");
        }
        try {
            return LobbyOrderStatus.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "로비 상태가 올바르지 않습니다.");
        }
    }

    private void validateStatusTransition(Lobby lobby, LobbyOrderStatus nextStatus) {
        LobbyOrderStatus current = lobby.getOrderStatus();
        if (nextStatus == LobbyOrderStatus.WAITING || nextStatus == LobbyOrderStatus.LOCKED) {
            throw new AuthException(HttpStatus.CONFLICT, "요청한 상태로 직접 변경할 수 없습니다.");
        }
        if (current == LobbyOrderStatus.LOCKED && nextStatus == LobbyOrderStatus.ORDER_PLACED) {
            return;
        }
        if (current == LobbyOrderStatus.ORDER_PLACED && nextStatus == LobbyOrderStatus.OUT_FOR_DELIVERY) {
            return;
        }
        if (current == LobbyOrderStatus.OUT_FOR_DELIVERY && nextStatus == LobbyOrderStatus.DELIVERED) {
            return;
        }
        throw new AuthException(HttpStatus.CONFLICT, "허용되지 않는 로비 상태 변경입니다.");
    }

    private String normalizeSearchText(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private LobbySummaryResponse toSummaryResponse(Lobby lobby, Long userId) {
        long participantCount = lobbyMembershipRepository.countByLobby_IdAndStatus(lobby.getId(), LobbyMembershipStatus.ACTIVE);
        long remainingAmount = Math.max(0, lobby.getMinimumOrderAmount() - lobby.getCurrentTotalAmount());
        ReadState readState = readStateFor(lobby.getId(), userId);
        return new LobbySummaryResponse(
            lobby.getId(),
            lobby.getHost().getId(),
            lobby.getHost().getName(),
            lobby.getHost().getTrustScore().doubleValue(),
            lobby.getRestaurantName(),
            lobby.getDeliveryLocation().name(),
            lobby.getMinimumOrderAmount(),
            lobby.getCurrentTotalAmount(),
            remainingAmount,
            participantCount,
            lobby.getOrderStatus().name(),
            readState.lastReadMessageId(),
            readState.unreadCount()
        );
    }

    private LobbyResponse toResponse(Lobby lobby, Long userId) {
        long participantCount = lobbyMembershipRepository.countByLobby_IdAndStatus(lobby.getId(), LobbyMembershipStatus.ACTIVE);
        ReadState readState = readStateFor(lobby.getId(), userId);
        return new LobbyResponse(
            lobby.getId(),
            lobby.getHost().getId(),
            lobby.getRestaurantName(),
            lobby.getDeliveryLocation().name(),
            lobby.getMinimumOrderAmount(),
            lobby.getCurrentTotalAmount(),
            lobby.getDeliveryFee(),
            participantCount,
            lobby.getOrderStatus().name(),
            lobby.getCartLockedAt() == null ? null : lobby.getCartLockedAt().toString(),
            readState.lastReadMessageId(),
            readState.unreadCount()
        );
    }

    private LobbyMembershipResponse toMembershipResponse(LobbyMembership membership) {
        return new LobbyMembershipResponse(
            membership.getLobby().getId(),
            membership.getUser().getId(),
            membership.getRoleInLobby().name(),
            membership.getStatus().name(),
            membership.getJoinedAt() == null ? null : membership.getJoinedAt().toString(),
            membership.getLeftAt() == null ? null : membership.getLeftAt().toString()
        );
    }

    private ReadState readStateFor(Long lobbyId, Long userId) {
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .map(membership -> new ReadState(
                membership.getLastReadMessageId(),
                chatReadService.countUnread(lobbyId, membership.getLastReadMessageId())
            ))
            .orElse(new ReadState(null, 0));
    }

    private record ReadState(Long lastReadMessageId, long unreadCount) {}
}
