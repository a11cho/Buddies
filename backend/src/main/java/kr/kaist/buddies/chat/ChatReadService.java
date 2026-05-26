package kr.kaist.buddies.chat;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class ChatReadService {
    private final JdbcTemplate jdbcTemplate;

    public ChatReadService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public long countUnread(Long lobbyId, Long lastReadMessageId) {
        Long count = jdbcTemplate.queryForObject(
            """
            select count(*)
            from chat_messages
            where lobby_id = ?
              and (? is null or id > ?)
            """,
            Long.class,
            lobbyId,
            lastReadMessageId,
            lastReadMessageId
        );
        return count == null ? 0 : count;
    }

    public boolean messageBelongsToLobby(Long lobbyId, Long messageId) {
        Long count = jdbcTemplate.queryForObject(
            "select count(*) from chat_messages where lobby_id = ? and id = ?",
            Long.class,
            lobbyId,
            messageId
        );
        return count != null && count > 0;
    }
}
