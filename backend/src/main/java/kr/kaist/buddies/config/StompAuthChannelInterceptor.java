package kr.kaist.buddies.config;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import kr.kaist.buddies.auth.AuthException;
import kr.kaist.buddies.auth.AuthenticatedUser;
import kr.kaist.buddies.auth.JwtTokenProvider;
import kr.kaist.buddies.auth.domain.RevokedTokenRepository;
import kr.kaist.buddies.chat.ChatErrorMapper;
import kr.kaist.buddies.chat.ChatErrorPublishedEvent;
import kr.kaist.buddies.chat.ChatService;
import kr.kaist.buddies.chat.StompSessionManager;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

@Component
public class StompAuthChannelInterceptor implements ChannelInterceptor {
    private static final Pattern CHAT_TOPIC_PATTERN = Pattern.compile("^/topic/lobbies/(\\d+)/chat$");
    private static final Pattern CHAT_SEND_PATTERN = Pattern.compile("^/app/lobbies/(\\d+)/chat/send$");

    private final JwtTokenProvider jwtTokenProvider;
    private final RevokedTokenRepository revokedTokenRepository;
    private final ChatService chatService;
    private final StompSessionManager stompSessionManager;
    private final ApplicationEventPublisher eventPublisher;

    public StompAuthChannelInterceptor(
        JwtTokenProvider jwtTokenProvider,
        RevokedTokenRepository revokedTokenRepository,
        ChatService chatService,
        StompSessionManager stompSessionManager,
        ApplicationEventPublisher eventPublisher
    ) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.revokedTokenRepository = revokedTokenRepository;
        this.chatService = chatService;
        this.stompSessionManager = stompSessionManager;
        this.eventPublisher = eventPublisher;
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
            Authentication authentication = authenticate(accessor.getFirstNativeHeader("Authorization"));
            accessor.setUser(authentication);
            stompSessionManager.connect(accessor.getSessionId(), ((AuthenticatedUser) authentication.getPrincipal()).id());
            return message;
        }

        if (command == StompCommand.DISCONNECT) {
            stompSessionManager.disconnect(accessor.getSessionId());
            return message;
        }

        Authentication authentication = currentAuthentication(accessor);
        if (command == StompCommand.SUBSCRIBE) {
            validateSubscription(authentication, accessor.getSessionId(), accessor.getDestination());
        } else if (command == StompCommand.SEND) {
            requireAuthenticated(authentication);
            validateSendDestination(authentication, accessor.getDestination());
            stompSessionManager.touch(accessor.getSessionId());
        } else {
            stompSessionManager.touch(accessor.getSessionId());
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
            return new StompAuthenticationToken(
                user,
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

    private void validateSubscription(Authentication authentication, String sessionId, String destination) {
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
                stompSessionManager.subscribeLobby(sessionId, lobbyId);
            } catch (MessagingException exception) {
                publishError(authentication, exception);
                throw exception;
            } catch (AuthException exception) {
                publishError(authentication, exception);
                throw new MessagingException(exception.getMessage(), exception);
            }
        }
    }

    private void validateSendDestination(Authentication authentication, String destination) {
        if (destination == null) {
            return;
        }
        Matcher matcher = CHAT_SEND_PATTERN.matcher(destination);
        if (matcher.matches()) {
            Long lobbyId = Long.valueOf(matcher.group(1));
            AuthenticatedUser user = (AuthenticatedUser) authentication.getPrincipal();
            try {
                chatService.requireConnectionAccess(user.id(), lobbyId);
            } catch (AuthException exception) {
                publishError(authentication, exception);
                throw new MessagingException(exception.getMessage(), exception);
            }
        }
    }

    private void publishError(Authentication authentication, Exception exception) {
        if (authentication == null) {
            return;
        }
        eventPublisher.publishEvent(new ChatErrorPublishedEvent(
            authentication.getName(),
            ChatErrorMapper.toResponse(exception)
        ));
    }

    private void requireAuthenticated(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser)) {
            throw new MessagingException("STOMP authentication is required.");
        }
    }
}
