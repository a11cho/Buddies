package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.lobby.CartPaymentController.PaymentRecordResponse;
import kr.kaist.buddies.lobby.domain.CartItemRepository;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.lobby.domain.LobbyMemberRole;
import kr.kaist.buddies.lobby.domain.LobbyMembership;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import kr.kaist.buddies.lobby.domain.LobbyOrderStatus;
import kr.kaist.buddies.lobby.domain.LobbyRepository;
import kr.kaist.buddies.lobby.domain.PaymentRecord;
import kr.kaist.buddies.lobby.domain.PaymentRecordRepository;
import kr.kaist.buddies.lobby.domain.PaymentRecordStatus;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentService {
    private final PaymentRecordRepository paymentRecordRepository;
    private final LobbyRepository lobbyRepository;
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final CartItemRepository cartItemRepository;
    private final UserRepository userRepository;
    private final LobbyEventPublisher lobbyEventPublisher;

    public PaymentService(
        PaymentRecordRepository paymentRecordRepository,
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        CartItemRepository cartItemRepository,
        UserRepository userRepository,
        LobbyEventPublisher lobbyEventPublisher
    ) {
        this.paymentRecordRepository = paymentRecordRepository;
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.cartItemRepository = cartItemRepository;
        this.userRepository = userRepository;
        this.lobbyEventPublisher = lobbyEventPublisher;
    }

    @Transactional(readOnly = true)
    public List<PaymentRecordResponse> list(Long userId, Long lobbyId) {
        requirePaymentAccess(lobbyId, userId);
        return paymentRecordRepository.findByLobby_IdOrderByIdAsc(lobbyId).stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public PaymentRecordResponse confirm(Long hostUserId, Long lobbyId, Long paymentRecordId) {
        Lobby lobby = findLobby(lobbyId);
        User host = requireHost(lobbyId, hostUserId);
        if (lobby.getOrderStatus() != LobbyOrderStatus.LOCKED) {
            throw LobbyErrorCode.PAYMENT_CONFIRM_STATE_INVALID.exception(HttpStatus.CONFLICT);
        }
        PaymentRecord paymentRecord = paymentRecordRepository.findByIdAndLobby_Id(paymentRecordId, lobbyId)
            .orElseThrow(() -> LobbyErrorCode.PAYMENT_RECORD_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
        if (paymentRecord.getStatus() == PaymentRecordStatus.INACTIVE) {
            throw LobbyErrorCode.PAYMENT_RECORD_INACTIVE.exception(HttpStatus.CONFLICT);
        }

        paymentRecord.markPaid(host, Instant.now());
        lobbyEventPublisher.paymentRecordUpdated(lobbyId, paymentRecord.getUser().getId(), paymentRecord.getUser().getName());
        return toResponse(paymentRecord);
    }

    @Transactional
    public void createOrRefreshForLockedLobby(Lobby lobby, Long hostUserId) {
        User host = userRepository.findById(hostUserId)
            .orElseThrow(() -> LobbyErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED));
        refreshActiveMemberRecords(lobby, host);
    }

    @Transactional
    public void deactivateUserAndRefreshLockedLobby(Lobby lobby, Long userId) {
        markInactiveForUser(lobby.getId(), userId);
        refreshActiveMemberRecords(lobby, lobby.getHost());
    }

    @Transactional
    public void markInactiveForUser(Long lobbyId, Long userId) {
        paymentRecordRepository.findByLobby_IdAndUser_Id(lobbyId, userId)
            .ifPresent(paymentRecord -> paymentRecord.markInactive(Instant.now()));
    }

    @Transactional(readOnly = true)
    public boolean allPayableRecordsPaid(Long lobbyId) {
        return paymentRecordRepository.existsByLobby_Id(lobbyId)
            && paymentRecordRepository.allActiveRecordsPaid(lobbyId);
    }

    private void refreshActiveMemberRecords(Lobby lobby, User host) {
        List<LobbyMembership> activeMembers = lobbyMembershipRepository.findByLobby_IdAndStatus(lobby.getId(), LobbyMembershipStatus.ACTIVE);
        if (activeMembers.isEmpty()) {
            throw LobbyErrorCode.NO_PAYABLE_MEMBERS.exception(HttpStatus.CONFLICT);
        }

        long baseDeliveryShare = lobby.getDeliveryFee() / activeMembers.size();
        long deliveryRemainder = lobby.getDeliveryFee() % activeMembers.size();
        for (LobbyMembership membership : activeMembers) {
            User member = membership.getUser();
            long foodAmount = cartItemRepository.sumActiveSubtotalByLobbyIdAndOwnerId(lobby.getId(), member.getId());
            long deliveryShare = baseDeliveryShare + (membership.isHost() ? deliveryRemainder : 0);
            long amount = foodAmount + deliveryShare;
            PaymentRecord paymentRecord = paymentRecordRepository.findByLobby_IdAndUser_Id(lobby.getId(), member.getId())
                .orElseGet(() -> paymentRecordRepository.save(new PaymentRecord(lobby, member, amount)));
            paymentRecord.resetAmount(amount);
            if (membership.isHost()) {
                paymentRecord.markPaid(host, Instant.now());
            }
        }
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> LobbyErrorCode.LOBBY_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private User requireHost(Long lobbyId, Long userId) {
        LobbyMembership membership = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
        if (membership.getRoleInLobby() != LobbyMemberRole.HOST) {
            throw LobbyErrorCode.HOST_REQUIRED.exception(HttpStatus.FORBIDDEN);
        }
        return membership.getUser();
    }

    private void requirePaymentAccess(Long lobbyId, Long userId) {
        boolean activeMember = lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE).isPresent();
        boolean ownsPaymentRecord = paymentRecordRepository.findByLobby_IdAndUser_Id(lobbyId, userId).isPresent();
        if (!activeMember && !ownsPaymentRecord) {
            throw LobbyErrorCode.PAYMENT_ACCESS_FORBIDDEN.exception(HttpStatus.FORBIDDEN);
        }
    }

    private PaymentRecordResponse toResponse(PaymentRecord paymentRecord) {
        return new PaymentRecordResponse(
            paymentRecord.getId(),
            paymentRecord.getLobby().getId(),
            paymentRecord.getUser().getId(),
            paymentRecord.getAmount(),
            paymentRecord.getStatus().name(),
            paymentRecord.getConfirmedByHost() == null ? null : paymentRecord.getConfirmedByHost().getId(),
            paymentRecord.getConfirmedAt() == null ? null : paymentRecord.getConfirmedAt().toString()
        );
    }
}
