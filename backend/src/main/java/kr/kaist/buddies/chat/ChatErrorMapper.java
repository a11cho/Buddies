package kr.kaist.buddies.chat;

import kr.kaist.buddies.auth.AuthException;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.MessagingException;

public final class ChatErrorMapper {
    private ChatErrorMapper() {
    }

    public static ChatErrorResponse toResponse(Throwable exception) {
        return new ChatErrorResponse(toCode(exception));
    }

    public static String toCode(Throwable exception) {
        Throwable mapped = exception instanceof MessagingException messagingException && messagingException.getCause() != null
            ? messagingException.getCause()
            : exception;
        if (mapped instanceof ChatException chatException) {
            return chatException.error();
        }
        String message = mapped.getMessage() == null ? "" : mapped.getMessage();
        if (message.contains("500자")) {
            return ChatErrorCode.MESSAGE_TOO_LONG.code();
        }
        if (message.contains("제한된 표현")) {
            return ChatErrorCode.RESTRICTED_KEYWORD.code();
        }
        if (message.contains("메시지 타입")) {
            return ChatErrorCode.INVALID_MESSAGE_TYPE.code();
        }
        if (message.contains("메시지 내용")) {
            return ChatErrorCode.MESSAGE_CONTENT_REQUIRED.code();
        }
        if (message.contains("MEDIA 메시지는 mediaUrl")) {
            return ChatErrorCode.MEDIA_URL_REQUIRED.code();
        }
        if (message.contains("USER 메시지는 mediaUrl")) {
            return ChatErrorCode.INVALID_MESSAGE_PAYLOAD.code();
        }
        if (message.contains("SYSTEM 메시지")) {
            return ChatErrorCode.SYSTEM_MESSAGE_FORBIDDEN.code();
        }
        if (message.contains("지원하지 않는 이미지")) {
            return ChatErrorCode.INVALID_FILE_TYPE.code();
        }
        if (message.contains("읽음 처리할 메시지")) {
            return ChatErrorCode.INVALID_READ_MESSAGE.code();
        }
        if (message.contains("종료된 로비")) {
            return ChatErrorCode.LOBBY_CLOSED.code();
        }
        if (message.contains("존재하지 않는 로비")) {
            return ChatErrorCode.LOBBY_NOT_FOUND.code();
        }
        if (message.contains("계정 상태")) {
            return ChatErrorCode.ACCOUNT_RESTRICTED.code();
        }
        if (message.contains("only one lobby")) {
            return ChatErrorCode.MULTIPLE_LOBBY_SUBSCRIPTION.code();
        }
        if (message.contains("Subscription destination")) {
            return ChatErrorCode.INVALID_DESTINATION.code();
        }
        if (message.contains("revoked")) {
            return ChatErrorCode.TOKEN_REVOKED.code();
        }
        if (message.contains("Authorization") || message.contains("authentication") || message.contains("토큰")) {
            return ChatErrorCode.AUTH_REQUIRED.code();
        }
        if (message.contains("접근할 권한") || message.contains("접근 권한")) {
            return ChatErrorCode.FORBIDDEN_ACCESS.code();
        }
        if (mapped instanceof AuthException authException) {
            return authCode(authException.getStatus());
        }
        if (mapped instanceof MessagingException || exception instanceof MessagingException) {
            return ChatErrorCode.STOMP_ERROR.code();
        }
        return ChatErrorCode.UNKNOWN.code();
    }

    private static String authCode(HttpStatus status) {
        return switch (status) {
            case UNAUTHORIZED -> ChatErrorCode.AUTH_REQUIRED.code();
            case FORBIDDEN -> ChatErrorCode.FORBIDDEN_ACCESS.code();
            case NOT_FOUND -> ChatErrorCode.LOBBY_NOT_FOUND.code();
            case BAD_REQUEST -> ChatErrorCode.INVALID_MESSAGE_PAYLOAD.code();
            default -> ChatErrorCode.UNKNOWN.code();
        };
    }
}
