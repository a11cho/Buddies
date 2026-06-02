package kr.kaist.buddies.config;

import java.util.Collection;
import kr.kaist.buddies.auth.AuthenticatedUser;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;

public class StompAuthenticationToken extends UsernamePasswordAuthenticationToken {
    private final AuthenticatedUser user;

    public StompAuthenticationToken(
        AuthenticatedUser user,
        Collection<? extends GrantedAuthority> authorities
    ) {
        super(user, null, authorities);
        this.user = user;
    }

    @Override
    public String getName() {
        return String.valueOf(user.id());
    }
}
