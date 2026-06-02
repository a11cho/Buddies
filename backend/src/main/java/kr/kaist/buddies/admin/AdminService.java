package kr.kaist.buddies.admin;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
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
    public AdminController.AdminUserPageResponse users(String status, int page, int size) {
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), 100);
        boolean filtered = status != null && !status.isBlank();
        String normalizedStatus = filtered ? parseUserStatus(status).name() : null;
        String sql = !filtered
            ? "select id, email, name, role, status, trust_score, created_at from users order by created_at desc limit ? offset ?"
            : "select id, email, name, role, status, trust_score, created_at from users where status = ? order by created_at desc limit ? offset ?";
        Object[] args = !filtered
            ? new Object[] {safeSize, (safePage - 1) * safeSize}
            : new Object[] {normalizedStatus, safeSize, (safePage - 1) * safeSize};
        List<AdminController.AdminUserSummaryResponse> items = jdbcTemplate.query(sql, (rs, rowNum) -> new AdminController.AdminUserSummaryResponse(
            rs.getLong("id"),
            rs.getString("email"),
            rs.getString("name"),
            rs.getString("role"),
            rs.getString("status"),
            rs.getBigDecimal("trust_score").doubleValue(),
            stringOrNull(rs.getTimestamp("created_at") == null ? null : rs.getTimestamp("created_at").toInstant())
        ), args);
        Long totalCount = !filtered
            ? jdbcTemplate.queryForObject("select count(*) from users", Long.class)
            : jdbcTemplate.queryForObject("select count(*) from users where status = ?", Long.class, normalizedStatus);
        return new AdminController.AdminUserPageResponse(items, safePage, safeSize, nullToZero(totalCount));
    }

    @Transactional
    public AdminController.AdminUserDetailResponse user(AuthenticatedUser admin, Long userId) {
        User user = userOrNotFound(userId);
        audit(admin.id(), "VIEW_USER_DETAIL", "USER", userId, null);
        Long reportedCount = jdbcTemplate.queryForObject("select count(*) from reports where reported_user_id = ?", Long.class, userId);
        Long reporterCount = jdbcTemplate.queryForObject("select count(*) from reports where reporter_user_id = ?", Long.class, userId);
        Long closedLobbyCount = jdbcTemplate.queryForObject(
            """
            select count(distinct l.id)
            from lobbies l
            left join lobby_memberships lm on lm.lobby_id = l.id
            where l.order_status = 'CLOSED'
              and (l.host_user_id = ? or lm.user_id = ?)
            """,
            Long.class,
            userId,
            userId
        );
        List<AdminController.ModerationActionResponse> moderationActions = moderationActionRepository.findByTargetUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(this::moderationActionResponse)
            .toList();
        return new AdminController.AdminUserDetailResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getRole().name(),
            user.getStatus().name(),
            user.getTrustScore().doubleValue(),
            stringOrNull(user.getCreatedAt()),
            nullToZero(reportedCount),
            nullToZero(reporterCount),
            nullToZero(closedLobbyCount),
            moderationActions
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
        Instant endsAt = parseOptionalInstant(request.endsAt());
        if (actionType == ModerationActionType.SUSPEND && (endsAt == null || !endsAt.isAfter(Instant.now()))) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Suspension end time must be in the future.");
        }
        if (actionType != ModerationActionType.SUSPEND) {
            endsAt = null;
        }

        moderationActionRepository.save(new ModerationAction(targetUser, adminUser, report, actionType, request.reason(), Instant.now(), endsAt));
        UserStatus nextStatus = statusFor(actionType, targetUser.getStatus());
        targetUser.applyStatus(nextStatus, actionType == ModerationActionType.SUSPEND ? endsAt : null);
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

    private UserStatus parseUserStatus(String status) {
        try {
            return UserStatus.valueOf(status);
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid user status.");
        }
    }

    private Instant parseOptionalInstant(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException exception) {
            try {
                return OffsetDateTime.parse(value).toInstant();
            } catch (DateTimeParseException ignored) {
                throw new AuthException(HttpStatus.BAD_REQUEST, "Invalid datetime value.");
            }
        }
    }

    private UserStatus statusFor(ModerationActionType actionType, UserStatus currentStatus) {
        return switch (actionType) {
            case WARNING -> currentStatus;
            case UNSUSPEND -> UserStatus.ACTIVE;
            case SUSPEND -> UserStatus.SUSPENDED;
            case BAN -> UserStatus.BANNED;
        };
    }

    private AdminController.ModerationActionResponse moderationActionResponse(ModerationAction action) {
        Report report = action.getReport();
        User adminUser = action.getAdminUser();
        return new AdminController.ModerationActionResponse(
            action.getId(),
            action.getActionType().name(),
            action.getReason(),
            adminUser.getId(),
            adminUser.getName(),
            report == null ? null : report.getId(),
            stringOrNull(action.getStartsAt()),
            stringOrNull(action.getEndsAt()),
            stringOrNull(action.getCreatedAt())
        );
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
