package kr.kaist.buddies.notification;

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
import kr.kaist.buddies.user.domain.User;

@Entity
@Table(name = "push_notifications")
public class PushNotification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "lobby_id")
    private Long lobbyId;

    @Column(name = "message_id")
    private Long messageId;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, length = 500)
    private String body;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PushNotificationStatus status;

    @Column(name = "error_message", length = 500)
    private String errorMessage;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "sent_at")
    private Instant sentAt;

    protected PushNotification() {
    }

    public PushNotification(User user, Long lobbyId, Long messageId, String title, String body, Instant now) {
        this.user = user;
        this.lobbyId = lobbyId;
        this.messageId = messageId;
        this.title = title;
        this.body = body;
        this.status = PushNotificationStatus.SKIPPED;
        this.createdAt = now;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public Long getLobbyId() {
        return lobbyId;
    }

    public Long getMessageId() {
        return messageId;
    }

    public String getTitle() {
        return title;
    }

    public String getBody() {
        return body;
    }

    public PushNotificationStatus getStatus() {
        return status;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public void markSent(Instant sentAt) {
        this.status = PushNotificationStatus.SENT;
        this.sentAt = sentAt;
        this.errorMessage = null;
    }

    public void markSkipped(String reason) {
        this.status = PushNotificationStatus.SKIPPED;
        this.errorMessage = reason;
    }

    public void markFailed(String errorMessage) {
        this.status = PushNotificationStatus.FAILED;
        this.errorMessage = errorMessage;
    }
}
