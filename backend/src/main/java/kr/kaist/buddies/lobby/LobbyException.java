package kr.kaist.buddies.lobby;

import org.springframework.http.HttpStatus;

public class LobbyException extends RuntimeException {
    private final HttpStatus status;
    private final LobbyErrorCode errorCode;

    public LobbyException(HttpStatus status, LobbyErrorCode errorCode) {
        super(errorCode.message());
        this.status = status;
        this.errorCode = errorCode;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public LobbyErrorCode getErrorCode() {
        return errorCode;
    }

    public String error() {
        return errorCode.code();
    }
}
