package kr.kaist.buddies.lobby.domain;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentRecordRepository extends JpaRepository<PaymentRecord, Long> {
    List<PaymentRecord> findByLobby_IdOrderByIdAsc(Long lobbyId);

    Optional<PaymentRecord> findByLobby_IdAndUser_Id(Long lobbyId, Long userId);

    Optional<PaymentRecord> findByIdAndLobby_Id(Long id, Long lobbyId);

    boolean existsByLobby_Id(Long lobbyId);

    @Query("""
        select count(p) = 0
        from PaymentRecord p
        where p.lobby.id = :lobbyId
          and p.status <> kr.kaist.buddies.lobby.domain.PaymentRecordStatus.INACTIVE
          and p.status <> kr.kaist.buddies.lobby.domain.PaymentRecordStatus.PAID
        """)
    boolean allActiveRecordsPaid(@Param("lobbyId") Long lobbyId);
}
