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
        order by l.createdAt desc
        """)
    List<Lobby> findAvailable();

    @Query("""
        select l
        from Lobby l
        join fetch l.host
        where l.orderStatus = kr.kaist.buddies.lobby.domain.LobbyOrderStatus.WAITING
          and l.cartLockedAt is null
          and l.deletedAt is null
          and l.deliveryLocation = :deliveryLocation
        order by l.createdAt desc
        """)
    List<Lobby> findAvailableByDeliveryLocation(@Param("deliveryLocation") DeliveryLocation deliveryLocation);

    @Query("""
        select l
        from Lobby l
        join fetch l.host
        where l.orderStatus = kr.kaist.buddies.lobby.domain.LobbyOrderStatus.WAITING
          and l.cartLockedAt is null
          and l.deletedAt is null
          and lower(l.restaurantName) like lower(concat('%', :restaurantName, '%'))
        order by l.createdAt desc
        """)
    List<Lobby> findAvailableByRestaurantName(@Param("restaurantName") String restaurantName);

    @Query("""
        select l
        from Lobby l
        join fetch l.host
        where l.orderStatus = kr.kaist.buddies.lobby.domain.LobbyOrderStatus.WAITING
          and l.cartLockedAt is null
          and l.deletedAt is null
          and l.deliveryLocation = :deliveryLocation
          and lower(l.restaurantName) like lower(concat('%', :restaurantName, '%'))
        order by l.createdAt desc
        """)
    List<Lobby> findAvailableByDeliveryLocationAndRestaurantName(
        @Param("deliveryLocation") DeliveryLocation deliveryLocation,
        @Param("restaurantName") String restaurantName
    );
}
