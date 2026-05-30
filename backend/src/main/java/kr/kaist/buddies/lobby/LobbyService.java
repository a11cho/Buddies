package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.chat.ChatArchiveService;
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
    private final LobbyEventPublisher lobbyEventPublisher;
    private final ChatArchiveService chatArchiveService;

    public LobbyService(
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        UserRepository userRepository,
        CartService cartService,
        ChatReadService chatReadService,
        PaymentService paymentService,
        LobbyEventPublisher lobbyEventPublisher,
        ChatArchiveService chatArchiveService
    ) {
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.userRepository = userRepository;
        this.cartService = cartService;
        this.chatReadService = chatReadService;
        this.paymentService = paymentService;
        this.lobbyEventPublisher = lobbyEventPublisher;
        this.chatArchiveService = chatArchiveService;
    }

    @Transactional(readOnly = true)
    public List<LobbySummaryResponse> list(Long userId, String deliveryLocation, String restaurantName) {
        DeliveryLocation location = parseDeliveryLocationOrNull(deliveryLocation);
        String normalizedRestaurantName = normalizeSearchText(restaurantName);
        return searchAvailableLobbies(location, normalizedRestaurantName).stream()
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
            throw LobbyErrorCode.LOBBY_NOT_JOINABLE.exception(HttpStatus.CONFLICT);
        }

        LobbyMembership membership = lobbyMembershipRepository.save(new LobbyMembership(lobby, user, LobbyMemberRole.PARTICIPANT));
        lobbyEventPublisher.memberJoined(lobbyId, userId, user.getName());
        return toMembershipResponse(membership);
    }

    @Transactional
    public LobbyMembershipResponse leave(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        if (!membership.isParticipant()) {
            throw LobbyErrorCode.HOST_LEAVE_FORBIDDEN.exception(HttpStatus.FORBIDDEN);
        }
        if (lobby.isCartLocked() || lobby.getOrderStatus() != LobbyOrderStatus.WAITING) {
            throw LobbyErrorCode.LOBBY_LEAVE_LOCKED.exception(HttpStatus.CONFLICT);
        }

        membership.leave(Instant.now());
        cartService.deleteActiveItemsOwnedBy(lobbyId, userId);
        lobbyEventPublisher.memberLeft(lobbyId, userId, membership.getUser().getName());
        return toMembershipResponse(membership);
    }

    @Transactional
    public LockCartResponse lockCart(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        if (!lobby.isOpenForJoin()) {
            throw LobbyErrorCode.LOBBY_LOCK_FORBIDDEN.exception(HttpStatus.CONFLICT);
        }
        if (lobby.getCurrentTotalAmount() < lobby.getMinimumOrderAmount()) {
            throw LobbyErrorCode.MINIMUM_ORDER_NOT_MET.exception(HttpStatus.CONFLICT);
        }

        String previousStatus = lobby.getOrderStatus().name();
        lobby.lockCart(Instant.now());
        paymentService.createOrRefreshForLockedLobby(lobby, userId);
        lobbyEventPublisher.cartLocked(lobbyId);
        return new LockCartResponse(lobbyId, previousStatus, lobby.getOrderStatus().name(), lobby.getCartLockedAt().toString());
    }

    @Transactional
    public LobbyStatusResponse updateStatus(Long userId, Long lobbyId, UpdateLobbyStatusRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobbyId, userId);
        LobbyOrderStatus nextStatus = parseOrderStatus(request.newStatus());
        validateStatusTransition(lobby, nextStatus);
        if (nextStatus == LobbyOrderStatus.ORDER_PLACED && !paymentService.allPayableRecordsPaid(lobbyId)) {
            throw LobbyErrorCode.PAYMENT_NOT_ALL_PAID.exception(HttpStatus.CONFLICT);
        }

        String previousStatus = lobby.getOrderStatus().name();
        lobby.changeStatus(nextStatus, Instant.now());
        lobbyEventPublisher.statusUpdated(lobbyId, LobbyOrderStatus.valueOf(previousStatus), nextStatus);
        return new LobbyStatusResponse(lobbyId, previousStatus, nextStatus.name());
    }

    @Transactional
    public TransferHostResponse transferHost(Long userId, Long lobbyId, TransferHostRequest request) {
        Lobby lobby = findLobby(lobbyId);
        LobbyMembership currentHost = requireHost(lobbyId, userId);
        if (lobby.getOrderStatus() != LobbyOrderStatus.WAITING || lobby.isCartLocked()) {
            throw LobbyErrorCode.HOST_TRANSFER_FORBIDDEN.exception(HttpStatus.CONFLICT);
        }
        LobbyMembership newHost = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, request.newHostUserId(), LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.TRANSFER_TARGET_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
        if (!newHost.isParticipant()) {
            throw LobbyErrorCode.HOST_TRANSFER_TARGET_INVALID.exception(HttpStatus.CONFLICT);
        }

        Instant now = Instant.now();
        currentHost.removeByTransfer(now);
        newHost.makeHost();
        lobby.transferHost(newHost.getUser(), now);
        cartService.deleteActiveItemsOwnedBy(lobbyId, userId);
        lobbyEventPublisher.hostTransferred(lobbyId, request.newHostUserId(), newHost.getUser().getName());
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
            throw LobbyErrorCode.KICK_FORBIDDEN_STATE.exception(HttpStatus.CONFLICT);
        }
        LobbyMembership target = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, request.targetUserId(), LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.KICK_TARGET_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
        if (!target.isParticipant()) {
            throw LobbyErrorCode.KICK_HOST_FORBIDDEN.exception(HttpStatus.CONFLICT);
        }

        target.kick(Instant.now());
        if (lobby.getOrderStatus() == LobbyOrderStatus.WAITING) {
            cartService.deleteActiveItemsOwnedBy(lobbyId, request.targetUserId());
        } else if (lobby.getOrderStatus() == LobbyOrderStatus.LOCKED) {
            paymentService.deactivateUserAndRefreshLockedLobby(lobby, request.targetUserId());
        }
        lobbyEventPublisher.memberKicked(lobbyId, request.targetUserId(), target.getUser().getName());
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
            throw LobbyErrorCode.LOBBY_DELETE_FORBIDDEN.exception(HttpStatus.CONFLICT);
        }

        lobby.changeStatus(nextStatus, Instant.now());
        lobbyEventPublisher.lobbyClosed(lobbyId, nextStatus);
        chatArchiveService.archiveLobby(lobbyId);
        return new DeleteLobbyResponse(lobbyId, previousStatus, nextStatus.name(), lobby.getDeletedAt().toString());
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> LobbyErrorCode.LOBBY_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> LobbyErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED));
    }

    private void rejectIfUserHasActiveLobby(Long userId) {
        if (lobbyMembershipRepository.existsActiveLobbyForUser(userId)) {
            throw LobbyErrorCode.ACTIVE_LOBBY_EXISTS.exception(HttpStatus.CONFLICT);
        }
    }

    private LobbyMembership requireActiveMember(Long lobbyId, Long userId) {
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
    }

    private LobbyMembership requireHost(Long lobbyId, Long userId) {
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        if (!membership.isHost()) {
            throw LobbyErrorCode.HOST_REQUIRED.exception(HttpStatus.FORBIDDEN);
        }
        return membership;
    }

    private DeliveryLocation parseDeliveryLocation(String value) {
        if (value == null || value.isBlank()) {
            throw LobbyErrorCode.INVALID_DELIVERY_LOCATION.exception(HttpStatus.BAD_REQUEST);
        }
        try {
            return DeliveryLocation.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw LobbyErrorCode.INVALID_DELIVERY_LOCATION.exception(HttpStatus.BAD_REQUEST);
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
            throw LobbyErrorCode.INVALID_LOBBY_STATUS.exception(HttpStatus.BAD_REQUEST);
        }
        try {
            return LobbyOrderStatus.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException exception) {
            throw LobbyErrorCode.INVALID_LOBBY_STATUS.exception(HttpStatus.BAD_REQUEST);
        }
    }

    private void validateStatusTransition(Lobby lobby, LobbyOrderStatus nextStatus) {
        LobbyOrderStatus current = lobby.getOrderStatus();
        if (nextStatus == LobbyOrderStatus.WAITING || nextStatus == LobbyOrderStatus.LOCKED) {
            throw LobbyErrorCode.STATUS_DIRECT_CHANGE_FORBIDDEN.exception(HttpStatus.CONFLICT);
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
        throw LobbyErrorCode.STATUS_TRANSITION_FORBIDDEN.exception(HttpStatus.CONFLICT);
    }

    private String normalizeSearchText(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private List<Lobby> searchAvailableLobbies(DeliveryLocation location, String restaurantName) {
        if (location != null && restaurantName != null) {
            return lobbyRepository.findAvailableByDeliveryLocationAndRestaurantName(location, restaurantName);
        }
        if (location != null) {
            return lobbyRepository.findAvailableByDeliveryLocation(location);
        }
        if (restaurantName != null) {
            return lobbyRepository.findAvailableByRestaurantName(restaurantName);
        }
        return lobbyRepository.findAvailable();
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
