package kr.kaist.buddies.chat;

public record ChatErrorPublishedEvent(String username, ChatErrorResponse error) {}
