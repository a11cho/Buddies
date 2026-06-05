package kr.kaist.buddies.chat;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;
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
import kr.kaist.buddies.storage.ImageUploadUrlService;
import kr.kaist.buddies.storage.ImageUploadUrlService.ImageUploadUrl;
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
    private static final TypeReference<Map<String, Object>> EVENT_METADATA_TYPE = new TypeReference<>() {};
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
    private final ObjectMapper objectMapper;
    private final ImageUploadUrlService imageUploadUrlService;

    public ChatService(
        ChatMessageRepository chatMessageRepository,
        LobbyRepository lobbyRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        UserRepository userRepository,
        ChatReadService chatReadService,
        ApplicationEventPublisher eventPublisher,
        ObjectMapper objectMapper,
        ImageUploadUrlService imageUploadUrlService
    ) {
        this.chatMessageRepository = chatMessageRepository;
        this.lobbyRepository = lobbyRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.userRepository = userRepository;
        this.chatReadService = chatReadService;
        this.eventPublisher = eventPublisher;
        this.objectMapper = objectMapper;
        this.imageUploadUrlService = imageUploadUrlService;
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
        return publishSystemMessage(lobbyId, eventType, targetUserId, content, Map.of());
    }

    @Transactional
    public ChatMessageResponse publishSystemMessage(Long lobbyId, String eventType, Long targetUserId, Map<String, Object> eventMetadata) {
        return publishSystemMessage(lobbyId, eventType, targetUserId, null, eventMetadata);
    }

    @Transactional
    public ChatMessageResponse publishSystemMessage(Long lobbyId, String eventType, Long targetUserId, String content, Map<String, Object> eventMetadata) {
        Lobby lobby = findLobby(lobbyId);
        ChatMessage message = chatMessageRepository.save(new ChatMessage(
            lobby,
            null,
            ChatMessageType.SYSTEM,
            content,
            null,
            eventType,
            targetUserId,
            serializeEventMetadata(eventMetadata),
            Instant.now()
        ));
        ChatMessageResponse response = toResponse(message);
        eventPublisher.publishEvent(new ChatMessagePublishedEvent(lobbyId, response));
        return response;
    }

    @Transactional
    public ChatMessageResponse publishMediaMessage(Long lobbyId, Long senderUserId, String content, String mediaUrl, String mediaPurpose) {
        Lobby lobby = findLobby(lobbyId);
        User sender = requireActiveUser(senderUserId);
        ChatMessage message = chatMessageRepository.save(new ChatMessage(
            lobby,
            sender,
            ChatMessageType.MEDIA,
            normalizeContent(content),
            normalizeMediaUrl(mediaUrl),
            null,
            null,
            serializeEventMetadata(Map.of("mediaPurpose", mediaPurpose)),
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
            throw ChatErrorCode.INVALID_READ_MESSAGE.exception(HttpStatus.BAD_REQUEST);
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
        ImageUploadUrl uploadUrl = imageUploadUrlService.issue("chat/" + lobbyId, request.contentType());
        return new ImageUploadUrlResponse(uploadUrl.uploadUrl(), uploadUrl.mediaUrl());
    }

    private Lobby requireOpenLobby(Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        if (lobby.isClosedOrCanceled()) {
            throw ChatErrorCode.LOBBY_CLOSED.exception(HttpStatus.FORBIDDEN);
        }
        return lobby;
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> ChatErrorCode.LOBBY_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private User requireActiveUser(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> ChatErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED));
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw ChatErrorCode.ACCOUNT_RESTRICTED.exception(HttpStatus.FORBIDDEN);
        }
        return user;
    }

    private LobbyMembership requireActiveMember(Long lobbyId, Long userId) {
        requireOpenLobby(lobbyId);
        return lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobbyId, userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> ChatErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
    }

    private ChatMessageType parseClientMessageType(String value) {
        try {
            ChatMessageType type = ChatMessageType.valueOf(value.trim().toUpperCase(Locale.ROOT));
            if (type == ChatMessageType.SYSTEM) {
                throw ChatErrorCode.SYSTEM_MESSAGE_FORBIDDEN.exception(HttpStatus.FORBIDDEN);
            }
            return type;
        } catch (IllegalArgumentException exception) {
            throw ChatErrorCode.INVALID_MESSAGE_TYPE.exception(HttpStatus.BAD_REQUEST);
        }
    }

    private void validateMessagePayload(ChatMessageType messageType, String content, String mediaUrl) {
        if (content != null && content.length() > MAX_CONTENT_LENGTH) {
            throw ChatErrorCode.MESSAGE_TOO_LONG.exception(HttpStatus.BAD_REQUEST);
        }
        if (messageType == ChatMessageType.USER) {
            if (content == null || content.isBlank()) {
                throw ChatErrorCode.MESSAGE_CONTENT_REQUIRED.exception(HttpStatus.BAD_REQUEST);
            }
            if (mediaUrl != null) {
                throw ChatErrorCode.INVALID_MESSAGE_PAYLOAD.exception(HttpStatus.BAD_REQUEST);
            }
        }
        if (messageType == ChatMessageType.MEDIA && mediaUrl == null) {
            throw ChatErrorCode.MEDIA_URL_REQUIRED.exception(HttpStatus.BAD_REQUEST);
        }
    }

    private void rejectRestrictedKeywords(String content) {
        if (content == null) {
            return;
        }
        String lowered = content.toLowerCase(Locale.ROOT);
        boolean restricted = RESTRICTED_KEYWORDS.stream().anyMatch(lowered::contains);
        if (restricted) {
            throw ChatErrorCode.RESTRICTED_KEYWORD.exception(HttpStatus.BAD_REQUEST);
        }
    }

    private void requireSupportedImageType(String contentType) {
        if (!List.of("image/jpeg", "image/png", "image/gif", "image/webp").contains(contentType)) {
            throw ChatErrorCode.INVALID_FILE_TYPE.exception(HttpStatus.BAD_REQUEST);
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
            parseEventMetadata(message.getEventMetadataJson()),
            message.getCreatedAt().toString()
        );
    }

    private String serializeEventMetadata(Map<String, Object> eventMetadata) {
        if (eventMetadata == null || eventMetadata.isEmpty()) {
            return "{}";
        }
        try {
            return objectMapper.writeValueAsString(eventMetadata);
        } catch (JsonProcessingException exception) {
            throw ChatErrorCode.STOMP_ERROR.exception(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private Map<String, Object> parseEventMetadata(String eventMetadataJson) {
        if (eventMetadataJson == null || eventMetadataJson.isBlank()) {
            return Collections.emptyMap();
        }
        try {
            return objectMapper.readValue(eventMetadataJson, EVENT_METADATA_TYPE);
        } catch (JsonProcessingException exception) {
            return Collections.emptyMap();
        }
    }
}
