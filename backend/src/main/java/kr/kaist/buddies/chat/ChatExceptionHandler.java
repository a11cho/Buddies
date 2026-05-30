package kr.kaist.buddies.chat;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ChatExceptionHandler {
    @ExceptionHandler(ChatException.class)
    ResponseEntity<Map<String, String>> handleChatException(ChatException exception) {
        return ResponseEntity.status(exception.getStatus()).body(Map.of("error", exception.error()));
    }
}
