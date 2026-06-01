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
@Table(name = "device_tokens")
public class DeviceToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "device_token", nullable = false, unique = true, length = 500)
    private String deviceToken;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private DevicePlatform platform;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "last_seen_at", nullable = false)
    private Instant lastSeenAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected DeviceToken() {
    }

    public DeviceToken(User user, String deviceToken, DevicePlatform platform, Instant now) {
        this.user = user;
        this.deviceToken = deviceToken;
        this.platform = platform;
        this.enabled = true;
        this.lastSeenAt = now;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public Long getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public String getDeviceToken() {
        return deviceToken;
    }

    public DevicePlatform getPlatform() {
        return platform;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public Instant getLastSeenAt() {
        return lastSeenAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void refresh(User user, DevicePlatform platform, Instant now) {
        this.user = user;
        this.platform = platform;
        this.enabled = true;
        this.lastSeenAt = now;
        this.updatedAt = now;
    }

    public void disable(Instant now) {
        this.enabled = false;
        this.updatedAt = now;
    }
}
