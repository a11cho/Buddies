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
@Table(name = "payment_records")
public class PaymentRecord {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lobby_id", nullable = false)
    private Lobby lobby;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private long amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentRecordStatus status = PaymentRecordStatus.UNPAID;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "confirmed_by_host_id")
    private User confirmedByHost;

    @Column(name = "confirmed_at")
    private Instant confirmedAt;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false, insertable = false)
    private Instant updatedAt;

    protected PaymentRecord() {
    }

    public PaymentRecord(Lobby lobby, User user, long amount) {
        this.lobby = lobby;
        this.user = user;
        this.amount = amount;
        this.status = PaymentRecordStatus.UNPAID;
    }

    public Long getId() {
        return id;
    }

    public Lobby getLobby() {
        return lobby;
    }

    public User getUser() {
        return user;
    }

    public long getAmount() {
        return amount;
    }

    public PaymentRecordStatus getStatus() {
        return status;
    }

    public User getConfirmedByHost() {
        return confirmedByHost;
    }

    public Instant getConfirmedAt() {
        return confirmedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void resetAmount(long amount) {
        this.amount = amount;
        this.status = PaymentRecordStatus.UNPAID;
        this.confirmedByHost = null;
        this.confirmedAt = null;
        this.updatedAt = Instant.now();
    }

    public void markPaid(User host, Instant confirmedAt) {
        this.status = PaymentRecordStatus.PAID;
        this.confirmedByHost = host;
        this.confirmedAt = confirmedAt;
        this.updatedAt = confirmedAt;
    }

    public void markInactive(Instant updatedAt) {
        this.status = PaymentRecordStatus.INACTIVE;
        this.updatedAt = updatedAt;
    }
}
