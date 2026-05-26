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
@Table(name = "lobby_memberships")
public class LobbyMembership {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lobby_id", nullable = false)
    private Lobby lobby;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "role_in_lobby", nullable = false, length = 20)
    private LobbyMemberRole roleInLobby;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private LobbyMembershipStatus status = LobbyMembershipStatus.ACTIVE;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private Instant joinedAt;

    @Column(name = "left_at")
    private Instant leftAt;

    protected LobbyMembership() {
    }

    public LobbyMembership(Lobby lobby, User user, LobbyMemberRole roleInLobby) {
        this.lobby = lobby;
        this.user = user;
        this.roleInLobby = roleInLobby;
        this.status = LobbyMembershipStatus.ACTIVE;
        this.joinedAt = Instant.now();
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

    public LobbyMemberRole getRoleInLobby() {
        return roleInLobby;
    }

    public LobbyMembershipStatus getStatus() {
        return status;
    }

    public Instant getJoinedAt() {
        return joinedAt;
    }

    public Instant getLeftAt() {
        return leftAt;
    }

    public boolean isHost() {
        return roleInLobby == LobbyMemberRole.HOST;
    }

    public boolean isParticipant() {
        return roleInLobby == LobbyMemberRole.PARTICIPANT;
    }

    public boolean isActive() {
        return status == LobbyMembershipStatus.ACTIVE;
    }

    public void leave(Instant leftAt) {
        this.status = LobbyMembershipStatus.LEFT;
        this.leftAt = leftAt;
    }

    public void kick(Instant kickedAt) {
        this.status = LobbyMembershipStatus.KICKED;
        this.leftAt = kickedAt;
    }

    public void removeByTransfer(Instant removedAt) {
        this.status = LobbyMembershipStatus.REMOVED_BY_TRANSFER;
        this.leftAt = removedAt;
    }

    public void makeHost() {
        this.roleInLobby = LobbyMemberRole.HOST;
    }
}
