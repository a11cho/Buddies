package kr.kaist.buddies.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import kr.kaist.buddies.auth.AuthController.LoginResponse;
import kr.kaist.buddies.auth.AuthController.MeResponse;
import kr.kaist.buddies.auth.domain.PendingSignup;
import kr.kaist.buddies.auth.domain.PendingSignupRepository;
import kr.kaist.buddies.auth.domain.RevokedToken;
import kr.kaist.buddies.auth.domain.RevokedTokenRepository;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserStatus;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final int MAX_OTP_ATTEMPTS = 3;
    private static final int MAX_PASSWORD_LENGTH = 72;
    private static final String NAME_PATTERN = "[A-Za-z0-9가-힣 ]+";
    private static final String PASSWORD_PATTERN = "[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?`~]+";

    private final UserRepository userRepository;
    private final PendingSignupRepository pendingSignupRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final EmailOtpSender emailOtpSender;
    private final RevokedTokenRepository revokedTokenRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(
        UserRepository userRepository,
        PendingSignupRepository pendingSignupRepository,
        PasswordEncoder passwordEncoder,
        JwtTokenProvider jwtTokenProvider,
        EmailOtpSender emailOtpSender,
        RevokedTokenRepository revokedTokenRepository
    ) {
        this.userRepository = userRepository;
        this.pendingSignupRepository = pendingSignupRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.emailOtpSender = emailOtpSender;
        this.revokedTokenRepository = revokedTokenRepository;
    }

    @Transactional
    public void requestSignup(String email, String name, String password) {
        String normalizedEmail = normalizeEmail(email);
        validateSignupInput(normalizedEmail, name, password);
        rejectIfUserExists(normalizedEmail);

        Instant now = Instant.now();
        PendingSignup pendingSignup = pendingSignupRepository.findByEmail(normalizedEmail).orElse(null);
        if (pendingSignup != null && pendingSignup.getResendAvailableAt().isAfter(now)) {
            throw new AuthException(HttpStatus.TOO_MANY_REQUESTS, "인증 코드는 일정 시간이 지난 후 다시 요청할 수 있습니다.");
        }

        String otp = createOtp();
        String passwordHash = passwordEncoder.encode(password);
        String otpHash = passwordEncoder.encode(sha256Hex(otp));
        Instant otpExpiresAt = now.plus(OTP_TTL);
        Instant resendAvailableAt = now.plus(RESEND_COOLDOWN);

        if (pendingSignup == null) {
            pendingSignupRepository.save(new PendingSignup(normalizedEmail, name.trim(), passwordHash, otpHash, otpExpiresAt, resendAvailableAt));
        } else {
            pendingSignup.replaceOtp(name.trim(), passwordHash, otpHash, otpExpiresAt, resendAvailableAt);
        }
        emailOtpSender.sendSignupOtp(normalizedEmail, otp);
    }

    @Transactional
    public void verifySignup(String email, String otp) {
        String normalizedEmail = normalizeEmail(email);
        if (!validKaistEmail(normalizedEmail)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }
        PendingSignup pendingSignup = pendingSignupRepository.findByEmail(normalizedEmail)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "회원가입 요청 정보를 찾을 수 없습니다."));

        Instant now = Instant.now();
        if (pendingSignup.getOtpExpiresAt().isBefore(now)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "인증 코드가 만료되었습니다. 다시 요청해주세요.");
        }
        if (pendingSignup.getAttemptCount() >= MAX_OTP_ATTEMPTS) {
            throw new AuthException(HttpStatus.TOO_MANY_REQUESTS, "인증 시도 횟수를 초과했습니다. 인증 코드를 다시 요청해주세요.");
        }
        String otpDigest = normalizeOtpDigest(otp);
        if (otpDigest == null || !passwordEncoder.matches(otpDigest, pendingSignup.getOtpHash())) {
            pendingSignup.increaseAttemptCount();
            throw new AuthException(HttpStatus.BAD_REQUEST, "인증 코드가 올바르지 않습니다.");
        }

        rejectIfUserExists(normalizedEmail);
        userRepository.save(new User(pendingSignup.getEmail(), pendingSignup.getName(), pendingSignup.getPasswordHash()));
        pendingSignupRepository.delete(pendingSignup);
    }

    @Transactional
    public void resendSignup(String email) {
        String normalizedEmail = normalizeEmail(email);
        if (!validKaistEmail(normalizedEmail)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }
        PendingSignup pendingSignup = pendingSignupRepository.findByEmail(normalizedEmail)
            .orElseThrow(() -> new AuthException(HttpStatus.NOT_FOUND, "회원가입 요청 정보를 찾을 수 없습니다."));

        Instant now = Instant.now();
        if (pendingSignup.getResendAvailableAt().isAfter(now)) {
            throw new AuthException(HttpStatus.TOO_MANY_REQUESTS, "인증 코드는 일정 시간이 지난 후 다시 요청할 수 있습니다.");
        }

        String otp = createOtp();
        pendingSignup.replaceOtp(
            pendingSignup.getName(),
            pendingSignup.getPasswordHash(),
            passwordEncoder.encode(sha256Hex(otp)),
            now.plus(OTP_TTL),
            now.plus(RESEND_COOLDOWN)
        );
        emailOtpSender.sendSignupOtp(normalizedEmail, otp);
    }

    @Transactional(readOnly = true)
    public LoginResponse login(String email, String password) {
        String normalizedEmail = normalizeEmail(email);
        if (!validKaistEmail(normalizedEmail) || password == null || password.isBlank()) {
            throw invalidCredentials();
        }
        User user = userRepository.findByEmail(normalizedEmail)
            .orElseThrow(this::invalidCredentials);
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw invalidCredentials();
        }
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new AuthException(HttpStatus.FORBIDDEN, "접근 권한이 없습니다.");
        }
        return createLoginResponse(user);
    }

    @Transactional(readOnly = true)
    public MeResponse me(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
        return new MeResponse(user.getId(), user.getEmail(), user.getName(), user.getRole().name());
    }

    @Transactional(readOnly = true)
    public LoginResponse refresh(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new AuthException(HttpStatus.UNAUTHORIZED, "토큰이 올바르지 않습니다."));
        return createLoginResponse(user);
    }

    @Transactional
    public void logout(AuthenticatedUser user) {
        if (!revokedTokenRepository.existsByTokenId(user.tokenId())) {
            revokedTokenRepository.save(new RevokedToken(user.tokenId(), user.expiresAt(), Instant.now()));
        }
    }

    private LoginResponse createLoginResponse(User user) {
        return new LoginResponse(jwtTokenProvider.createAccessToken(user.getId(), user.getRole()), "Bearer", jwtTokenProvider.expiresInSeconds());
    }

    private void rejectIfUserExists(String email) {
        if (userRepository.existsByEmail(email)) {
            throw new AuthException(HttpStatus.CONFLICT, "이미 사용 중인 이메일입니다.");
        }
    }

    private void validateSignupInput(String email, String name, String password) {
        if (!validKaistEmail(email) || !validName(name) || !validPassword(password)) {
            throw new AuthException(HttpStatus.BAD_REQUEST, "입력값이 올바르지 않습니다.");
        }
    }

    private boolean validKaistEmail(String email) {
        return email != null && email.endsWith("@kaist.ac.kr");
    }

    private boolean validName(String name) {
        return name != null
            && !name.isBlank()
            && name.equals(name.trim())
            && name.length() <= 100
            && name.matches(NAME_PATTERN);
    }

    private boolean validPassword(String password) {
        return password != null
            && password.length() >= 8
            && password.length() <= MAX_PASSWORD_LENGTH
            && password.matches(PASSWORD_PATTERN)
            && password.chars().anyMatch(Character::isLetter)
            && password.chars().anyMatch(Character::isDigit)
            && password.chars().anyMatch(ch -> !Character.isLetterOrDigit(ch));
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    private String createOtp() {
        return String.format("%06d", secureRandom.nextInt(1_000_000));
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 알고리즘을 사용할 수 없습니다.", exception);
        }
    }

    private String normalizeOtpDigest(String otpDigest) {
        if (otpDigest == null) {
            return null;
        }
        String normalized = otpDigest.trim().toLowerCase();
        if (!normalized.matches("[0-9a-f]{64}")) {
            return null;
        }
        return normalized;
    }

    private AuthException invalidCredentials() {
        return new AuthException(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다.");
    }
}
