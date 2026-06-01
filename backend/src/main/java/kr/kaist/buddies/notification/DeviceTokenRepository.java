package kr.kaist.buddies.notification;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    Optional<DeviceToken> findByDeviceToken(String deviceToken);

    List<DeviceToken> findByUser_IdAndEnabledTrue(Long userId);

    List<DeviceToken> findByUser_IdInAndEnabledTrue(List<Long> userIds);
}
