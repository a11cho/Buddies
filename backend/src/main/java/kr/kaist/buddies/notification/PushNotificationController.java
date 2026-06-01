package kr.kaist.buddies.notification;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.CurrentUser;
import kr.kaist.buddies.user.UserController.MessageResponse;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/users/me/device-tokens")
public class PushNotificationController {
    private final PushNotificationService pushNotificationService;

    public PushNotificationController(PushNotificationService pushNotificationService) {
        this.pushNotificationService = pushNotificationService;
    }

    @GetMapping
    public List<DeviceTokenResponse> list(@CurrentUser AuthenticatedUser user) {
        return pushNotificationService.listTokens(user.id());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DeviceTokenResponse register(@CurrentUser AuthenticatedUser user, @Valid @RequestBody DeviceTokenRequest request) {
        return pushNotificationService.registerToken(user.id(), request);
    }

    @DeleteMapping
    public MessageResponse delete(@CurrentUser AuthenticatedUser user, @Valid @RequestBody DeleteDeviceTokenRequest request) {
        pushNotificationService.disableToken(user.id(), request);
        return new MessageResponse("디바이스 토큰이 삭제되었습니다.");
    }

    public record DeviceTokenRequest(@NotBlank @Size(max = 500) String deviceToken, @NotBlank String platform) {}
    public record DeleteDeviceTokenRequest(@NotBlank @Size(max = 500) String deviceToken) {}
    public record DeviceTokenResponse(Long deviceTokenId, String platform, boolean enabled, String lastSeenAt, String updatedAt) {}
}
