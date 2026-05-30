package kr.kaist.buddies.chat;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.MessagingException;

class ChatErrorMapperTest {
    @Test
    void mapsKnownChatValidationErrors() {
        assertThat(ChatErrorMapper.toCode(ChatErrorCode.MESSAGE_TOO_LONG.exception(HttpStatus.BAD_REQUEST)))
            .isEqualTo(ChatErrorCode.MESSAGE_TOO_LONG.code());
        assertThat(ChatErrorMapper.toCode(ChatErrorCode.RESTRICTED_KEYWORD.exception(HttpStatus.BAD_REQUEST)))
            .isEqualTo(ChatErrorCode.RESTRICTED_KEYWORD.code());
        assertThat(ChatErrorMapper.toCode(ChatErrorCode.INVALID_MESSAGE_TYPE.exception(HttpStatus.BAD_REQUEST)))
            .isEqualTo(ChatErrorCode.INVALID_MESSAGE_TYPE.code());
    }

    @Test
    void mapsStompSessionErrors() {
        assertThat(ChatErrorMapper.toCode(new MessagingException("A STOMP session can subscribe to only one lobby.")))
            .isEqualTo(ChatErrorCode.MULTIPLE_LOBBY_SUBSCRIPTION.code());
    }

    @Test
    void mapsWrappedChatException() {
        ChatException exception = ChatErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN);

        assertThat(ChatErrorMapper.toCode(new MessagingException(exception.getMessage(), exception)))
            .isEqualTo(ChatErrorCode.FORBIDDEN_ACCESS.code());
    }
}
