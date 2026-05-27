package kr.kaist.buddies.admin;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import kr.kaist.buddies.admin.domain.AdminAuditLog;
import kr.kaist.buddies.admin.domain.AdminAuditLogRepository;
import kr.kaist.buddies.admin.domain.ModerationAction;
import kr.kaist.buddies.admin.domain.ModerationActionRepository;
import kr.kaist.buddies.admin.domain.ModerationActionType;
import kr.kaist.buddies.admin.domain.Report;
import kr.kaist.buddies.admin.domain.ReportRepository;
import kr.kaist.buddies.admin.domain.ReportStatus;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {
    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final AdminAuditLogRepository auditLogRepository;
    private final ModerationActionRepository moderationActionRepository;
    private final JdbcTemplate jdbcTemplate;

    public AdminService(
        ReportRepository reportRepository,
        UserRepository userRepository,
        AdminAuditLogRepository auditLogRepository,
        ModerationActionRepository moderationActionRepository,
        JdbcTemplate jdbcTemplate
    ) {
        this.reportRepository = reportRepository;
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.moderationActionRepository = moderationActionRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public void createReport(AuthenticatedUser currentUser, AdminController.CreateReportRequest request) {
        User reporter = userOrNotFound(currentUser.id());
        User reportedUser = userOrNotFound(request.reportedUserId());
        ensureActiveLobbyMember(request.lobbyId(), currentUser.id());
        ensureActiveLobbyMember(request.lobbyId(), request.reportedUserId());
        if (request.reportedMessageId() != null) {
            ensureMessageBelongsToLobby(request.lobbyId(), request.reportedMessageId());
        }

        reportRepository.save(new Report(
            request.lobbyId(),
            reporter,
            reportedUser,
            request.reportedMessageId(),
            request.reason(),
            request.description()
        ));
    }

    @Transactional(readOnly = true)
    public AdminController.ReportPageResponse listReports(String status, int page, int size) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        PageRequest pageRequest = PageRequest.of(safePage - 1, safeSize);
        Page<Report> reports = status == null || status.isBlank()
            ? reportRepository.findAllByOrderByCreatedAtDesc(pageRequest)
            : reportRepository.findByStatusOrderByCreatedAtDesc(parseReportStatus(status), pageRequest);

        List<AdminController.ReportSummaryResponse> items = reports.stream()
            .map(report -> new AdminController.ReportSummaryResponse(
                report.getId(),
                report.getLobbyId(),
                report.getReporter().getId(),
                report.getReportedUser().getId(),
                report.getReason(),
                report.getStatus().name(),
                stringOrNull(report.getCreatedAt())
            ))
            .toList();
        return new AdminController.ReportPageResponse(items, safePage, safeSize, reports.getTotalElements());
    }

    @Transactional
    public AdminController.ReportDetailResponse getReport(AuthenticatedUser admin, Long reportId) {
        Report report = reportRepository.findById(reportId)
            .orElseThrow(() -> notFound("Report not found."));
        audit(admin.id(), "VIEW_REPORT", "REPORT", reportId, null);
        return new AdminController.ReportDetailResponse(
            report.getId(),
            report.getLobbyId(),
            userRef(report.getReporter()),
            userRef(report.getReportedUser()),
            report.getReportedMessageId(),
            report.getReason(),
            report.getDescription(),
            report.getStatus().name(),
            report.getResolutionNote(),
            stringOrNull(report.getCreatedAt())
        );
    }

    @Transactional
    public void resolveReport(AuthenticatedUser admin, Long reportId, String resolutionNote) {
        User adminUser = userOrNotFound(admin.id());
        Report report = reportRepository.findById(reportId)
            .orElseThrow(() -> notFound("Report not found."));
        report.resolve(adminUser, resolutionNote, Instant.now());
        auditLogRepository.save(new AdminAuditLog(adminUser, "RESOLVE_REPORT", "REPORT", reportId, null));
    }

    @Transactional
    public AdminController.ChatArchiveResponse chatArchive(AuthenticatedUser admin, Long lobbyId) {
        if (!existsById("lobbies", lobbyId)) {
            throw notFound("Lobby not found.");
        }
        audit(admin.id(), "VIEW_CHAT_ARCHIVE", "LOBBY", lobbyId, null);
        List<Long> reportedMessageIds = jdbcTemplate.queryForList(
            "select reported_message_id from reports where lobby_id = ? and reported_message_id is not null",
            Long.class,
            lobbyId
        );
        List<AdminController.ArchiveMessageResponse> messages = jdbcTemplate.query(
            """
            select cm.id, cm.lobby_id, cm.sender_user_id, u.name as sender_name, cm.message_type,
                   cm.content, cm.media_url, cm.created_at
            from chat_messages cm
            left join users u on u.id = cm.sender_user_id
            where cm.lobby_id = ?
            order by cm.created_at asc, cm.id asc
            """,
            (rs, rowNum) -> archiveMessage(rs, reportedMessageIds.contains(rs.getLong("id"))),
            lobbyId
        );
        return new AdminController.ChatArchiveResponse(lobbyId, messages);
    }

    @Transactional(readOnly = true)
    public AdminController.SystemOverviewResponse overview() {
        Long activeLobbyCount = jdbcTemplate.queryForObject(
            "select count(*) from lobbies where order_status not in ('CLOSED', 'CANCELED') and deleted_at is null",
            Long.class
        );
        Long lockedLobbyCount = jdbcTemplate.queryForObject(
            "select count(*) from lobbies where cart_locked_at is not null and order_status not in ('CLOSED', 'CANCELED')",
            Long.class
        );
        Long activeUserCount = jdbcTemplate.queryForObject("select count(*) from users where status = 'ACTIVE'", Long.class);
        Long suspendedUserCount = jdbcTemplate.queryForObject("select count(*) from users where status = 'SUSPENDED'", Long.class);
        List<AdminController.RecentLobbyResponse> recentLobbies = jdbcTemplate.query(
            """
            select l.id, l.restaurant_name, l.delivery_location, l.host_user_id,
                   l.current_total_amount, l.order_status, l.cart_locked_at, l.created_at,
                   count(lm.id) filter (where lm.status = 'ACTIVE') as participant_count
            from lobbies l
            left join lobby_memberships lm on lm.lobby_id = l.id
            group by l.id
            order by l.created_at desc
            limit 5
            """,
            (rs, rowNum) -> new AdminController.RecentLobbyResponse(
                rs.getLong("id"),
                rs.getString("restaurant_name"),
                rs.getString("delivery_location"),
                rs.getLong("host_user_id"),
                rs.getInt("participant_count"),
                rs.getLong("current_total_amount"),
                rs.getString("order_status"),
                rs.getTimestamp("cart_locked_at") != null,
                stringOrNull(rs.getTimestamp("created_at") == null ? null : rs.getTimestamp("created_at").toInstant())
            )
        );
        return new AdminController.SystemOverviewResponse(
            nullToZero(activeLobbyCount),
            nullToZero(lockedLobbyCount),
            nullToZero(activeUserCount),
            reportRepository.countByStatus(ReportStatus.OPEN),
            nullToZero(suspendedUserCount),
            recentLobbies
        );
    }

    @Transactional(readOnly = true)
    public List<AdminController.AdminUserResponse> users(String status, int page, int size) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        String sql = status == null || status.isBlank()
            ? "select id, email, name, status, trust_score from users order by created_at desc limit ? offset ?"
            : "select id, email, name, status, trust_score from users where status = ? order by created_at desc limit ? offset ?";
        Object[] args = status == null || status.isBlank()
            ? new Object[] {safeSize, (safePage - 1) * safeSize}
            : new Object[] {status, safeSize, (safePage - 1) * safeSize};
        return jdbcTemplate.query(sql, (rs, rowNum) -> new AdminController.AdminUserResponse(
            rs.getLong("id"),
            rs.getString("email"),
            rs.getString("name"),
            rs.getString("status"),
            rs.getBigDecimal("trust_score").doubleValue()
        ), args);
    }

    @Transactional
    public AdminController.AdminUserResponse user(AuthenticatedUser admin, Long userId) {
        User user = userOrNotFound(userId);
        audit(admin.id(), "VIEW_USER_DETAIL", "USER", userId, null);
        return new AdminController.AdminUserResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getStatus().name(),
            user.getTrustScore().doubleValue()
        );
    }

    @Transactional
    public void moderateUser(AuthenticatedUser admin, Long userId, AdminController.ModerationActionRequest request) {
        if (admin.id().equals(userId)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Admins cannot moderate themselves.");
        }
        User adminUser = userOrNotFound(admin.id());
        User targetUser = userOrNotFound(userId);
        Report report = request.reportId() == null ? null : reportRepository.findById(request.reportId())
            .orElseThrow(() -> notFound("Report not found."));
        ModerationActionType actionType = parseModerationActionType(request.actionType());
        Instant endsAt = request.endsAt() == null || request.endsAt().isBlank() ? null : Instant.parse(request.endsAt());

        moderationActionRepository.save(new ModerationAction(targetUser, adminUser, report, actionType, request.reason(), Instant.now(), endsAt));
        targetUser.applyStatus(statusFor(actionType), actionType == ModerationActionType.SUSPEND ? endsAt : null);
        auditLogRepository.save(new AdminAuditLog(adminUser, "CREATE_MODERATION_ACTION", "USER", userId, "{\"actionType\":\"" + actionType.name() + "\"}"));
    }

    @Transactional
    public AdminController.AdminLobbyResponse adminLobby(AuthenticatedUser admin, Long lobbyId) {
        AdminController.AdminLobbyResponse lobby = jdbcTemplate.query(
            "select id, restaurant_name, delivery_location, host_user_id, current_total_amount, order_status, cart_locked_at from lobbies where id = ?",
            rs -> {
                if (!rs.next()) {
                    throw notFound("Lobby not found.");
                }
                return new AdminController.AdminLobbyResponse(
                    rs.getLong("id"),
                    rs.getString("restaurant_name"),
                    rs.getString("delivery_location"),
                    rs.getLong("host_user_id"),
                    rs.getLong("current_total_amount"),
                    rs.getString("order_status"),
                    rs.getTimestamp("cart_locked_at") != null
                );
            },
            lobbyId
        );
        audit(admin.id(), "VIEW_LOBBY_DETAIL", "LOBBY", lobbyId, null);
        return lobby;
    }

    @Transactional
    public List<AdminController.AdminPaymentRecordResponse> paymentRecords(AuthenticatedUser admin, Long lobbyId) {
        audit(admin.id(), "VIEW_PAYMENT_RECORDS", "LOBBY", lobbyId, null);
        return jdbcTemplate.query(
            """
            select pr.id, pr.user_id, u.name, pr.amount, pr.status, pr.confirmed_at
            from payment_records pr
            join users u on u.id = pr.user_id
            where pr.lobby_id = ?
            order by pr.created_at asc
            """,
            (rs, rowNum) -> new AdminController.AdminPaymentRecordResponse(
                rs.getLong("id"),
                rs.getLong("user_id"),
                rs.getString("name"),
                rs.getLong("amount"),
                rs.getString("status"),
                stringOrNull(rs.getTimestamp("confirmed_at") == null ? null : rs.getTimestamp("confirmed_at").toInstant())
            ),
            lobbyId
        );
    }

    private void ensureActiveLobbyMember(Long lobbyId, Long userId) {
        Integer count = jdbcTemplate.queryForObject(
            "select count(*) from lobby_memberships where lobby_id = ? and user_id = ? and status = 'ACTIVE'",
            Integer.class,
            lobbyId,
            userId
        );
        if (count == null || count == 0) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "User is not an active member of the lobby.");
        }
    }

    private void ensureMessageBelongsToLobby(Long lobbyId, Long messageId) {
        Integer count = jdbcTemplate.queryForObject(
            "select count(*) from chat_messages where id = ? and lobby_id = ?",
            Integer.class,
            messageId,
            lobbyId
        );
        if (count == null || count == 0) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Reported message does not belong to the lobby.");
        }
    }

    private boolean existsById(String table, Long id) {
        Integer count = jdbcTemplate.queryForObject("select count(*) from " + table + " where id = ?", Integer.class, id);
        return count != null && count > 0;
    }

    private User userOrNotFound(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> notFound("User not found."));
    }

    private void audit(Long adminUserId, String action, String targetType, Long targetId, String metadataJson) {
        auditLogRepository.save(new AdminAuditLog(userOrNotFound(adminUserId), action, targetType, targetId, metadataJson));
    }

    private AdminController.UserReference userRef(User user) {
        return new AdminController.UserReference(user.getId(), user.getName());
    }

    private AdminController.ArchiveMessageResponse archiveMessage(ResultSet rs, boolean reported) throws SQLException {
        return new AdminController.ArchiveMessageResponse(
            rs.getLong("id"),
            rs.getLong("lobby_id"),
            nullableLong(rs, "sender_user_id"),
            rs.getString("sender_name"),
            rs.getString("message_type"),
            rs.getString("content"),
            rs.getString("media_url"),
            reported,
            stringOrNull(rs.getTimestamp("created_at") == null ? null : rs.getTimestamp("created_at").toInstant())
        );
    }

    private ReportStatus parseReportStatus(String status) {
        try {
            return ReportStatus.valueOf(status);
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid report status.");
        }
    }

    private Long nullableLong(ResultSet rs, String columnName) throws SQLException {
        long value = rs.getLong(columnName);
        return rs.wasNull() ? null : value;
    }

    private ModerationActionType parseModerationActionType(String actionType) {
        try {
            return ModerationActionType.valueOf(actionType);
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid moderation action type.");
        }
    }

    private UserStatus statusFor(ModerationActionType actionType) {
        return switch (actionType) {
            case WARNING, UNSUSPEND -> UserStatus.ACTIVE;
            case SUSPEND -> UserStatus.SUSPENDED;
            case BAN -> UserStatus.BANNED;
        };
    }

    private AuthException notFound(String message) {
        return new AuthException(HttpStatus.NOT_FOUND, message);
    }

    private String stringOrNull(Instant instant) {
        return instant == null ? null : instant.toString();
    }

    private long nullToZero(Long value) {
        return value == null ? 0 : value;
    }
}
