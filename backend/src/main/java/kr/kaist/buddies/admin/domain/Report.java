package kr.kaist.buddies.admin.domain;

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
@Table(name = "reports")
public class Report {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reporter_user_id", nullable = false)
    private User reporter;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reported_user_id", nullable = false)
    private User reportedUser;

    @Column(name = "lobby_id")
    private Long lobbyId;

    @Column(name = "chat_message_id")
    private Long chatMessageId;

    @Column(nullable = false, length = 100)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ReportStatus status = ReportStatus.OPEN;

    @Column(name = "resolution_note")
    private String resolutionNote;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resolved_by_admin_id")
    private User resolvedByAdmin;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    protected Report() {
    }

    public Report(User reporter, User reportedUser, Long lobbyId, Long chatMessageId, String reason) {
        this.reporter = reporter;
        this.reportedUser = reportedUser;
        this.lobbyId = lobbyId;
        this.chatMessageId = chatMessageId;
        this.reason = reason;
    }

    public Long getId() {
        return id;
    }

    public User getReporter() {
        return reporter;
    }

    public User getReportedUser() {
        return reportedUser;
    }

    public Long getLobbyId() {
        return lobbyId;
    }

    public Long getChatMessageId() {
        return chatMessageId;
    }

    public String getReason() {
        return reason;
    }

    public ReportStatus getStatus() {
        return status;
    }

    public String getResolutionNote() {
        return resolutionNote;
    }

    public User getResolvedByAdmin() {
        return resolvedByAdmin;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void markInReview() {
        this.status = ReportStatus.UNDER_REVIEW;
    }

    public void resolve(User admin, String resolutionNote, Instant resolvedAt) {
        this.status = ReportStatus.RESOLVED;
        this.resolvedByAdmin = admin;
        this.resolutionNote = resolutionNote;
        this.resolvedAt = resolvedAt;
    }
}
