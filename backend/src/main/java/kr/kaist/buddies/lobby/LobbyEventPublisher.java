package kr.kaist.buddies.lobby;

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
        publish(lobbyId, "lobby.member_joined", userId, userName + "님이 입장하셨습니다.");
    }

    public void memberLeft(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "lobby.member_left", userId, userName + "님이 로비를 나갔습니다.");
    }

    public void memberKicked(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "lobby.member_kicked", userId, userName + "님이 강퇴되었습니다.");
    }

    public void hostTransferred(Long lobbyId, Long newHostUserId, String newHostName) {
        publish(lobbyId, "lobby.host_transferred", newHostUserId, newHostName + "님이 새로운 Host가 되었습니다.");
    }

    public void cartLocked(Long lobbyId) {
        publish(lobbyId, "cart.locked", null, "장바구니가 확정되었습니다. 정산을 시작해 주세요.");
    }

    public void statusUpdated(Long lobbyId, LobbyOrderStatus previousStatus, LobbyOrderStatus nextStatus) {
        publish(lobbyId, "lobby.status_updated", null, "주문 상태가 " + previousStatus.name() + "에서 " + nextStatus.name() + "(으)로 변경되었습니다.");
    }

    public void lobbyClosed(Long lobbyId, LobbyOrderStatus nextStatus) {
        publish(lobbyId, "lobby.closed", null, "로비가 " + nextStatus.name() + " 상태로 종료되었습니다.");
    }

    public void cartItemAdded(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_added", userId, userName + "님이 " + itemName + "을(를) 장바구니에 추가했습니다.");
    }

    public void cartItemUpdated(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_updated", userId, userName + "님이 " + itemName + " 항목을 수정했습니다.");
    }

    public void cartItemDeleted(Long lobbyId, Long userId, String userName, String itemName) {
        publish(lobbyId, "cart.item_deleted", userId, userName + "님이 " + itemName + "을(를) 장바구니에서 삭제했습니다.");
    }

    public void paymentRecordUpdated(Long lobbyId, Long userId, String userName) {
        publish(lobbyId, "payment.record_updated", userId, userName + "님의 결제가 확인되었습니다.");
    }

    private void publish(Long lobbyId, String eventType, Long targetUserId, String content) {
        chatService.publishSystemMessage(lobbyId, eventType, targetUserId, content);
    }
}
