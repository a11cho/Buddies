package kr.kaist.buddies.lobby.domain;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LobbyMembershipRepository extends JpaRepository<LobbyMembership, Long> {
    @Query("""
        select count(m) > 0
        from LobbyMembership m
        where m.user.id = :userId
          and m.status = kr.kaist.buddies.lobby.domain.LobbyMembershipStatus.ACTIVE
          and m.lobby.orderStatus not in (
              kr.kaist.buddies.lobby.domain.LobbyOrderStatus.CLOSED,
              kr.kaist.buddies.lobby.domain.LobbyOrderStatus.CANCELED
          )
        """)
    boolean existsActiveLobbyForUser(@Param("userId") Long userId);

    Optional<LobbyMembership> findByLobby_IdAndUser_IdAndStatus(Long lobbyId, Long userId, LobbyMembershipStatus status);

    Optional<LobbyMembership> findByLobby_IdAndRoleInLobbyAndStatus(Long lobbyId, LobbyMemberRole roleInLobby, LobbyMembershipStatus status);

    long countByLobby_IdAndStatus(Long lobbyId, LobbyMembershipStatus status);
}
