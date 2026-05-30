package kr.kaist.buddies.chat;

import org.springframework.http.HttpStatus;

public class ChatException extends RuntimeException {
    private final HttpStatus status;
    private final ChatErrorCode errorCode;

    public ChatException(HttpStatus status, ChatErrorCode errorCode) {
        super(errorCode.message());
        this.status = status;
        this.errorCode = errorCode;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public ChatErrorCode getErrorCode() {
        return errorCode;
    }

    public String error() {
        return errorCode.code();
    }
}
