package kr.kaist.buddies.chat;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.security.Principal;
import java.util.List;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.MessageExceptionHandler;
import org.springframework.messaging.simp.annotation.SendToUser;
import org.springframework.security.core.Authentication;
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
    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @GetMapping("/connection")
    public ChatConnectionResponse connection(@CurrentUser AuthenticatedUser user, @PathVariable Long lobbyId) {
        chatService.requireConnectionAccess(user.id(), lobbyId);
        return new ChatConnectionResponse("/ws", 300);
    }

    @GetMapping("/messages")
    public ChatHistoryResponse list(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @RequestParam(defaultValue = "50") int limit,
        @RequestParam(required = false) Long cursor
    ) {
        return chatService.history(user.id(), lobbyId, limit, cursor);
    }

    @PostMapping("/upload-url")
    public ImageUploadUrlResponse uploadImageUrl(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @Valid @RequestBody ImageUploadUrlRequest request
    ) {
        return chatService.issueUploadUrl(user.id(), lobbyId, request);
    }

    @PatchMapping("/read-state")
    public ChatReadStateResponse updateReadState(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @Valid @RequestBody UpdateReadStateRequest request
    ) {
        return chatService.updateReadState(user.id(), lobbyId, request.lastReadMessageId());
    }

    @MessageMapping("/lobbies/{lobbyId}/chat/send")
    public void send(
        Principal principal,
        @DestinationVariable Long lobbyId,
        @Valid ChatMessageRequest request
    ) {
        chatService.send(stompUser(principal).id(), lobbyId, request);
    }

    public record ChatConnectionResponse(String serverUrl, long expiresIn) {}
    public record ImageUploadUrlRequest(@NotBlank String filename, @NotBlank String contentType) {}
    public record ImageUploadUrlResponse(String uploadUrl, String mediaUrl) {}
    public record UpdateReadStateRequest(@NotNull Long lastReadMessageId) {}
    public record ChatHistoryResponse(Long lastReadMessageId, List<ChatMessageResponse> messages) {}
    public record ChatReadStateResponse(Long lobbyId, Long userId, Long lastReadMessageId, String lastReadAt, long unreadCount) {}
    public record ChatMessageRequest(@NotBlank String messageType, @Size(max = 500) String content, String mediaUrl) {}
    public record ChatMessageResponse(
        Long id,
        Long lobbyId,
        Long senderUserId,
        String messageType,
        String eventType,
        Long targetUserId,
        String content,
        String mediaUrl,
        String createdAt
    ) {}

    @MessageExceptionHandler(Exception.class)
    @SendToUser("/queue/chat-errors")
    public ChatErrorResponse handleChatException(Exception exception) {
        return ChatErrorMapper.toResponse(exception);
    }

    private AuthenticatedUser stompUser(Principal principal) {
        if (principal instanceof Authentication authentication && authentication.getPrincipal() instanceof AuthenticatedUser user) {
            return user;
        }
        throw ChatErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED);
    }
}
