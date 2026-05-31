package kr.kaist.buddies.notification;

public interface PushNotificationSender {
    void send(DeviceToken deviceToken, PushMessage message);
}
