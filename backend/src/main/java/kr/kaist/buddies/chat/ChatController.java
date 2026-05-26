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
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/lobbies/{lobbyId}/chat")
public class ChatController {
    @GetMapping("/connection")
    public ChatConnectionResponse connection(@PathVariable Long lobbyId) {
        // TODO: Add lobby membership authorization before issuing WebSocket connection metadata.
        return new ChatConnectionResponse("/ws", 300);
    }

    @GetMapping("/messages")
    public List<ChatMessageResponse> list(
        @PathVariable Long lobbyId,
        @RequestParam(defaultValue = "50") int limit,
        @RequestParam(required = false) Long cursor
    ) {
        return List.of();
    }

    @PostMapping("/upload-url")
    public ImageUploadUrlResponse uploadImageUrl(@PathVariable Long lobbyId, @Valid @RequestBody ImageUploadUrlRequest request) {
        // TODO: Connect object storage pre-signed URL issuing after storage provider is selected.
        return new ImageUploadUrlResponse(
            "https://example.com/upload/" + request.filename(),
            "https://cdn.example.com/chat/" + request.filename()
        );
    }

    @GetMapping("/read-state")
    public ChatReadStateResponse readState(@PathVariable Long lobbyId) {
        // TODO: Read user id from JWT and calculate unread count from chat_read_states.
        return new ChatReadStateResponse(lobbyId, 1L, null, null, 0);
    }

    @PatchMapping("/read-state")
    public ChatReadStateResponse updateReadState(@PathVariable Long lobbyId, @Valid @RequestBody UpdateReadStateRequest request) {
        // TODO: Verify lastReadMessageId belongs to lobbyId before upserting chat_read_states.
        return new ChatReadStateResponse(lobbyId, 1L, request.lastReadMessageId(), Instant.now().toString(), 0);
    }

    @MessageMapping("/lobbies/{lobbyId}/chat/send")
    @SendTo("/topic/lobbies/{lobbyId}/chat")
    public ChatMessageResponse send(@DestinationVariable Long lobbyId, @Valid ChatMessageRequest request) {
        // TODO: Persist the message and apply restricted keyword filtering before broadcasting.
        return new ChatMessageResponse(1L, lobbyId, 1L, request.messageType(), request.content(), request.mediaUrl(), Instant.now().toString());
    }

    public record ChatConnectionResponse(String serverUrl, long expiresIn) {}
    public record ImageUploadUrlRequest(@NotBlank String filename, @NotBlank String contentType) {}
    public record ImageUploadUrlResponse(String uploadUrl, String mediaUrl) {}
    public record UpdateReadStateRequest(Long lastReadMessageId) {}
    public record ChatReadStateResponse(Long lobbyId, Long userId, Long lastReadMessageId, String lastReadAt, long unreadCount) {}
    public record ChatMessageRequest(@NotBlank String messageType, @Size(max = 500) String content, String mediaUrl) {}
    public record ChatMessageResponse(Long id, Long lobbyId, Long senderUserId, String messageType, String content, String mediaUrl, String createdAt) {}
}
