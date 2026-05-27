package kr.kaist.buddies.lobby;

import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.auth.AuthException;
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
            throw new AuthException(HttpStatus.CONFLICT, "결제 확인은 LOCKED 상태에서만 가능합니다.");
        }
        PaymentRecord paymentRecord = paymentRecordRepository.findByIdAndLobby_Id(paymentRecordId, lobbyId)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "결제 기록을 찾을 수 없습니다."));
        if (paymentRecord.getStatus() == PaymentRecordStatus.INACTIVE) {
            throw new AuthException(HttpStatus.CONFLICT, "비활성화된 결제 기록은 확인할 수 없습니다.");
        }

        paymentRecord.markPaid(host, Instant.now());
        lobbyEventPublisher.paymentRecordUpdated(lobbyId, paymentRecord.getUser().getId(), paymentRecord.getUser().getName());
        return toResponse(paymentRecord);
    }

    @Transactional
    public void createOrRefreshForLockedLobby(Lobby lobby, Long hostUserId) {
        User host = userRepository.findById(hostUserId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
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
            throw new AuthException(HttpStatus.CONFLICT, "정산할 로비 멤버가 없습니다.");
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
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "존재하지 않는 로비입니다."));
    }

    private User requireHost(Long lobbyId, Long userId) {
        LobbyMembership membership = lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.FORBIDDEN, "해당 로비에 대한 접근 권한이 없습니다."));
        if (membership.getRoleInLobby() != LobbyMemberRole.HOST) {
            throw new AuthException(HttpStatus.FORBIDDEN, "Host 권한이 필요합니다.");
        }
        return membership.getUser();
    }

    private void requirePaymentAccess(Long lobbyId, Long userId) {
        boolean activeMember = lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE).isPresent();
        boolean ownsPaymentRecord = paymentRecordRepository.findByLobby_IdAndUser_Id(lobbyId, userId).isPresent();
        if (!activeMember && !ownsPaymentRecord) {
            throw new AuthException(HttpStatus.FORBIDDEN, "정산 기록에 접근할 권한이 없습니다.");
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
