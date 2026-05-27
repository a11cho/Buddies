package kr.kaist.buddies.chat;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.chat.ChatController.ChatHistoryResponse;
import kr.kaist.buddies.chat.ChatController.ChatMessageRequest;
import kr.kaist.buddies.chat.ChatController.ChatMessageResponse;
import kr.kaist.buddies.chat.ChatController.ChatReadStateResponse;
import kr.kaist.buddies.chat.ChatController.ImageUploadUrlRequest;
import kr.kaist.buddies.chat.ChatController.ImageUploadUrlResponse;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.lobby.domain.LobbyMembership;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import kr.kaist.buddies.lobby.domain.LobbyRepository;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserStatus;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatService {
    private static final int DEFAULT_LIMIT = 50;
    private static final int MAX_LIMIT = 100;
    private static final int MAX_CONTENT_LENGTH = 500;
    private static final List<String> RESTRICTED_KEYWORDS = List.of(
        "fuck",
        "shit",
        "bitch",
        "씨발",
        "시발",
        "병신",
        "개새끼"
    );

    private final ChatMessageRepository chatMessageRepository;
    private final LobbyRepository lobbyRepository;
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final UserRepository userRepository;
    private final ChatReadService chatReadService;
    private final ApplicationEventPublisher eventPublisher;

    public ChatService(
        ChatMessageRepository chatMessageRepository,
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        UserRepository userRepository,
        ChatReadService chatReadService,
        ApplicationEventPublisher eventPublisher
    ) {
        this.chatMessageRepository = chatMessageRepository;
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.userRepository = userRepository;
        this.chatReadService = chatReadService;
        this.eventPublisher = eventPublisher;
    }

    @Transactional(readOnly = true)
    public ChatHistoryResponse history(Long userId, Long lobbyId, int limit, Long cursor) {
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        int pageSize = normalizeLimit(limit);
        List<ChatMessage> messages = cursor == null
            ? chatMessageRepository.findLatest(lobbyId, PageRequest.of(0, pageSize))
            : chatMessageRepository.findBeforeCursor(lobbyId, cursor, PageRequest.of(0, pageSize));
        return new ChatHistoryResponse(
            membership.getLastReadMessageId(),
            reverseChronologically(messages).stream().map(this::toResponse).toList()
        );
    }

    @Transactional
    public ChatMessageResponse send(Long userId, Long lobbyId, ChatMessageRequest request) {
        Lobby lobby = requireOpenLobby(lobbyId);
        User sender = requireActiveUser(userId);
        requireActiveMember(lobbyId, userId);

        ChatMessageType messageType = parseClientMessageType(request.messageType());
        String content = normalizeContent(request.content());
        String mediaUrl = normalizeMediaUrl(request.mediaUrl());
        validateMessagePayload(messageType, content, mediaUrl);
        rejectRestrictedKeywords(content);

        ChatMessage message = chatMessageRepository.save(new ChatMessage(
            lobby,
            sender,
            messageType,
            content,
            mediaUrl,
            Instant.now()
        ));
        ChatMessageResponse response = toResponse(message);
        eventPublisher.publishEvent(new ChatMessagePublishedEvent(lobbyId, response));
        return response;
    }

    @Transactional
    public ChatMessageResponse publishSystemMessage(Long lobbyId, String eventType, Long targetUserId, String content) {
        Lobby lobby = findLobby(lobbyId);
        ChatMessage message = chatMessageRepository.save(new ChatMessage(
            lobby,
            null,
            ChatMessageType.SYSTEM,
            content,
            null,
            eventType,
            targetUserId,
            Instant.now()
        ));
        ChatMessageResponse response = toResponse(message);
        eventPublisher.publishEvent(new ChatMessagePublishedEvent(lobbyId, response));
        return response;
    }

    @Transactional
    public ChatReadStateResponse updateReadState(Long userId, Long lobbyId, Long lastReadMessageId) {
        LobbyMembership membership = requireActiveMember(lobbyId, userId);
        if (!chatMessageRepository.existsByIdAndLobby_Id(lastReadMessageId, lobbyId)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "읽음 처리할 메시지가 해당 로비에 속하지 않습니다.");
        }

        Instant now = Instant.now();
        membership.updateLastReadMessage(lastReadMessageId, now);
        return new ChatReadStateResponse(
            lobbyId,
            userId,
            membership.getLastReadMessageId(),
            membership.getLastReadAt() == null ? now.toString() : membership.getLastReadAt().toString(),
            chatReadService.countUnread(lobbyId, membership.getLastReadMessageId())
        );
    }

    @Transactional(readOnly = true)
    public void requireConnectionAccess(Long userId, Long lobbyId) {
        requireActiveMember(lobbyId, userId);
    }

    @Transactional(readOnly = true)
    public ImageUploadUrlResponse issueUploadUrl(Long userId, Long lobbyId, ImageUploadUrlRequest request) {
        requireActiveMember(lobbyId, userId);
        requireSupportedImageType(request.contentType());
        String safeFilename = request.filename().replaceAll("[^A-Za-z0-9._-]", "_");
        return new ImageUploadUrlResponse(
            "https://example.com/upload/" + safeFilename,
            "https://cdn.example.com/chat/" + safeFilename
        );
    }

    private Lobby requireOpenLobby(Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        if (lobby.isClosedOrCanceled()) {
            throw new AuthException(HttpStatus.FORBIDDEN, "종료된 로비의 채팅에는 접근할 수 없습니다.");
        }
        return lobby;
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "존재하지 않는 로비입니다."));
    }

    private User requireActiveUser(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new AuthException(HttpStatus.FORBIDDEN, "계정 상태로 인해 채팅을 보낼 수 없습니다.");
        }
        return user;
    }

    private LobbyMembership requireActiveMember(Long lobbyId, Long userId) {
        requireOpenLobby(lobbyId);
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> new AuthException(HttpStatus.FORBIDDEN, "해당 로비에 접근할 권한이 없습니다."));
    }

    private ChatMessageType parseClientMessageType(String value) {
        try {
            ChatMessageType type = ChatMessageType.valueOf(value.trim().toUpperCase(Locale.ROOT));
            if (type == ChatMessageType.SYSTEM) {
                throw new AuthException(HttpStatus.FORBIDDEN, "SYSTEM 메시지는 사용자가 전송할 수 없습니다.");
            }
            return type;
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "메시지 타입이 올바르지 않습니다.");
        }
    }

    private void validateMessagePayload(ChatMessageType messageType, String content, String mediaUrl) {
        if (content != null && content.length() > MAX_CONTENT_LENGTH) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "메시지는 500자 이하로 입력해야 합니다.");
        }
        if (messageType == ChatMessageType.USER) {
            if (content == null || content.isBlank()) {
                throw new AuthException(HttpStatus.BAD_REQUEST, "메시지 내용이 필요합니다.");
            }
            if (mediaUrl != null) {
                throw new AuthException(HttpStatus.BAD_REQUEST, "USER 메시지는 mediaUrl을 포함할 수 없습니다.");
            }
        }
        if (messageType == ChatMessageType.MEDIA && mediaUrl == null) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "MEDIA 메시지는 mediaUrl이 필요합니다.");
        }
    }

    private void rejectRestrictedKeywords(String content) {
        if (content == null) {
            return;
        }
        String lowered = content.toLowerCase(Locale.ROOT);
        boolean restricted = RESTRICTED_KEYWORDS.stream().anyMatch(lowered::contains);
        if (restricted) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "제한된 표현이 포함되어 있습니다.");
        }
    }

    private void requireSupportedImageType(String contentType) {
        if (!List.of("image/jpeg", "image/png", "image/gif", "image/webp").contains(contentType)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "지원하지 않는 이미지 형식입니다.");
        }
    }

    private String normalizeContent(String content) {
        if (content == null) {
            return null;
        }
        String normalized = content.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String normalizeMediaUrl(String mediaUrl) {
        if (mediaUrl == null) {
            return null;
        }
        String normalized = mediaUrl.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private int normalizeLimit(int limit) {
        if (limit <= 0) {
            return DEFAULT_LIMIT;
        }
        return Math.min(limit, MAX_LIMIT);
    }

    private List<ChatMessage> reverseChronologically(List<ChatMessage> messages) {
        List<ChatMessage> reversed = new ArrayList<>(messages);
        java.util.Collections.reverse(reversed);
        return reversed;
    }

    private ChatMessageResponse toResponse(ChatMessage message) {
        return new ChatMessageResponse(
            message.getId(),
            message.getLobby().getId(),
            message.getSender() == null ? null : message.getSender().getId(),
            message.getMessageType().name(),
            message.getEventType(),
            message.getTargetUserId(),
            message.getContent(),
            message.getMediaUrl(),
            message.getCreatedAt().toString()
        );
    }
}
