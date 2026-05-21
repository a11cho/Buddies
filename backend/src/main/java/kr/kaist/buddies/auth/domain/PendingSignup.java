package kr.kaist.buddies.auth.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "pending_signups")
public class PendingSignup {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "otp_hash", nullable = false)
    private String otpHash;

    @Column(name = "otp_expires_at", nullable = false)
    private Instant otpExpiresAt;

    @Column(name = "attempt_count", nullable = false)
    private int attemptCount;

    @Column(name = "resend_available_at", nullable = false)
    private Instant resendAvailableAt;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false, insertable = false)
    private Instant updatedAt;

    protected PendingSignup() {
    }

    public PendingSignup(
        String email,
        String name,
        String passwordHash,
        String otpHash,
        Instant otpExpiresAt,
        Instant resendAvailableAt
    ) {
        this.email = email;
        this.name = name;
        this.passwordHash = passwordHash;
        this.otpHash = otpHash;
        this.otpExpiresAt = otpExpiresAt;
        this.resendAvailableAt = resendAvailableAt;
    }

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getName() {
        return name;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getOtpHash() {
        return otpHash;
    }

    public Instant getOtpExpiresAt() {
        return otpExpiresAt;
    }

    public int getAttemptCount() {
        return attemptCount;
    }

    public Instant getResendAvailableAt() {
        return resendAvailableAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void replaceOtp(String name, String passwordHash, String otpHash, Instant otpExpiresAt, Instant resendAvailableAt) {
        this.name = name;
        this.passwordHash = passwordHash;
        this.otpHash = otpHash;
        this.otpExpiresAt = otpExpiresAt;
        this.resendAvailableAt = resendAvailableAt;
        this.attemptCount = 0;
        this.updatedAt = Instant.now();
    }

    public void increaseAttemptCount() {
        this.attemptCount++;
        this.updatedAt = Instant.now();
    }
}
