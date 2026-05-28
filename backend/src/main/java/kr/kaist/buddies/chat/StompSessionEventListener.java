package kr.kaist.buddies.chat;

import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

@Component
public class StompSessionEventListener {
    private final StompSessionManager stompSessionManager;

    public StompSessionEventListener(StompSessionManager stompSessionManager) {
        this.stompSessionManager = stompSessionManager;
    }

    @EventListener
    public void disconnect(SessionDisconnectEvent event) {
        stompSessionManager.disconnect(event.getSessionId());
    }
}
