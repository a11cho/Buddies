package kr.kaist.buddies.config;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.JwtTokenProvider;
import kr.kaist.buddies.auth.domain.RevokedTokenRepository;
import kr.kaist.buddies.chat.ChatService;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

@Component
public class StompAuthChannelInterceptor implements ChannelInterceptor {
    private static final Pattern CHAT_TOPIC_PATTERN = Pattern.compile("^/topic/lobbies/(\\d+)/chat$");

    private final JwtTokenProvider jwtTokenProvider;
    private final RevokedTokenRepository revokedTokenRepository;
    private final ChatService chatService;

    public StompAuthChannelInterceptor(
        JwtTokenProvider jwtTokenProvider,
        RevokedTokenRepository revokedTokenRepository,
        ChatService chatService
    ) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.revokedTokenRepository = revokedTokenRepository;
        this.chatService = chatService;
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) {
            return message;
        }
        StompCommand command = accessor.getCommand();
        if (command == null) {
            return message;
        }

        if (command == StompCommand.CONNECT) {
            accessor.setUser(authenticate(accessor.getFirstNativeHeader("Authorization")));
            return message;
        }

        Authentication authentication = currentAuthentication(accessor);
        if (command == StompCommand.SUBSCRIBE) {
            validateSubscription(authentication, accessor.getDestination());
        } else if (command == StompCommand.SEND) {
            requireAuthenticated(authentication);
        }
        return message;
    }

    private Authentication authenticate(String authorization) {
        if (authorization == null || authorization.isBlank() || !authorization.startsWith("Bearer ")) {
            throw new MessagingException("STOMP Authorization header is required.");
        }

        try {
            AuthenticatedUser user = jwtTokenProvider.parse(authorization.substring(7));
            if (revokedTokenRepository.existsByTokenId(user.tokenId())) {
                throw new MessagingException("Token has been revoked.");
            }
            return new UsernamePasswordAuthenticationToken(
                user,
                null,
                List.of(new SimpleGrantedAuthority("ROLE_" + user.role().name()))
            );
        } catch (AuthException exception) {
            throw new MessagingException(exception.getMessage(), exception);
        }
    }

    private Authentication currentAuthentication(StompHeaderAccessor accessor) {
        if (accessor.getUser() instanceof Authentication authentication) {
            return authentication;
        }
        throw new MessagingException("STOMP authentication is required.");
    }

    private void validateSubscription(Authentication authentication, String destination) {
        requireAuthenticated(authentication);
        if (destination == null) {
            throw new MessagingException("Subscription destination is required.");
        }

        Matcher matcher = CHAT_TOPIC_PATTERN.matcher(destination);
        if (matcher.matches()) {
            Long lobbyId = Long.valueOf(matcher.group(1));
            AuthenticatedUser user = (AuthenticatedUser) authentication.getPrincipal();
            try {
                chatService.requireConnectionAccess(user.id(), lobbyId);
            } catch (AuthException exception) {
                throw new MessagingException(exception.getMessage(), exception);
            }
        }
    }

    private void requireAuthenticated(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser)) {
            throw new MessagingException("STOMP authentication is required.");
        }
    }
}
