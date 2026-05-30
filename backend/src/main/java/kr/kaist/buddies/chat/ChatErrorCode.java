package kr.kaist.buddies.chat;

import org.springframework.http.HttpStatus;

public enum ChatErrorCode {
    AUTH_REQUIRED("CHAT_ERR01", "채팅 인증이 필요합니다."),
    FORBIDDEN_ACCESS("CHAT_ERR02", "채팅방에 접근할 권한이 없습니다."),
    LOBBY_NOT_FOUND("CHAT_ERR03", "존재하지 않는 로비입니다."),
    LOBBY_CLOSED("CHAT_ERR04", "종료된 로비의 채팅에는 접근할 수 없습니다."),
    INVALID_DESTINATION("CHAT_ERR05", "STOMP destination이 올바르지 않습니다."),
    MULTIPLE_LOBBY_SUBSCRIPTION("CHAT_ERR06", "하나의 STOMP 세션은 하나의 로비만 구독할 수 있습니다."),
    TOKEN_REVOKED("CHAT_ERR07", "토큰이 무효화되었습니다."),
    ACCOUNT_RESTRICTED("CHAT_ERR08", "계정 상태로 인해 채팅을 보낼 수 없습니다."),
    INVALID_READ_MESSAGE("CHAT_ERR09", "읽음 처리할 메시지가 해당 로비에 속하지 않습니다."),
    INVALID_MESSAGE_TYPE("CHAT_ERR10", "메시지 타입이 올바르지 않습니다."),
    MESSAGE_CONTENT_REQUIRED("CHAT_ERR11", "메시지 내용이 필요합니다."),
    MESSAGE_TOO_LONG("CHAT_ERR12", "메시지는 500자 이하로 입력해야 합니다."),
    RESTRICTED_KEYWORD("CHAT_ERR13", "제한된 표현이 포함되어 있습니다."),
    MEDIA_URL_REQUIRED("CHAT_ERR14", "MEDIA 메시지는 mediaUrl이 필요합니다."),
    INVALID_MESSAGE_PAYLOAD("CHAT_ERR15", "메시지 payload가 올바르지 않습니다."),
    SYSTEM_MESSAGE_FORBIDDEN("CHAT_ERR16", "SYSTEM 메시지는 사용자가 전송할 수 없습니다."),
    INVALID_FILE_TYPE("CHAT_ERR17", "지원하지 않는 이미지 형식입니다."),
    STOMP_ERROR("CHAT_ERR98", "STOMP 채팅 처리 중 오류가 발생했습니다."),
    UNKNOWN("CHAT_ERR99", "채팅 처리 중 오류가 발생했습니다.");

    private final String code;
    private final String message;

    ChatErrorCode(String code, String message) {
        this.code = code;
        this.message = message;
    }

    public String code() {
        return code;
    }

    public String message() {
        return message;
    }

    public ChatException exception(HttpStatus status) {
        return new ChatException(status, this);
    }
}
