package kr.kaist.buddies.chat;

import kr.kaist.buddies.chat.ChatController.ChatMessageResponse;

public record ChatMessagePublishedEvent(Long lobbyId, ChatMessageResponse message) {}
