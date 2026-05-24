package kr.kaist.buddies.admin.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminAuditLogRepository extends JpaRepository<AdminAuditLog, Long> {
    List<AdminAuditLog> findByAdminUserIdOrderByCreatedAtDesc(Long adminUserId);
}
