package kr.kaist.buddies.chat;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatArchiveService {
    private static final Duration RETENTION_PERIOD = Duration.ofDays(30);

    private final ChatArchiveRepository chatArchiveRepository;
    private final JdbcTemplate jdbcTemplate;

    public ChatArchiveService(ChatArchiveRepository chatArchiveRepository, JdbcTemplate jdbcTemplate) {
        this.chatArchiveRepository = chatArchiveRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public ChatArchive archiveLobby(Long lobbyId) {
        Instant now = Instant.now();
        jdbcTemplate.update("update chat_messages set is_archived = true where lobby_id = ?", lobbyId);
        return chatArchiveRepository.findByLobbyId(lobbyId)
            .orElseGet(() -> chatArchiveRepository.save(new ChatArchive(lobbyId, now, now.plus(RETENTION_PERIOD))));
    }

    @Transactional
    @Scheduled(cron = "0 0 4 * * *")
    public void deleteExpiredArchives() {
        deleteExpiredArchives(Instant.now());
    }

    @Transactional
    public int deleteExpiredArchives(Instant now) {
        List<ChatArchive> expiredArchives = chatArchiveRepository.findByRetentionUntilBeforeOrderByRetentionUntilAsc(now);
        expiredArchives.forEach(this::deleteArchiveMessages);
        return expiredArchives.size();
    }

    private void deleteArchiveMessages(ChatArchive archive) {
        Long lobbyId = archive.getLobbyId();
        jdbcTemplate.update(
            "update lobby_memberships set last_read_message_id = null, last_read_at = null where lobby_id = ?",
            lobbyId
        );
        jdbcTemplate.update(
            "update chat_read_states set last_read_message_id = null, last_read_at = null where lobby_id = ?",
            lobbyId
        );
        jdbcTemplate.update("update reports set reported_message_id = null where lobby_id = ?", lobbyId);
        jdbcTemplate.update("delete from chat_messages where lobby_id = ? and is_archived = true", lobbyId);
        chatArchiveRepository.delete(archive);
    }
}
