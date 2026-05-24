package kr.kaist.buddies.auth;

import kr.kaist.buddies.user.domain.UserRole;

public record AuthenticatedUser(Long id, UserRole role) {
}
