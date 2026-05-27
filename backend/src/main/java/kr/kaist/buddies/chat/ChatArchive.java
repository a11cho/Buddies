package kr.kaist.buddies.chat;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "chat_archives")
public class ChatArchive {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "lobby_id", nullable = false)
    private Long lobbyId;

    @Column(name = "archived_at", nullable = false)
    private Instant archivedAt;

    @Column(name = "retention_until", nullable = false)
    private Instant retentionUntil;

    protected ChatArchive() {
    }

    public ChatArchive(Long lobbyId, Instant archivedAt, Instant retentionUntil) {
        this.lobbyId = lobbyId;
        this.archivedAt = archivedAt;
        this.retentionUntil = retentionUntil;
    }

    public Long getId() {
        return id;
    }

    public Long getLobbyId() {
        return lobbyId;
    }

    public Instant getArchivedAt() {
        return archivedAt;
    }

    public Instant getRetentionUntil() {
        return retentionUntil;
    }
}
