package kr.kaist.buddies.chat;

import static org.assertj.core.api.Assertions.assertThat;

import kr.kaist.buddies.auth.AuthException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.MessagingException;

class ChatErrorMapperTest {
    @Test
    void mapsKnownChatValidationErrors() {
        assertThat(ChatErrorMapper.toCode(new AuthException(HttpStatus.BAD_REQUEST, "메시지는 500자 이하로 입력해야 합니다.")))
            .isEqualTo("MESSAGE_TOO_LONG");
        assertThat(ChatErrorMapper.toCode(new AuthException(HttpStatus.BAD_REQUEST, "제한된 표현이 포함되어 있습니다.")))
            .isEqualTo("RESTRICTED_KEYWORD");
        assertThat(ChatErrorMapper.toCode(new AuthException(HttpStatus.BAD_REQUEST, "메시지 타입이 올바르지 않습니다.")))
            .isEqualTo("INVALID_MESSAGE_TYPE");
    }

    @Test
    void mapsStompSessionErrors() {
        assertThat(ChatErrorMapper.toCode(new MessagingException("A STOMP session can subscribe to only one lobby.")))
            .isEqualTo("MULTIPLE_LOBBY_SUBSCRIPTION");
    }
}
