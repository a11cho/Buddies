package kr.kaist.buddies.auth.domain;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HostPaymentInfoRepository extends JpaRepository<HostPaymentInfo, Long> {
    Optional<HostPaymentInfo> findByUser_Id(Long userId);

    boolean existsByUser_Id(Long userId);
}
