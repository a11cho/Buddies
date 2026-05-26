package kr.kaist.buddies.chat;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import kr.kaist.buddies.lobby.domain.LobbyMembership;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import org.springframework.http.HttpStatus;
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
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final ChatReadService chatReadService;

    public ChatController(LobbyMembershipRepository lobbyMembershipRepository, ChatReadService chatReadService) {
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.chatReadService = chatReadService;
    }

    @GetMapping("/connection")
    public ChatConnectionResponse connection(@PathVariable Long lobbyId) {
        // TODO: Add lobby membership authorization before issuing WebSocket connection metadata.
        return new ChatConnectionResponse("/ws", 300);
    }

    @GetMapping("/messages")
    public ChatHistoryResponse list(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @RequestParam(defaultValue = "50") int limit,
        @RequestParam(required = false) Long cursor
    ) {
        LobbyMembership membership = requireActiveMember(lobbyId, user.id());
        return new ChatHistoryResponse(membership.getLastReadMessageId(), List.of());
    }

    @PostMapping("/upload-url")
    public ImageUploadUrlResponse uploadImageUrl(@PathVariable Long lobbyId, @Valid @RequestBody ImageUploadUrlRequest request) {
        // TODO: Connect object storage pre-signed URL issuing after storage provider is selected.
        return new ImageUploadUrlResponse(
            "https://example.com/upload/" + request.filename(),
            "https://cdn.example.com/chat/" + request.filename()
        );
    }

    @PatchMapping("/read-state")
    public ChatReadStateResponse updateReadState(
        @CurrentUser AuthenticatedUser user,
        @PathVariable Long lobbyId,
        @Valid @RequestBody UpdateReadStateRequest request
    ) {
        LobbyMembership membership = requireActiveMember(lobbyId, user.id());
        if (!chatReadService.messageBelongsToLobby(lobbyId, request.lastReadMessageId())) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "읽음 처리할 메시지가 해당 로비에 속하지 않습니다.");
        }
        Instant lastReadAt = Instant.now();
        membership.updateLastReadMessage(request.lastReadMessageId(), lastReadAt);
        return new ChatReadStateResponse(
            lobbyId,
            user.id(),
            membership.getLastReadMessageId(),
            membership.getLastReadAt() == null ? lastReadAt.toString() : membership.getLastReadAt().toString(),
            chatReadService.countUnread(lobbyId, membership.getLastReadMessageId())
        );
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
    public record UpdateReadStateRequest(@NotNull Long lastReadMessageId) {}
    public record ChatHistoryResponse(Long lastReadMessageId, List<ChatMessageResponse> messages) {}
    public record ChatReadStateResponse(Long lobbyId, Long userId, Long lastReadMessageId, String lastReadAt, long unreadCount) {}
    public record ChatMessageRequest(@NotBlank String messageType, @Size(max = 500) String content, String mediaUrl) {}
    public record ChatMessageResponse(Long id, Long lobbyId, Long senderUserId, String messageType, String content, String mediaUrl, String createdAt) {}

    private LobbyMembership requireActiveMember(Long lobbyId, Long userId) {
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.FORBIDDEN, "해당 로비에 접근할 권한이 없습니다."));
    }
}
