package kr.kaist.buddies.chat;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ChatArchiveRepository extends JpaRepository<ChatArchive, Long> {
    Optional<ChatArchive> findByLobbyId(Long lobbyId);

    List<ChatArchive> findByRetentionUntilBeforeOrderByRetentionUntilAsc(Instant now);
}
