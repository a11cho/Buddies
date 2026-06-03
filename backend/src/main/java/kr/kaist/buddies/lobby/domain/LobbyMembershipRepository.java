package kr.kaist.buddies.lobby.domain;

import java.util.List;
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

    @Query("""
        select m
        from LobbyMembership m
        join fetch m.lobby l
        join fetch l.host
        where m.user.id = :userId
          and m.status = kr.kaist.buddies.lobby.domain.LobbyMembershipStatus.ACTIVE
          and l.orderStatus not in (
              kr.kaist.buddies.lobby.domain.LobbyOrderStatus.CLOSED,
              kr.kaist.buddies.lobby.domain.LobbyOrderStatus.CANCELED
          )
        order by m.joinedAt desc
        """)
    List<LobbyMembership> findActiveLobbyMembershipsForUser(@Param("userId") Long userId);

    @Query("""
        select m
        from LobbyMembership m
        join fetch m.lobby l
        join fetch l.host
        where m.user.id = :userId
        order by m.joinedAt desc
        """)
    List<LobbyMembership> findByUserIdWithLobbyOrderByJoinedAtDesc(@Param("userId") Long userId);

    Optional<LobbyMembership> findByLobby_IdAndUser_IdAndStatus(Long lobbyId, Long userId, LobbyMembershipStatus status);

    Optional<LobbyMembership> findByLobby_IdAndUser_Id(Long lobbyId, Long userId);

    Optional<LobbyMembership> findByLobby_IdAndRoleInLobbyAndStatus(Long lobbyId, LobbyMemberRole roleInLobby, LobbyMembershipStatus status);

    List<LobbyMembership> findByLobby_IdAndStatus(Long lobbyId, LobbyMembershipStatus status);

    @Query("""
        select m
        from LobbyMembership m
        join fetch m.user
        where m.lobby.id = :lobbyId
        order by m.joinedAt asc
        """)
    List<LobbyMembership> findByLobbyIdWithUserOrderByJoinedAtAsc(@Param("lobbyId") Long lobbyId);

    long countByLobby_IdAndStatus(Long lobbyId, LobbyMembershipStatus status);

    long countByLobby_Id(Long lobbyId);
}
