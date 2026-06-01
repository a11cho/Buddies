package kr.kaist.buddies.notification;

public record PushMessage(Long lobbyId, Long messageId, String title, String body) {}
