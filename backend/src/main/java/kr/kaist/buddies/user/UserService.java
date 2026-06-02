package kr.kaist.buddies.user;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.user.UserController.FaqResponse;
import kr.kaist.buddies.user.UserController.MessageResponse;
import kr.kaist.buddies.user.UserController.OrderHistoryItem;
import kr.kaist.buddies.user.UserController.OrderHistoryResponse;
import kr.kaist.buddies.user.UserController.ProfileImageUploadUrlRequest;
import kr.kaist.buddies.user.UserController.ProfileImageUploadUrlResponse;
import kr.kaist.buddies.user.UserController.ProfileResponse;
import kr.kaist.buddies.user.UserController.RatingRequest;
import kr.kaist.buddies.user.UserController.SupportTicketRequest;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserStatus;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {
    private static final String NAME_PATTERN = "[A-Za-z0-9가-힣 ]+";
    private static final int MAX_NAME_LENGTH = 100;
    private static final int MAX_PROFILE_IMAGE_URL_LENGTH = 500;

    private final UserRepository userRepository;
    private final JdbcTemplate jdbcTemplate;

    public UserService(UserRepository userRepository, JdbcTemplate jdbcTemplate) {
        this.userRepository = userRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public ProfileResponse profile(Long userId) {
        return toProfileResponse(findUser(userId));
    }

    @Transactional
    public ProfileResponse updateProfile(Long userId, Map<String, Object> request) {
        rejectImmutableProfileFields(request);

        String name = stringValue(request.get("name"));
        String profileImageUrl = nullableStringValue(request.get("profileImageUrl"));
        if (!validName(name) || !validProfileImageUrl(profileImageUrl)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }

        User user = findUser(userId);
        requireActive(user);
        user.updateProfile(name.trim(), profileImageUrl);
        return toProfileResponse(user);
    }

    @Transactional(readOnly = true)
    public ProfileImageUploadUrlResponse issueProfileImageUploadUrl(Long userId, ProfileImageUploadUrlRequest request) {
        requireActive(findUser(userId));
        String extension = requireSupportedImageType(request.contentType());
        String safeFilename = request.filename().replaceAll("[^A-Za-z0-9._-]", "_");
        return new ProfileImageUploadUrlResponse(
            "https://storage.example.com/profile/" + userId + "/" + safeFilename,
            "https://cdn.example.com/profile/" + userId + extension
        );
    }

    @Transactional(readOnly = true)
    public OrderHistoryResponse orderHistory(Long userId) {
        String sql = """
            SELECT
                l.id AS lobby_id,
                l.restaurant_name,
                l.delivery_location,
                l.updated_at AS delivered_at,
                host.name AS host_name,
                (
                    SELECT COUNT(DISTINCT member_count.user_id)
                    FROM lobby_memberships member_count
                    WHERE member_count.lobby_id = l.id
                ) AS participant_count,
                (
                    SELECT COALESCE(SUM(payment_sum.amount), 0)
                    FROM payment_records payment_sum
                    WHERE payment_sum.lobby_id = l.id
                ) AS total_amount,
                COALESCE(my_payment.amount, 0) AS my_amount,
                EXISTS (
                    SELECT 1
                    FROM lobby_memberships peer
                    WHERE peer.lobby_id = l.id
                      AND peer.user_id <> ?
                      AND NOT EXISTS (
                          SELECT 1
                          FROM ratings r
                          WHERE r.lobby_id = l.id
                            AND r.rater_user_id = ?
                            AND r.target_user_id = peer.user_id
                      )
                ) AS can_rate
            FROM lobbies l
            JOIN lobby_memberships mine ON mine.lobby_id = l.id AND mine.user_id = ?
            JOIN users host ON host.id = l.host_user_id
            LEFT JOIN payment_records my_payment ON my_payment.lobby_id = l.id AND my_payment.user_id = ?
            WHERE l.order_status IN ('DELIVERED', 'CLOSED')
            ORDER BY l.updated_at DESC
            """;

        List<OrderHistoryItem> items = jdbcTemplate.query(
            sql,
            (rs, rowNum) -> mapOrderHistoryItem(rs),
            userId,
            userId,
            userId,
            userId
        );
        return new OrderHistoryResponse(items);
    }

    @Transactional
    public MessageResponse createRating(Long raterUserId, RatingRequest request) {
        requireActive(findUser(raterUserId));
        if (request.lobbyId() == null || request.targetUserId() == null) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }
        if (raterUserId.equals(request.targetUserId())) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "자기 자신은 평가할 수 없습니다.");
        }
        if (!existsById("users", request.targetUserId())) {
            throw new AuthException(HttpStatus.NOT_FOUND, "대상 사용자를 찾을 수 없습니다.");
        }
        if (!existsById("lobbies", request.lobbyId())) {
            throw new AuthException(HttpStatus.NOT_FOUND, "대상 로비를 찾을 수 없습니다.");
        }
        if (!isClosedLobby(request.lobbyId())) {
            throw new AuthException(HttpStatus.FORBIDDEN, "닫힌 로비의 사용자만 평가할 수 있습니다.");
        }
        if (!wasLobbyMember(request.lobbyId(), raterUserId) || !wasLobbyMember(request.lobbyId(), request.targetUserId())) {
            throw new AuthException(HttpStatus.FORBIDDEN, "같은 로비에 참여한 사용자만 평가할 수 있습니다.");
        }
        if (ratingExists(request.lobbyId(), raterUserId, request.targetUserId())) {
            throw new AuthException(HttpStatus.CONFLICT, "이미 해당 로비에서 이 사용자를 평가했습니다.");
        }

        try {
            jdbcTemplate.update(
                "INSERT INTO ratings (lobby_id, rater_user_id, target_user_id, rating, feedback) VALUES (?, ?, ?, ?, ?)",
                request.lobbyId(),
                raterUserId,
                request.targetUserId(),
                request.rating(),
                nullableStringValue(request.feedback())
            );
        } catch (DuplicateKeyException exception) {
            throw new AuthException(HttpStatus.CONFLICT, "이미 해당 로비에서 이 사용자를 평가했습니다.");
        }
        recalculateTrustScore(request.targetUserId());
        return new MessageResponse("평가가 등록되었습니다.");
    }

    @Transactional(readOnly = true)
    public List<FaqResponse> faqs() {
        return List.of(
            new FaqResponse("otp_expired", "OTP가 만료되면 회원가입 화면에서 인증 코드를 다시 요청해주세요."),
            new FaqResponse("deep_link_failed", "외부 결제 앱이 열리지 않으면 결제 앱 설치 여부와 로그인 상태를 확인해주세요."),
            new FaqResponse("lobby_full", "로비가 잠겼거나 주문이 진행 중이면 새 참여가 제한될 수 있습니다."),
            new FaqResponse("payment_delayed", "결제 확인이 지연되면 Host에게 채팅으로 알리고 필요하면 Direct Contact를 제출해주세요."),
            new FaqResponse("report_user", "채팅 또는 로비에서 문제가 발생하면 Report 기능으로 Admin 검토를 요청할 수 있습니다.")
        );
    }

    @Transactional
    public MessageResponse createSupportTicket(Long userId, SupportTicketRequest request) {
        requireActive(findUser(userId));
        if (request.lobbyId() != null && !existsById("lobbies", request.lobbyId())) {
            throw new AuthException(HttpStatus.NOT_FOUND, "대상 로비를 찾을 수 없습니다.");
        }
        jdbcTemplate.update(
            "INSERT INTO support_tickets (user_id, lobby_id, category, title, body) VALUES (?, ?, ?, ?, ?)",
            userId,
            request.lobbyId(),
            request.category().trim(),
            request.title().trim(),
            request.body().trim()
        );
        return new MessageResponse("문의가 등록되었습니다.");
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
    }

    private ProfileResponse toProfileResponse(User user) {
        return new ProfileResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getRole().name(),
            user.getProfileImageUrl(),
            user.getTrustScore().doubleValue(),
            user.getStatus().name()
        );
    }

    private void requireActive(User user) {
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new AuthException(HttpStatus.FORBIDDEN, "접근 권한이 없습니다.");
        }
    }

    private OrderHistoryItem mapOrderHistoryItem(ResultSet rs) throws SQLException {
        Instant deliveredAt = rs.getTimestamp("delivered_at").toInstant();
        return new OrderHistoryItem(
            rs.getLong("lobby_id"),
            rs.getString("restaurant_name"),
            rs.getString("delivery_location"),
            deliveredAt.toString(),
            rs.getString("host_name"),
            rs.getInt("participant_count"),
            rs.getLong("total_amount"),
            rs.getLong("my_amount"),
            null,
            rs.getBoolean("can_rate")
        );
    }

    private void rejectImmutableProfileFields(Map<String, Object> request) {
        if (request.containsKey("email") || request.containsKey("id") || request.containsKey("role")
            || request.containsKey("trustScore") || request.containsKey("status")) {
            throw new AuthException(HttpStatus.FORBIDDEN, "수정할 수 없는 프로필 항목입니다.");
        }
    }

    private boolean validName(String name) {
        return name != null
            && !name.isBlank()
            && name.equals(name.trim())
            && name.length() <= MAX_NAME_LENGTH
            && name.matches(NAME_PATTERN);
    }

    private boolean validProfileImageUrl(String profileImageUrl) {
        return profileImageUrl == null || profileImageUrl.length() <= MAX_PROFILE_IMAGE_URL_LENGTH;
    }

    private String requireSupportedImageType(String contentType) {
        return switch (contentType) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/gif" -> ".gif";
            case "image/webp" -> ".webp";
            default -> throw new AuthException(HttpStatus.BAD_REQUEST, "지원하지 않는 이미지 형식입니다.");
        };
    }

    private String stringValue(Object value) {
        return value instanceof String string ? string : null;
    }

    private String nullableStringValue(Object value) {
        if (value == null) {
            return null;
        }
        if (!(value instanceof String string)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }
        String trimmed = string.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private boolean existsById(String tableName, Long id) {
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + tableName + " WHERE id = ?", Integer.class, id);
        return count != null && count > 0;
    }

    private boolean isClosedLobby(Long lobbyId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM lobbies WHERE id = ? AND order_status IN ('DELIVERED', 'CLOSED')",
            Integer.class,
            lobbyId
        );
        return count != null && count > 0;
    }

    private boolean wasLobbyMember(Long lobbyId, Long userId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM lobby_memberships WHERE lobby_id = ? AND user_id = ?",
            Integer.class,
            lobbyId,
            userId
        );
        return count != null && count > 0;
    }

    private boolean ratingExists(Long lobbyId, Long raterUserId, Long targetUserId) {
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM ratings WHERE lobby_id = ? AND rater_user_id = ? AND target_user_id = ?",
            Integer.class,
            lobbyId,
            raterUserId,
            targetUserId
        );
        return count != null && count > 0;
    }

    private void recalculateTrustScore(Long targetUserId) {
        BigDecimal trustScore = jdbcTemplate.queryForObject(
            "SELECT COALESCE(AVG(rating), 0)::numeric(3,2) FROM ratings WHERE target_user_id = ?",
            BigDecimal.class,
            targetUserId
        );
        jdbcTemplate.update("UPDATE users SET trust_score = ?, updated_at = now() WHERE id = ?", trustScore, targetUserId);
    }
}
