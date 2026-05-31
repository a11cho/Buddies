package kr.kaist.buddies.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class LoggingPushNotificationSender implements PushNotificationSender {
    private static final Logger log = LoggerFactory.getLogger(LoggingPushNotificationSender.class);

    @Override
    public void send(DeviceToken deviceToken, PushMessage message) {
        log.info(
            "Mock push sent. userId={}, platform={}, lobbyId={}, messageId={}, title={}",
            deviceToken.getUser().getId(),
            deviceToken.getPlatform(),
            message.lobbyId(),
            message.messageId(),
            message.title()
        );
    }
}
