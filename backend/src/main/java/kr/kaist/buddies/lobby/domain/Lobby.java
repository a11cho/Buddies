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
@Table(name = "lobbies")
public class Lobby {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "host_user_id", nullable = false)
    private User host;

    @Column(name = "restaurant_name", nullable = false, length = 200)
    private String restaurantName;

    @Enumerated(EnumType.STRING)
    @Column(name = "delivery_location", nullable = false, length = 100)
    private DeliveryLocation deliveryLocation;

    @Column(name = "minimum_order_amount", nullable = false)
    private long minimumOrderAmount;

    @Column(name = "current_total_amount", nullable = false)
    private long currentTotalAmount;

    @Column(name = "delivery_fee", nullable = false)
    private long deliveryFee;

    @Enumerated(EnumType.STRING)
    @Column(name = "order_status", nullable = false, length = 40)
    private LobbyOrderStatus orderStatus = LobbyOrderStatus.WAITING;

    @Column(name = "cart_locked_at")
    private Instant cartLockedAt;

    @Column(name = "created_at", nullable = false, insertable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false, insertable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    protected Lobby() {
    }

    public Lobby(User host, String restaurantName, DeliveryLocation deliveryLocation, long minimumOrderAmount, long deliveryFee) {
        this.host = host;
        this.restaurantName = restaurantName;
        this.deliveryLocation = deliveryLocation;
        this.minimumOrderAmount = minimumOrderAmount;
        this.deliveryFee = deliveryFee;
        this.currentTotalAmount = 0;
        this.orderStatus = LobbyOrderStatus.WAITING;
    }

    public Long getId() {
        return id;
    }

    public User getHost() {
        return host;
    }

    public String getRestaurantName() {
        return restaurantName;
    }

    public DeliveryLocation getDeliveryLocation() {
        return deliveryLocation;
    }

    public long getMinimumOrderAmount() {
        return minimumOrderAmount;
    }

    public long getCurrentTotalAmount() {
        return currentTotalAmount;
    }

    public long getDeliveryFee() {
        return deliveryFee;
    }

    public LobbyOrderStatus getOrderStatus() {
        return orderStatus;
    }

    public Instant getCartLockedAt() {
        return cartLockedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public Instant getDeletedAt() {
        return deletedAt;
    }

    public boolean isCartLocked() {
        return cartLockedAt != null;
    }

    public boolean isOpenForJoin() {
        return orderStatus == LobbyOrderStatus.WAITING && cartLockedAt == null && deletedAt == null;
    }

    public boolean isClosedOrCanceled() {
        return orderStatus == LobbyOrderStatus.CLOSED || orderStatus == LobbyOrderStatus.CANCELED;
    }

    public void lockCart(Instant lockedAt) {
        this.cartLockedAt = lockedAt;
        this.orderStatus = LobbyOrderStatus.LOCKED;
        this.updatedAt = lockedAt;
    }

    public void changeStatus(LobbyOrderStatus newStatus, Instant changedAt) {
        this.orderStatus = newStatus;
        if (newStatus == LobbyOrderStatus.CLOSED || newStatus == LobbyOrderStatus.CANCELED) {
            this.deletedAt = changedAt;
        }
        this.updatedAt = changedAt;
    }

    public void transferHost(User newHost, Instant changedAt) {
        this.host = newHost;
        this.updatedAt = changedAt;
    }
}
