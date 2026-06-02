package kr.kaist.buddies.lobby;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class LobbyExceptionHandler {
    @ExceptionHandler(LobbyException.class)
    ResponseEntity<Map<String, String>> handleLobbyException(LobbyException exception) {
        return ResponseEntity.status(exception.getStatus()).body(Map.of("error", exception.error()));
    }
}
