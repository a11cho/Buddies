package kr.kaist.buddies.chat;

import java.util.List;
import kr.kaist.buddies.chat.ChatController.ChatMessageResponse;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatPushNotificationService {
    private static final Logger log = LoggerFactory.getLogger(ChatPushNotificationService.class);

    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final StompSessionManager stompSessionManager;

    public ChatPushNotificationService(
        LobbyMembershipRepository lobbyMembershipRepository,
        StompSessionManager stompSessionManager
    ) {
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.stompSessionManager = stompSessionManager;
    }

    @Transactional(readOnly = true)
    public void notifyOfflineMembers(ChatMessageResponse message) {
        List<Long> activeMemberIds = lobbyMembershipRepository
            .findByLobby_IdAndStatus(message.lobbyId(), LobbyMembershipStatus.ACTIVE)
            .stream()
            .map(membership -> membership.getUser().getId())
            .filter(userId -> !userId.equals(message.senderUserId()))
            .toList();
        List<Long> offlineUserIds = stompSessionManager.offlineUserIdsInLobby(message.lobbyId(), activeMemberIds);
        offlineUserIds.forEach(userId -> sendNoOp(userId, message));
    }

    private void sendNoOp(Long userId, ChatMessageResponse message) {
        log.info(
            "Push notification skipped because device token provider is not configured. userId={}, lobbyId={}, messageId={}",
            userId,
            message.lobbyId(),
            message.id()
        );
    }
}
