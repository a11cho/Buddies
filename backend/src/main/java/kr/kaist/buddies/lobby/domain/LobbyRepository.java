package kr.kaist.buddies.lobby.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LobbyRepository extends JpaRepository<Lobby, Long> {
    @Query("""
        select l
        from Lobby l
        join fetch l.host
        where l.orderStatus = kr.kaist.buddies.lobby.domain.LobbyOrderStatus.WAITING
          and l.cartLockedAt is null
          and l.deletedAt is null
          and (:deliveryLocation is null or l.deliveryLocation = :deliveryLocation)
          and (:restaurantName is null or lower(l.restaurantName) like lower(concat('%', :restaurantName, '%')))
        order by l.createdAt desc
        """)
    List<Lobby> searchAvailable(
        @Param("deliveryLocation") DeliveryLocation deliveryLocation,
        @Param("restaurantName") String restaurantName
    );
}
