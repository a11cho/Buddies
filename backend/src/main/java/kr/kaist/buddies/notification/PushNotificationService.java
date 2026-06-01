package kr.kaist.buddies.notification;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.notification.PushNotificationController.DeleteDeviceTokenRequest;
import kr.kaist.buddies.notification.PushNotificationController.DeviceTokenRequest;
import kr.kaist.buddies.notification.PushNotificationController.DeviceTokenResponse;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PushNotificationService {
    private static final int MAX_TOKEN_LENGTH = 500;

    private final DeviceTokenRepository deviceTokenRepository;
    private final PushNotificationRepository pushNotificationRepository;
    private final UserRepository userRepository;
    private final PushNotificationSender pushNotificationSender;

    public PushNotificationService(
        DeviceTokenRepository deviceTokenRepository,
        PushNotificationRepository pushNotificationRepository,
        UserRepository userRepository,
        PushNotificationSender pushNotificationSender
    ) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.pushNotificationRepository = pushNotificationRepository;
        this.userRepository = userRepository;
        this.pushNotificationSender = pushNotificationSender;
    }

    @Transactional
    public DeviceTokenResponse registerToken(Long userId, DeviceTokenRequest request) {
        User user = findUser(userId);
        DevicePlatform platform = parsePlatform(request.platform());
        String token = normalizeToken(request.deviceToken());
        Instant now = Instant.now();
        DeviceToken deviceToken = deviceTokenRepository.findByDeviceToken(token)
            .map(existing -> {
                existing.refresh(user, platform, now);
                return existing;
            })
            .orElseGet(() -> deviceTokenRepository.save(new DeviceToken(user, token, platform, now)));
        return toResponse(deviceToken);
    }

    @Transactional(readOnly = true)
    public List<DeviceTokenResponse> listTokens(Long userId) {
        return deviceTokenRepository.findByUser_IdAndEnabledTrue(userId).stream()
            .sorted(Comparator.comparing(DeviceToken::getUpdatedAt).reversed())
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public void disableToken(Long userId, DeleteDeviceTokenRequest request) {
        String token = normalizeToken(request.deviceToken());
        DeviceToken deviceToken = deviceTokenRepository.findByDeviceToken(token)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "등록된 디바이스 토큰을 찾을 수 없습니다."));
        if (!deviceToken.getUser().getId().equals(userId)) {
            throw new AuthException(HttpStatus.FORBIDDEN, "디바이스 토큰을 삭제할 권한이 없습니다.");
        }
        deviceToken.disable(Instant.now());
    }

    @Transactional
    public void sendChatPush(Long userId, PushMessage message) {
        User user = findUser(userId);
        List<DeviceToken> deviceTokens = deviceTokenRepository.findByUser_IdAndEnabledTrue(userId);
        PushNotification notification = pushNotificationRepository.save(new PushNotification(
            user,
            message.lobbyId(),
            message.messageId(),
            message.title(),
            message.body(),
            Instant.now()
        ));
        if (deviceTokens.isEmpty()) {
            notification.markSkipped("No enabled device tokens.");
            return;
        }

        try {
            deviceTokens.forEach(deviceToken -> pushNotificationSender.send(deviceToken, message));
            notification.markSent(Instant.now());
        } catch (RuntimeException exception) {
            notification.markFailed(truncate(exception.getMessage()));
        }
    }

    private User findUser(Long userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
    }

    private DevicePlatform parsePlatform(String value) {
        if (value == null || value.isBlank()) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "디바이스 플랫폼이 필요합니다.");
        }
        try {
            return DevicePlatform.valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException exception) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "지원하지 않는 디바이스 플랫폼입니다.");
        }
    }

    private String normalizeToken(String value) {
        if (value == null || value.isBlank() || value.length() > MAX_TOKEN_LENGTH) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "디바이스 토큰이 올바르지 않습니다.");
        }
        return value.trim();
    }

    private String truncate(String value) {
        if (value == null) {
            return "Push provider failed.";
        }
        return value.length() <= 500 ? value : value.substring(0, 500);
    }

    private DeviceTokenResponse toResponse(DeviceToken deviceToken) {
        return new DeviceTokenResponse(
            deviceToken.getId(),
            deviceToken.getPlatform().name(),
            deviceToken.isEnabled(),
            deviceToken.getLastSeenAt().toString(),
            deviceToken.getUpdatedAt().toString()
        );
    }
}
