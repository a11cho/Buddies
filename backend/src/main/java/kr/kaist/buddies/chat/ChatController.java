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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/chat")
public class ChatController {
    @GetMapping("/connection")
    public ChatConnectionResponse connection(@RequestParam Long lobbyId) {
        // TODO: Add lobby membership authorization before issuing WebSocket connection metadata.
        return new ChatConnectionResponse("/ws/chat", 300);
    }

    @GetMapping("/lobbies/{lobbyId}/messages")
    public List<ChatMessageResponse> list(@PathVariable Long lobbyId) {
        return List.of();
    }

    @PostMapping("/images/upload-url")
    public ImageUploadUrlResponse uploadImageUrl(@Valid @RequestBody ImageUploadUrlRequest request) {
        // TODO: Connect object storage pre-signed URL issuing after storage provider is selected.
        return new ImageUploadUrlResponse(request.lobbyId(), request.filename(), "https://example.com/upload/" + request.filename());
    }

    @MessageMapping("/lobbies/{lobbyId}/messages")
    @SendTo("/topic/lobbies/{lobbyId}/chat")
    public ChatMessageResponse send(@DestinationVariable Long lobbyId, @Valid ChatMessageRequest request) {
        // TODO: Persist the message and apply restricted keyword filtering before broadcasting.
        return new ChatMessageResponse(1L, lobbyId, 1L, request.content(), "USER", Instant.now().toString());
    }

    public record ChatConnectionResponse(String serverUrl, long expiresIn) {}
    public record ImageUploadUrlRequest(Long lobbyId, @NotBlank String filename, @NotBlank String contentType) {}
    public record ImageUploadUrlResponse(Long lobbyId, String filename, String uploadUrl) {}
    public record ChatMessageRequest(@NotBlank @Size(max = 500) String content) {}
    public record ChatMessageResponse(Long messageId, Long lobbyId, Long senderUserId, String content, String type, String createdAt) {}
}
