package kr.kaist.buddies.lobby.domain;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CartItemRepository extends JpaRepository<CartItem, Long> {
    List<CartItem> findByLobby_IdAndDeletedAtIsNullOrderByCreatedAtAsc(Long lobbyId);

    Optional<CartItem> findByIdAndLobby_IdAndDeletedAtIsNull(Long id, Long lobbyId);

    List<CartItem> findByLobby_IdAndOwner_IdAndDeletedAtIsNull(Long lobbyId, Long ownerId);

    @Query("""
        select coalesce(sum(c.subtotal), 0)
        from CartItem c
        where c.lobby.id = :lobbyId
          and c.deletedAt is null
        """)
    long sumActiveSubtotalByLobbyId(@Param("lobbyId") Long lobbyId);
}
