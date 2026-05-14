package kr.kaist.buddies.admin;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class AdminController {
    @PostMapping("/reports")
    public MessageResponse createReport(@Valid @RequestBody CreateReportRequest request) {
        return new MessageResponse("Report created for user " + request.reportedUserId());
    }

    @GetMapping("/admin/reports")
    public List<ReportResponse> reports() {
        return List.of();
    }

    @GetMapping("/admin/reports/{reportId}")
    public ReportResponse report(@PathVariable Long reportId) {
        return new ReportResponse(reportId, 1L, 2L, "OPEN");
    }

    @PatchMapping("/admin/reports/{reportId}/resolve")
    public MessageResponse resolveReport(@PathVariable Long reportId, @Valid @RequestBody ResolveReportRequest request) {
        return new MessageResponse("Report " + reportId + " resolved");
    }

    @GetMapping("/admin/lobbies/{lobbyId}/chat-archive")
    public List<ArchiveMessageResponse> chatArchive(@PathVariable Long lobbyId) {
        return List.of();
    }

    @GetMapping("/admin/users")
    public List<AdminUserResponse> users() {
        return List.of();
    }

    @GetMapping("/admin/users/{userId}")
    public AdminUserResponse user(@PathVariable Long userId) {
        return new AdminUserResponse(userId, "dev@kaist.ac.kr", "ACTIVE", 0.0);
    }

    @PostMapping("/admin/users/{userId}/moderation-actions")
    public MessageResponse moderateUser(@PathVariable Long userId, @Valid @RequestBody ModerationActionRequest request) {
        return new MessageResponse("Moderation action " + request.actionType() + " applied to user " + userId);
    }

    @GetMapping("/admin/system/overview")
    public SystemOverviewResponse overview() {
        return new SystemOverviewResponse(0, 0, 0);
    }

    public record CreateReportRequest(@NotNull Long reportedUserId, Long lobbyId, Long messageId, @NotBlank String reason) {}
    public record ResolveReportRequest(String resolutionNote) {}
    public record ModerationActionRequest(@NotBlank String actionType, String reason) {}
    public record ReportResponse(Long id, Long reporterUserId, Long reportedUserId, String status) {}
    public record ArchiveMessageResponse(Long id, Long senderUserId, String body, String createdAt) {}
    public record AdminUserResponse(Long id, String email, String status, double trustScore) {}
    public record SystemOverviewResponse(long activeLobbies, long openReports, long activeUsers) {}
    public record MessageResponse(String message) {}
}

