package kr.kaist.buddies.chat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.MessagingException;

class StompSessionManagerTest {
    private final StompSessionManager sessionManager = new StompSessionManager();

    @Test
    void tracksOnlineUserForSubscribedLobby() {
        sessionManager.connect("session-1", 10L);
        sessionManager.subscribeLobby("session-1", 30L);

        assertThat(sessionManager.isOnlineInLobby(10L, 30L)).isTrue();
        assertThat(sessionManager.isOnlineInLobby(10L, 31L)).isFalse();
        assertThat(sessionManager.offlineUserIdsInLobby(30L, List.of(10L, 11L))).containsExactly(11L);
    }

    @Test
    void rejectsSecondLobbySubscriptionFromSameSession() {
        sessionManager.connect("session-1", 10L);
        sessionManager.subscribeLobby("session-1", 30L);

        assertThatThrownBy(() -> sessionManager.subscribeLobby("session-1", 31L))
            .isInstanceOf(MessagingException.class)
            .hasMessageContaining("only one lobby");
    }

    @Test
    void removesSessionIndexesOnDisconnect() {
        sessionManager.connect("session-1", 10L);
        sessionManager.subscribeLobby("session-1", 30L);

        sessionManager.disconnect("session-1");

        assertThat(sessionManager.isOnlineInLobby(10L, 30L)).isFalse();
        assertThat(sessionManager.activeSessionCount()).isZero();
    }
}
