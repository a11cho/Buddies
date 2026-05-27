package kr.kaist.buddies.chat;

import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.messaging.MessagingException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class StompSessionManager {
    private static final Duration IDLE_TIMEOUT = Duration.ofSeconds(90);

    private final ConcurrentMap<String, ChatSession> sessionsById = new ConcurrentHashMap<>();
    private final ConcurrentMap<Long, Set<String>> sessionIdsByUserId = new ConcurrentHashMap<>();
    private final ConcurrentMap<Long, Set<String>> sessionIdsByLobbyId = new ConcurrentHashMap<>();

    public void connect(String sessionId, Long userId) {
        requireSessionId(sessionId);
        ChatSession previous = sessionsById.put(sessionId, ChatSession.connected(sessionId, userId, Instant.now()));
        if (previous != null) {
            removeIndexes(previous);
        }
        sessionIdsByUserId.computeIfAbsent(userId, ignored -> ConcurrentHashMap.newKeySet()).add(sessionId);
    }

    public void subscribeLobby(String sessionId, Long lobbyId) {
        requireSessionId(sessionId);
        ChatSession session = sessionsById.get(sessionId);
        if (session == null) {
            throw new MessagingException("STOMP session is not connected.");
        }
        Long subscribedLobbyId = session.lobbyId();
        if (subscribedLobbyId != null && !subscribedLobbyId.equals(lobbyId)) {
            throw new MessagingException("A STOMP session can subscribe to only one lobby.");
        }
        if (subscribedLobbyId == null) {
            sessionsById.put(sessionId, session.withLobby(lobbyId, Instant.now()));
            sessionIdsByLobbyId.computeIfAbsent(lobbyId, ignored -> ConcurrentHashMap.newKeySet()).add(sessionId);
        } else {
            touch(sessionId);
        }
    }

    public void touch(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return;
        }
        sessionsById.computeIfPresent(sessionId, (id, session) -> session.withLastActivityAt(Instant.now()));
    }

    public void disconnect(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            return;
        }
        ChatSession removed = sessionsById.remove(sessionId);
        if (removed != null) {
            removeIndexes(removed);
        }
    }

    public boolean isOnlineInLobby(Long userId, Long lobbyId) {
        Set<String> sessionIds = sessionIdsByUserId.get(userId);
        if (sessionIds == null || sessionIds.isEmpty()) {
            return false;
        }
        return sessionIds.stream()
            .map(sessionsById::get)
            .filter(Objects::nonNull)
            .anyMatch(session -> lobbyId.equals(session.lobbyId()));
    }

    public List<Long> offlineUserIdsInLobby(Long lobbyId, Collection<Long> userIds) {
        return userIds.stream()
            .filter(userId -> !isOnlineInLobby(userId, lobbyId))
            .toList();
    }

    public int activeSessionCount() {
        return sessionsById.size();
    }

    @Scheduled(fixedDelay = 30_000)
    public void removeIdleSessions() {
        Instant threshold = Instant.now().minus(IDLE_TIMEOUT);
        sessionsById.values().stream()
            .filter(session -> session.lastActivityAt().isBefore(threshold))
            .map(ChatSession::sessionId)
            .toList()
            .forEach(this::disconnect);
    }

    private void removeIndexes(ChatSession session) {
        removeFromIndex(sessionIdsByUserId, session.userId(), session.sessionId());
        if (session.lobbyId() != null) {
            removeFromIndex(sessionIdsByLobbyId, session.lobbyId(), session.sessionId());
        }
    }

    private void removeFromIndex(ConcurrentMap<Long, Set<String>> index, Long key, String sessionId) {
        Set<String> sessionIds = index.get(key);
        if (sessionIds == null) {
            return;
        }
        sessionIds.remove(sessionId);
        if (sessionIds.isEmpty()) {
            index.remove(key, sessionIds);
        }
    }

    private void requireSessionId(String sessionId) {
        if (sessionId == null || sessionId.isBlank()) {
            throw new MessagingException("STOMP session id is required.");
        }
    }

    public record ChatSession(
        String sessionId,
        Long userId,
        Long lobbyId,
        Instant connectedAt,
        Instant lastActivityAt
    ) {
        static ChatSession connected(String sessionId, Long userId, Instant now) {
            return new ChatSession(sessionId, userId, null, now, now);
        }

        ChatSession withLobby(Long lobbyId, Instant now) {
            return new ChatSession(sessionId, userId, lobbyId, connectedAt, now);
        }

        ChatSession withLastActivityAt(Instant now) {
            return new ChatSession(sessionId, userId, lobbyId, connectedAt, now);
        }
    }
}
