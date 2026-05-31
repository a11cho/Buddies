package kr.kaist.buddies.config;

import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserRole;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class AdminAccountInitializer implements ApplicationRunner {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final String email;
    private final String name;
    private final String password;
    private final boolean enabled;

    public AdminAccountInitializer(
        UserRepository userRepository,
        PasswordEncoder passwordEncoder,
        @Value("${buddies.admin.bootstrap.enabled:true}") boolean enabled,
        @Value("${buddies.admin.bootstrap.email:admin@kaist.ac.kr}") String email,
        @Value("${buddies.admin.bootstrap.name:Buddies Admin}") String name,
        @Value("${buddies.admin.bootstrap.password:Admin123!}") String password
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.enabled = enabled;
        this.email = email;
        this.name = name;
        this.password = password;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled || userRepository.existsByRole(UserRole.ADMIN)) {
            return;
        }
        userRepository.findByEmail(email)
            .ifPresentOrElse(
                user -> user.updateRole(UserRole.ADMIN),
                () -> userRepository.save(new User(email, name, passwordEncoder.encode(password), UserRole.ADMIN))
            );
    }
}
