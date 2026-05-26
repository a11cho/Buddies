package kr.kaist.buddies.auth;

import java.time.Instant;
import kr.kaist.buddies.user.domain.UserRole;

public record AuthenticatedUser(Long id, UserRole role, String tokenId, Instant expiresAt) {
}
