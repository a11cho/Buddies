package kr.kaist.buddies.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/signup/request")
    public MessageResponse requestSignup(@Valid @RequestBody SignupRequest request) {
        authService.requestSignup(request.email(), request.name(), request.password());
        return new MessageResponse("인증 코드가 이메일로 전송되었습니다.");
    }

    @PostMapping("/signup/verify")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse verifySignup(@Valid @RequestBody SignupVerifyRequest request) {
        authService.verifySignup(request.email(), request.otp());
        return new MessageResponse("회원가입이 완료되었습니다.");
    }

    @PostMapping("/signup/resend")
    public MessageResponse resendSignup(@Valid @RequestBody EmailRequest request) {
        authService.resendSignup(request.email());
        return new MessageResponse("인증 코드가 이메일로 전송되었습니다.");
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request.email(), request.password());
    }

    @GetMapping("/me")
    public MeResponse me(@CurrentUser AuthenticatedUser user) {
        return authService.me(user.id());
    }

    @PostMapping("/refresh")
    public LoginResponse refresh(@CurrentUser AuthenticatedUser user) {
        return authService.refresh(user.id());
    }

    @PostMapping("/logout")
    public MessageResponse logout(@CurrentUser AuthenticatedUser user) {
        authService.logout(user);
        return new MessageResponse("로그아웃되었습니다.");
    }

    @PostMapping("/password-reset/request")
    public MessageResponse requestPasswordReset(@Valid @RequestBody EmailRequest request) {
        authService.requestPasswordReset(request.email());
        return new MessageResponse("입력한 이메일로 비밀번호 재설정 안내를 보냈습니다.");
    }

    @PostMapping("/password-reset/confirm")
    public MessageResponse confirmPasswordReset(@Valid @RequestBody PasswordResetConfirmRequest request) {
        authService.confirmPasswordReset(request.token(), request.newPassword(), request.newPasswordConfirm());
        return new MessageResponse("비밀번호가 재설정되었습니다. 새 비밀번호로 로그인해주세요.");
    }

    public record SignupRequest(@Email @NotBlank String email, @NotBlank String name, @NotBlank String password) {}
    public record SignupVerifyRequest(@Email @NotBlank String email, @NotBlank String otp) {}
    public record EmailRequest(@Email @NotBlank String email) {}
    public record LoginRequest(@Email @NotBlank String email, @NotBlank String password) {}
    public record PasswordResetConfirmRequest(
        @NotBlank String token,
        @NotBlank String newPassword,
        @NotBlank String newPasswordConfirm
    ) {}
    public record LoginResponse(String accessToken, String tokenType, long expiresIn) {}
    public record MeResponse(Long id, String email, String name, String role) {}
    public record MessageResponse(String message) {}
}
