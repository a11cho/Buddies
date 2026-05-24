package kr.kaist.buddies.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class EmailOtpSender {
    private static final Logger log = LoggerFactory.getLogger(EmailOtpSender.class);

    public void sendSignupOtp(String email, String otp) {
        log.info("Signup OTP for {} is {}", email, otp);
    }
}
