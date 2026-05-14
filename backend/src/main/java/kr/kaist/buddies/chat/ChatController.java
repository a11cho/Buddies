package kr.kaist.buddies.chat;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/lobbies/{lobbyId}/messages")
public class ChatController {
    @GetMapping
    public List<ChatMessageResponse> list(@PathVariable Long lobbyId) {
        return List.of();
    }

    @PostMapping("/media")
    public MessageResponse uploadMedia(@PathVariable Long lobbyId) {
        return new MessageResponse("Media upload endpoint placeholder for lobby " + lobbyId);
    }

    @MessageMapping("/lobbies/{lobbyId}/messages")
    @SendTo("/topic/lobbies/{lobbyId}/chat")
    public ChatMessageResponse send(@DestinationVariable Long lobbyId, @Valid ChatMessageRequest request) {
        return new ChatMessageResponse(lobbyId, 1L, request.body(), "USER", Instant.now().toString());
    }

    public record ChatMessageRequest(@NotBlank @Size(max = 500) String body) {}
    public record ChatMessageResponse(Long lobbyId, Long senderUserId, String body, String type, String createdAt) {}
    public record MessageResponse(String message) {}
}

