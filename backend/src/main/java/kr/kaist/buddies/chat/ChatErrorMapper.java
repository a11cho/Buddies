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
        String message = exception.getMessage() == null ? "" : exception.getMessage();
        if (message.contains("500자")) {
            return "MESSAGE_TOO_LONG";
        }
        if (message.contains("제한된 표현")) {
            return "RESTRICTED_KEYWORD";
        }
        if (message.contains("메시지 타입")) {
            return "INVALID_MESSAGE_TYPE";
        }
        if (message.contains("메시지 내용")) {
            return "MESSAGE_CONTENT_REQUIRED";
        }
        if (message.contains("MEDIA 메시지는 mediaUrl")) {
            return "MEDIA_URL_REQUIRED";
        }
        if (message.contains("USER 메시지는 mediaUrl")) {
            return "INVALID_MESSAGE_PAYLOAD";
        }
        if (message.contains("SYSTEM 메시지")) {
            return "SYSTEM_MESSAGE_FORBIDDEN";
        }
        if (message.contains("지원하지 않는 이미지")) {
            return "INVALID_FILE_TYPE";
        }
        if (message.contains("읽음 처리할 메시지")) {
            return "INVALID_READ_MESSAGE";
        }
        if (message.contains("종료된 로비")) {
            return "LOBBY_CLOSED";
        }
        if (message.contains("존재하지 않는 로비")) {
            return "LOBBY_NOT_FOUND";
        }
        if (message.contains("계정 상태")) {
            return "ACCOUNT_RESTRICTED";
        }
        if (message.contains("only one lobby")) {
            return "MULTIPLE_LOBBY_SUBSCRIPTION";
        }
        if (message.contains("Subscription destination")) {
            return "INVALID_DESTINATION";
        }
        if (message.contains("Authorization") || message.contains("authentication") || message.contains("토큰")) {
            return "AUTH_REQUIRED";
        }
        if (message.contains("revoked")) {
            return "TOKEN_REVOKED";
        }
        if (message.contains("접근할 권한") || message.contains("접근 권한")) {
            return "FORBIDDEN_ACCESS";
        }
        if (exception instanceof AuthException authException) {
            return authCode(authException.getStatus());
        }
        if (exception instanceof MessagingException) {
            return "STOMP_ERROR";
        }
        return "CHAT_ERROR";
    }

    private static String authCode(HttpStatus status) {
        return switch (status) {
            case UNAUTHORIZED -> "AUTH_REQUIRED";
            case FORBIDDEN -> "FORBIDDEN_ACCESS";
            case NOT_FOUND -> "LOBBY_NOT_FOUND";
            case CONFLICT -> "LOBBY_CONFLICT";
            case BAD_REQUEST -> "INVALID_CHAT_REQUEST";
            default -> "CHAT_ERROR";
        };
    }
}
