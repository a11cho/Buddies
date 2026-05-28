package kr.kaist.buddies.chat;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ChatMessageEventListener {
    private final SimpMessagingTemplate messagingTemplate;
    private final ChatPushNotificationService chatPushNotificationService;

    public ChatMessageEventListener(
        SimpMessagingTemplate messagingTemplate,
        ChatPushNotificationService chatPushNotificationService
    ) {
        this.messagingTemplate = messagingTemplate;
        this.chatPushNotificationService = chatPushNotificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void publish(ChatMessagePublishedEvent event) {
        messagingTemplate.convertAndSend("/topic/lobbies/" + event.lobbyId() + "/chat", event.message());
        chatPushNotificationService.notifyOfflineMembers(event.message());
    }
}
