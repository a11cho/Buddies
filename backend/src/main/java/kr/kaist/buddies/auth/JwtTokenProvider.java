package kr.kaist.buddies.auth;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import kr.kaist.buddies.user.domain.UserRole;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class JwtTokenProvider {
    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };

    private final ObjectMapper objectMapper;
    private final byte[] secret;
    private final long expiresInSeconds;

    public JwtTokenProvider(
        ObjectMapper objectMapper,
        @Value("${buddies.jwt.secret}") String secret,
        @Value("${buddies.jwt.expires-in-seconds:3600}") long expiresInSeconds
    ) {
        this.objectMapper = objectMapper;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.expiresInSeconds = expiresInSeconds;
    }

    public String createAccessToken(Long userId, UserRole role) {
        long issuedAt = Instant.now().getEpochSecond();
        long expiresAt = issuedAt + expiresInSeconds;
        try {
            String header = encodeJson(Map.of("alg", "HS256", "typ", "JWT"));
            String payload = encodeJson(Map.of(
                "sub", userId.toString(),
                "role", role.name(),
                "jti", UUID.randomUUID().toString(),
                "iat", issuedAt,
                "exp", expiresAt
            ));
            String unsignedToken = header + "." + payload;
            return unsignedToken + "." + sign(unsignedToken);
        } catch (Exception exception) {
            throw new IllegalStateException("JWT 생성에 실패했습니다.", exception);
        }
    }

    public AuthenticatedUser parse(String token) {
        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            throw invalidToken();
        }

        String unsignedToken = parts[0] + "." + parts[1];
        if (!constantTimeEquals(sign(unsignedToken), parts[2])) {
            throw invalidToken();
        }

        try {
            Map<String, Object> payload = objectMapper.readValue(BASE64_URL_DECODER.decode(parts[1]), MAP_TYPE);
            long expiresAt = ((Number) payload.get("exp")).longValue();
            if (expiresAt < Instant.now().getEpochSecond()) {
                throw new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 만료되었습니다.");
            }
            Long userId = Long.valueOf(String.valueOf(payload.get("sub")));
            UserRole role = UserRole.valueOf(String.valueOf(payload.get("role")));
            String tokenId = String.valueOf(payload.get("jti"));
            if (tokenId == null || tokenId.isBlank() || "null".equals(tokenId)) {
                throw invalidToken();
            }
            return new AuthenticatedUser(userId, role, tokenId, Instant.ofEpochSecond(expiresAt));
        } catch (AuthException exception) {
            throw exception;
        } catch (Exception exception) {
            throw invalidToken();
        }
    }

    public long expiresInSeconds() {
        return expiresInSeconds;
    }

    private String encodeJson(Map<String, Object> value) throws Exception {
        return BASE64_URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(value));
    }

    private String sign(String unsignedToken) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(secret, HMAC_ALGORITHM));
            return BASE64_URL_ENCODER.encodeToString(mac.doFinal(unsignedToken.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("JWT 서명에 실패했습니다.", exception);
        }
    }

    private boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }

    private AuthException invalidToken() {
        return new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다.");
    }
}
