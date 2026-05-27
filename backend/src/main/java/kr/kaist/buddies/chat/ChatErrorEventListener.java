package kr.kaist.buddies.chat;

import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
public class ChatErrorEventListener {
    private final SimpMessagingTemplate messagingTemplate;

    public ChatErrorEventListener(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    @EventListener
    public void publish(ChatErrorPublishedEvent event) {
        messagingTemplate.convertAndSendToUser(event.username(), "/queue/chat-errors", event.error());
    }
}
