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
@RequestMapping("/api/auth")
public class AuthController {
    @PostMapping("/signup/request")
    public MessageResponse requestSignup(@Valid @RequestBody SignupRequest request) {
        // Passwords must travel only over HTTPS/TLS and be stored with bcrypt in the service layer.
        return new MessageResponse("OTP requested for " + request.email());
    }

    @PostMapping("/signup/verify")
    @ResponseStatus(HttpStatus.CREATED)
    public MessageResponse verifySignup(@Valid @RequestBody SignupVerifyRequest request) {
        // The client network layer sends SHA-256 encoded OTP values.
        return new MessageResponse("Signup verified for " + request.email());
    }

    @PostMapping("/signup/resend")
    public MessageResponse resendSignup(@Valid @RequestBody EmailRequest request) {
        return new MessageResponse("OTP resent for " + request.email());
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        // TODO: Implement password-hash verification, account-status check, and real JWT issuing.
        return new LoginResponse("development-token", "Bearer", 3600);
    }

    @GetMapping("/me")
    public MeResponse me() {
        // TODO: Resolve current user from JWT subject instead of returning the development user.
        return new MeResponse(1L, "dev@kaist.ac.kr", "Development User", "USER");
    }

    @PostMapping("/refresh")
    public LoginResponse refresh() {
        // TODO: Decide refresh-token storage/revocation policy and validate refresh tokens here.
        return new LoginResponse("development-token", "Bearer", 3600);
    }

    @PostMapping("/logout")
    public MessageResponse logout() {
        // TODO: Persist revoked token id or invalidate refresh token after token strategy is finalized.
        return new MessageResponse("Logged out");
    }

    @PostMapping("/password-reset/request")
    public MessageResponse requestPasswordReset(@Valid @RequestBody EmailRequest request) {
        return new MessageResponse("Password reset requested for " + request.email());
    }

    @PostMapping("/password-reset/confirm")
    public MessageResponse confirmPasswordReset(@Valid @RequestBody PasswordResetConfirmRequest request) {
        // The client network layer sends SHA-256 encoded reset token values.
        return new MessageResponse("Password reset confirmed");
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
