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
        if (lastReadMessageId == null) {
            Long count = jdbcTemplate.queryForObject(
                """
                select count(*)
                from chat_messages
                where lobby_id = ?
                """,
                Long.class,
                lobbyId
            );
            return count == null ? 0 : count;
        }

        Long count = jdbcTemplate.queryForObject(
            """
            select count(*)
            from chat_messages
            where lobby_id = ?
              and id > ?
            """,
            Long.class,
            lobbyId,
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
