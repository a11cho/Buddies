package kr.kaist.buddies.admin.domain;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ModerationActionRepository extends JpaRepository<ModerationAction, Long> {
    List<ModerationAction> findByTargetUserIdOrderByCreatedAtDesc(Long targetUserId);
}
