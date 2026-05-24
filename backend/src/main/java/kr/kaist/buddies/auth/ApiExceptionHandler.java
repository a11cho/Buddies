package kr.kaist.buddies.auth;

import jakarta.validation.ConstraintViolationException;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(AuthException.class)
    ResponseEntity<Map<String, String>> handleAuthException(AuthException exception) {
        return ResponseEntity.status(exception.getStatus()).body(Map.of("error", exception.getMessage()));
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, ConstraintViolationException.class})
    ResponseEntity<Map<String, String>> handleValidationException(Exception exception) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "입력값이 올바르지 않습니다."));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<Map<String, String>> handleDataIntegrityException(DataIntegrityViolationException exception) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", "이미 사용 중인 이메일입니다."));
    }
}
