package kr.kaist.buddies.lobby;

import java.util.Map;
import kr.kaist.buddies.chat.ChatService;
import kr.kaist.buddies.lobby.domain.LobbyOrderStatus;
import org.springframework.stereotype.Component;

@Component
public class LobbyEventPublisher {
    private final ChatService chatService;

    public LobbyEventPublisher(ChatService chatService) {
        this.chatService = chatService;
    }

    public void memberJoined(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "lobby.member_joined", userId);
    }

    public void memberLeft(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "lobby.member_left", userId);
    }

    public void memberKicked(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "lobby.member_kicked", userId);
    }

    public void hostTransferred(Long lobbyId, Long newHostUserId, String newHostName) {
        publish(lobbyId, "lobby.host_transferred", newHostUserId);
    }

    public void cartLocked(Long lobbyId) {
        publish(lobbyId, "cart.locked", null);
    }

    public void statusUpdated(Long lobbyId, LobbyOrderStatus previousStatus, LobbyOrderStatus nextStatus) {
        publish(
            lobbyId,
            "lobby.status_updated",
            null,
            Map.of("previousStatus", previousStatus.name(), "nextStatus", nextStatus.name())
        );
    }

    public void lobbyClosed(Long lobbyId, LobbyOrderStatus nextStatus) {
        publish(lobbyId, "lobby.closed", null, Map.of("status", nextStatus.name()));
    }

    public void cartItemAdded(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_added", userId, Map.of("itemName", itemName));
    }

    public void cartItemUpdated(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_updated", userId, Map.of("itemName", itemName));
    }

    public void cartItemDeleted(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_deleted", userId, Map.of("itemName", itemName));
    }

    public void paymentRecordUpdated(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "payment.record_updated", userId);
    }

    private void publish(Long lobbyId, String eventType, Long targetUserId) {
        publish(lobbyId, eventType, targetUserId, Map.of());
    }

    private void publish(Long lobbyId, String eventType, Long targetUserId, Map<String, Object> eventMetadata) {
        chatService.publishSystemMessage(lobbyId, eventType, targetUserId, eventMetadata);
    }
}
