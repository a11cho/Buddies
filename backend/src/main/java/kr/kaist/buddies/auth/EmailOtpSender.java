package kr.kaist.buddies.auth;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

@Component
public class EmailOtpSender {
    private final ObjectProvider<JavaMailSender> mailSenderProvider;
    private final String from;
    private final String signupSubject;
    private final String passwordResetSubject;
    private final String passwordResetUrlTemplate;

    public EmailOtpSender(
        ObjectProvider<JavaMailSender> mailSenderProvider,
        @Value("${buddies.mail.from}") String from,
        @Value("${buddies.mail.signup-subject}") String signupSubject,
        @Value("${buddies.mail.password-reset-subject}") String passwordResetSubject,
        @Value("${buddies.password-reset.url-template}") String passwordResetUrlTemplate
    ) {
        this.mailSenderProvider = mailSenderProvider;
        this.from = from;
        this.signupSubject = signupSubject;
        this.passwordResetSubject = passwordResetSubject;
        this.passwordResetUrlTemplate = passwordResetUrlTemplate;
    }

    public void sendSignupOtp(String email, String otp) {
        JavaMailSender mailSender = mailSenderProvider.getIfAvailable();
        if (mailSender == null) {
            throw new AuthException(HttpStatus.INTERNAL_SERVER_ERROR, "메일 발송 설정이 없습니다.");
        }

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(email);
        message.setSubject(signupSubject);
        message.setText("""
            Buddies 회원가입 인증 코드입니다.

            인증 코드: %s

            이 코드는 5분 동안 유효합니다.
            본인이 요청하지 않았다면 이 메일을 무시해주세요.
            """.formatted(otp));

        try {
            mailSender.send(message);
        } catch (MailException exception) {
            throw new AuthException(HttpStatus.INTERNAL_SERVER_ERROR, "인증 코드 이메일 발송에 실패했습니다.");
        }
    }

    public void sendPasswordResetLink(String email, String token) {
        JavaMailSender mailSender = mailSenderProvider.getIfAvailable();
        if (mailSender == null) {
            throw new AuthException(HttpStatus.INTERNAL_SERVER_ERROR, "메일 발송 설정이 없습니다.");
        }

        String resetLink = passwordResetUrlTemplate.formatted(token);
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(email);
        message.setSubject(passwordResetSubject);
        message.setText("""
            Buddies 비밀번호 재설정 안내입니다.

            아래 링크에서 새 비밀번호를 설정해주세요.
            %s

            이 링크는 30분 동안 유효합니다.
            본인이 요청하지 않았다면 이 메일을 무시해주세요.
            """.formatted(resetLink));

        try {
            mailSender.send(message);
        } catch (MailException exception) {
            throw new AuthException(HttpStatus.INTERNAL_SERVER_ERROR, "비밀번호 재설정 이메일 발송에 실패했습니다.");
        }
    }
}
