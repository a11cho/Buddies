package kr.kaist.buddies.chat;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    @Query("""
        select m
        from ChatMessage m
        left join fetch m.sender
        where m.lobby.id = :lobbyId
        order by m.id desc
        """)
    List<ChatMessage> findLatest(@Param("lobbyId") Long lobbyId, Pageable pageable);

    @Query("""
        select m
        from ChatMessage m
        left join fetch m.sender
        where m.lobby.id = :lobbyId
          and m.id < :cursor
        order by m.id desc
        """)
    List<ChatMessage> findBeforeCursor(@Param("lobbyId") Long lobbyId, @Param("cursor") Long cursor, Pageable pageable);

    boolean existsByIdAndLobby_Id(Long id, Long lobbyId);
}
