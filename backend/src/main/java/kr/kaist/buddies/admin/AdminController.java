package kr.kaist.buddies.admin;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping
public class AdminController {
    private final AdminService adminService;

    public AdminController(AdminService adminService) {
        this.adminService = adminService;
    }

    @PostMapping("/reports")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse createReport(@CurrentUser AuthenticatedUser currentUser, @Valid @RequestBody CreateReportRequest request) {
        adminService.createReport(currentUser, request);
        return new MessageResponse("Report has been submitted.");
    }

    @GetMapping("/admin/reports")
    public ReportPageResponse reports(
        @RequestParam(required = false) String status,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return adminService.listReports(status, page, size);
    }

    @GetMapping("/admin/reports/{reportId}")
    public ReportDetailResponse report(@CurrentUser AuthenticatedUser admin, @PathVariable Long reportId) {
        return adminService.getReport(admin, reportId);
    }

    @PatchMapping("/admin/reports/{reportId}/resolve")
    public MessageResponse resolveReport(
        @CurrentUser AuthenticatedUser admin,
        @PathVariable Long reportId,
        @Valid @RequestBody ResolveReportRequest request
    ) {
        adminService.resolveReport(admin, reportId, request.resolutionNote());
        return new MessageResponse("Report has been resolved.");
    }

    @GetMapping("/admin/lobbies/{lobbyId}")
    public AdminLobbyResponse adminLobby(@CurrentUser AuthenticatedUser admin, @PathVariable Long lobbyId) {
        return adminService.adminLobby(admin, lobbyId);
    }

    @GetMapping("/admin/lobbies/{lobbyId}/chat-archive")
    public ChatArchiveResponse chatArchive(@CurrentUser AuthenticatedUser admin, @PathVariable Long lobbyId) {
        return adminService.chatArchive(admin, lobbyId);
    }

    @GetMapping("/admin/lobbies/{lobbyId}/payment-records")
    public List<AdminPaymentRecordResponse> adminPaymentRecords(@CurrentUser AuthenticatedUser admin, @PathVariable Long lobbyId) {
        return adminService.paymentRecords(admin, lobbyId);
    }

    @GetMapping("/admin/users")
    public AdminUserPageResponse users(
        @RequestParam(required = false) String status,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return adminService.users(status, page, size);
    }

    @GetMapping("/admin/support-tickets")
    public SupportTicketPageResponse supportTickets(
        @RequestParam(required = false) String status,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        return adminService.supportTickets(status, page, size);
    }

    @GetMapping("/admin/support-tickets/{ticketId}")
    public SupportTicketDetailResponse supportTicket(@CurrentUser AuthenticatedUser admin, @PathVariable Long ticketId) {
        return adminService.supportTicket(admin, ticketId);
    }

    @PatchMapping("/admin/support-tickets/{ticketId}")
    public MessageResponse updateSupportTicket(
        @CurrentUser AuthenticatedUser admin,
        @PathVariable Long ticketId,
        @Valid @RequestBody UpdateSupportTicketRequest request
    ) {
        adminService.updateSupportTicket(admin, ticketId, request);
        return new MessageResponse("Support ticket has been updated.");
    }

    @GetMapping("/admin/users/{userId}")
    public AdminUserDetailResponse user(@CurrentUser AuthenticatedUser admin, @PathVariable Long userId) {
        return adminService.user(admin, userId);
    }

    @PostMapping("/admin/users/{userId}/moderation-actions")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse moderateUser(
        @CurrentUser AuthenticatedUser admin,
        @PathVariable Long userId,
        @Valid @RequestBody ModerationActionRequest request
    ) {
        adminService.moderateUser(admin, userId, request);
        return new MessageResponse("Moderation action has been applied.");
    }

    @GetMapping("/admin/system/overview")
    public SystemOverviewResponse overview() {
        return adminService.overview();
    }

    public record CreateReportRequest(@NotNull Long lobbyId, @NotNull Long reportedUserId, Long reportedMessageId, @NotBlank String reason, String description) {}
    public record ResolveReportRequest(String resolutionNote) {}
    public record ModerationActionRequest(@NotBlank String actionType, @NotBlank String reason, String endsAt, Long reportId) {}
    public record UpdateSupportTicketRequest(@NotBlank String status, String resolutionNote) {}
    public record UserReference(Long id, String name) {}
    public record ReportSummaryResponse(Long reportId, Long lobbyId, Long reporterUserId, Long reportedUserId, String reason, String status, String createdAt) {}
    public record ReportPageResponse(List<ReportSummaryResponse> items, int page, int size, long totalCount) {}
    public record ReportDetailResponse(
        Long reportId,
        Long lobbyId,
        UserReference reporter,
        UserReference reportedUser,
        Long reportedMessageId,
        String reason,
        String description,
        String status,
        String resolutionNote,
        String createdAt
    ) {}
    public record SupportTicketSummaryResponse(
        Long ticketId,
        Long userId,
        String userName,
        Long lobbyId,
        String category,
        String title,
        String status,
        String createdAt,
        String updatedAt
    ) {}
    public record SupportTicketPageResponse(List<SupportTicketSummaryResponse> items, int page, int size, long totalCount) {}
    public record SupportTicketDetailResponse(
        Long ticketId,
        UserReference user,
        Long lobbyId,
        String category,
        String title,
        String body,
        String status,
        String resolutionNote,
        UserReference resolvedByAdmin,
        String resolvedAt,
        String createdAt,
        String updatedAt
    ) {}
    public record ChatArchiveResponse(Long lobbyId, List<ArchiveMessageResponse> messages) {}
    public record ArchiveMessageResponse(
        Long messageId,
        Long lobbyId,
        Long senderUserId,
        String senderName,
        String messageType,
        String content,
        String mediaUrl,
        boolean reported,
        String createdAt
    ) {}
    public record AdminUserSummaryResponse(Long id, String email, String name, String role, String status, double trustScore, String createdAt) {}
    public record AdminUserPageResponse(List<AdminUserSummaryResponse> items, int page, int size, long totalCount) {}
    public record AdminUserDetailResponse(
        Long id,
        String email,
        String name,
        String role,
        String status,
        double trustScore,
        String createdAt,
        long reportedCount,
        long reporterCount,
        long closedLobbyCount,
        List<ModerationActionResponse> moderationActions
    ) {}
    public record ModerationActionResponse(Long id, String actionType, String reason, Long adminUserId, String adminName, Long reportId, String startsAt, String endsAt, String createdAt) {}
    public record AdminLobbyResponse(Long lobbyId, String restaurantName, String deliveryLocation, Long hostUserId, long currentTotal, String orderStatus, boolean cartLocked) {}
    public record AdminPaymentRecordResponse(Long id, Long userId, String userName, long amount, String status, String confirmedAt) {}
    public record SystemOverviewResponse(
        long activeLobbyCount,
        long cartLockedLobbyCount,
        long activeUserCount,
        long openReportCount,
        long openSupportTicketCount,
        long suspendedUserCount,
        List<RecentLobbyResponse> recentLobbies
    ) {}
    public record RecentLobbyResponse(Long lobbyId, String restaurantName, String deliveryLocation, Long hostUserId, int participantCount, long currentTotal, String orderStatus, boolean cartLocked, String createdAt) {}
    public record MessageResponse(String message) {}
}
