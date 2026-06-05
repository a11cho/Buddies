package kr.kaist.buddies.lobby.domain;

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
@Table(name = "receipt_attachments")
public class ReceiptAttachment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lobby_id", nullable = false)
    private Lobby lobby;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "uploaded_by_user_id", nullable = false)
    private User uploadedBy;

    @Column(name = "receipt_image_url", nullable = false, length = 500)
    private String receiptImageUrl;

    @Column(name = "original_filename", length = 255)
    private String originalFilename;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Column(name = "file_size_bytes")
    private Long fileSizeBytes;

    @Column(length = 128)
    private String checksum;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ReceiptAttachmentStatus status = ReceiptAttachmentStatus.ACTIVE;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected ReceiptAttachment() {
    }

    public ReceiptAttachment(
        Lobby lobby,
        User uploadedBy,
        String receiptImageUrl,
        String originalFilename,
        String contentType,
        Long fileSizeBytes,
        String checksum
    ) {
        this.lobby = lobby;
        this.uploadedBy = uploadedBy;
        this.receiptImageUrl = receiptImageUrl;
        this.originalFilename = originalFilename;
        this.contentType = contentType;
        this.fileSizeBytes = fileSizeBytes;
        this.checksum = checksum;
        this.status = ReceiptAttachmentStatus.ACTIVE;
        this.createdAt = Instant.now();
        this.updatedAt = this.createdAt;
    }

    public Long getId() {
        return id;
    }

    public Lobby getLobby() {
        return lobby;
    }

    public User getUploadedBy() {
        return uploadedBy;
    }

    public String getReceiptImageUrl() {
        return receiptImageUrl;
    }

    public String getOriginalFilename() {
        return originalFilename;
    }

    public String getContentType() {
        return contentType;
    }

    public Long getFileSizeBytes() {
        return fileSizeBytes;
    }

    public String getChecksum() {
        return checksum;
    }

    public ReceiptAttachmentStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void replace() {
        this.status = ReceiptAttachmentStatus.REPLACED;
        this.updatedAt = Instant.now();
    }
}
