package kr.kaist.buddies.admin.domain;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportRepository extends JpaRepository<Report, Long> {
    @EntityGraph(attributePaths = {"reporter", "reportedUser"})
    Page<Report> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"reporter", "reportedUser"})
    Page<Report> findByStatusOrderByCreatedAtDesc(ReportStatus status, Pageable pageable);

    long countByStatus(ReportStatus status);
}
