package kr.kaist.buddies.chat;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.user.domain.User;

@Entity
@Table(name = "chat_messages")
public class ChatMessage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lobby_id", nullable = false)
    private Lobby lobby;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_user_id")
    private User sender;

    @Enumerated(EnumType.STRING)
    @Column(name = "message_type", nullable = false, length = 20)
    private ChatMessageType messageType;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "media_url", length = 500)
    private String mediaUrl;

    @Column(name = "event_type", length = 100)
    private String eventType;

    @Column(name = "target_user_id")
    private Long targetUserId;

    @Column(name = "is_archived", nullable = false)
    private boolean archived;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected ChatMessage() {
    }

    public ChatMessage(Lobby lobby, User sender, ChatMessageType messageType, String content, String mediaUrl, Instant createdAt) {
        this(lobby, sender, messageType, content, mediaUrl, null, null, createdAt);
    }

    public ChatMessage(
        Lobby lobby,
        User sender,
        ChatMessageType messageType,
        String content,
        String mediaUrl,
        String eventType,
        Long targetUserId,
        Instant createdAt
    ) {
        this.lobby = lobby;
        this.sender = sender;
        this.messageType = messageType;
        this.content = content;
        this.mediaUrl = mediaUrl;
        this.eventType = eventType;
        this.targetUserId = targetUserId;
        this.createdAt = createdAt;
        this.archived = false;
    }

    public Long getId() {
        return id;
    }

    public Lobby getLobby() {
        return lobby;
    }

    public User getSender() {
        return sender;
    }

    public ChatMessageType getMessageType() {
        return messageType;
    }

    public String getContent() {
        return content;
    }

    public String getMediaUrl() {
        return mediaUrl;
    }

    public String getEventType() {
        return eventType;
    }

    public Long getTargetUserId() {
        return targetUserId;
    }

    public boolean isArchived() {
        return archived;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
