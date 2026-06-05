package kr.kaist.buddies.lobby;

import java.util.List;
import java.util.Locale;
import kr.kaist.buddies.chat.ChatService;
import kr.kaist.buddies.lobby.LobbyController.ReceiptAttachRequest;
import kr.kaist.buddies.lobby.LobbyController.ReceiptResponse;
import kr.kaist.buddies.lobby.LobbyController.ReceiptUploadUrlRequest;
import kr.kaist.buddies.lobby.LobbyController.ReceiptUploadUrlResponse;
import kr.kaist.buddies.lobby.domain.Lobby;
import kr.kaist.buddies.lobby.domain.LobbyMembershipRepository;
import kr.kaist.buddies.lobby.domain.LobbyMembershipStatus;
import kr.kaist.buddies.lobby.domain.LobbyOrderStatus;
import kr.kaist.buddies.lobby.domain.LobbyRepository;
import kr.kaist.buddies.lobby.domain.ReceiptAttachment;
import kr.kaist.buddies.lobby.domain.ReceiptAttachmentRepository;
import kr.kaist.buddies.lobby.domain.ReceiptAttachmentStatus;
import kr.kaist.buddies.storage.ImageUploadUrlService;
import kr.kaist.buddies.storage.ImageUploadUrlService.ImageUploadUrl;
import kr.kaist.buddies.user.domain.User;
import kr.kaist.buddies.user.domain.UserRepository;
import kr.kaist.buddies.user.domain.UserStatus;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ReceiptAttachmentService {
    private static final long MAX_RECEIPT_FILE_SIZE_BYTES = 10L * 1024L * 1024L;
    private static final int MAX_FILENAME_LENGTH = 255;
    private static final int MAX_MEDIA_URL_LENGTH = 500;
    private static final int MAX_CHECKSUM_LENGTH = 128;
    private static final List<String> SUPPORTED_IMAGE_TYPES = List.of(
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/webp"
    );

    private final LobbyRepository lobbyRepository;
    private final UserRepository userRepository;
    private final LobbyMembershipRepository lobbyMembershipRepository;
    private final ReceiptAttachmentRepository receiptAttachmentRepository;
    private final ImageUploadUrlService imageUploadUrlService;
    private final ChatService chatService;

    public ReceiptAttachmentService(
        LobbyRepository lobbyRepository,
        UserRepository userRepository,
        LobbyMembershipRepository lobbyMembershipRepository,
        ReceiptAttachmentRepository receiptAttachmentRepository,
        ImageUploadUrlService imageUploadUrlService,
        ChatService chatService
    ) {
        this.lobbyRepository = lobbyRepository;
        this.userRepository = userRepository;
        this.lobbyMembershipRepository = lobbyMembershipRepository;
        this.receiptAttachmentRepository = receiptAttachmentRepository;
        this.imageUploadUrlService = imageUploadUrlService;
        this.chatService = chatService;
    }

    @Transactional(readOnly = true)
    public ReceiptUploadUrlResponse issueUploadUrl(Long userId, Long lobbyId, ReceiptUploadUrlRequest request) {
        Lobby lobby = findLobby(lobbyId);
        requireHost(lobby, userId);
        requireReceiptEditableState(lobby);
        String contentType = requireSupportedImageType(request.contentType());
        requireValidFileSize(request.fileSizeBytes());

        ImageUploadUrl uploadUrl = imageUploadUrlService.issue("receipts/lobbies/" + lobbyId, contentType);
        return new ReceiptUploadUrlResponse(uploadUrl.uploadUrl(), uploadUrl.mediaUrl(), 300);
    }

    @Transactional
    public ReceiptResponse attach(Long userId, Long lobbyId, ReceiptAttachRequest request) {
        Lobby lobby = findLobby(lobbyId);
        User uploader = requireActiveUser(userId);
        requireHost(lobby, userId);
        requireReceiptEditableState(lobby);

        String receiptImageUrl = requireMediaUrl(request.receiptImageUrl());
        String contentType = requireSupportedImageType(request.contentType());
        String originalFilename = normalizeOptional(request.originalFilename(), MAX_FILENAME_LENGTH);
        Long fileSizeBytes = requireValidFileSize(request.fileSizeBytes());
        String checksum = normalizeOptional(request.checksum(), MAX_CHECKSUM_LENGTH);

        ReceiptAttachment existing = receiptAttachmentRepository
            .findByLobby_IdAndStatus(lobbyId, ReceiptAttachmentStatus.ACTIVE)
            .orElse(null);
        if (existing != null && existing.getReceiptImageUrl().equals(receiptImageUrl)) {
            return toResponse(existing);
        }
        if (existing != null) {
            existing.replace();
            receiptAttachmentRepository.saveAndFlush(existing);
        }

        ReceiptAttachment receipt = receiptAttachmentRepository.save(new ReceiptAttachment(
            lobby,
            uploader,
            receiptImageUrl,
            originalFilename,
            contentType,
            fileSizeBytes,
            checksum
        ));
        chatService.publishMediaMessage(
            lobbyId,
            userId,
            "최종 주문 영수증이 첨부되었습니다.",
            receiptImageUrl,
            "RECEIPT"
        );
        return toResponse(receipt);
    }

    @Transactional(readOnly = true)
    public ReceiptResponse get(Long userId, Long lobbyId) {
        Lobby lobby = findLobby(lobbyId);
        requireReceiptViewAccess(lobby, userId);
        ReceiptAttachment receipt = receiptAttachmentRepository
            .findByLobby_IdAndStatus(lobbyId, ReceiptAttachmentStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.RECEIPT_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
        return toResponse(receipt);
    }

    private Lobby findLobby(Long lobbyId) {
        return lobbyRepository.findById(lobbyId)
            .orElseThrow(() -> LobbyErrorCode.LOBBY_NOT_FOUND.exception(HttpStatus.NOT_FOUND));
    }

    private User requireActiveUser(Long userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> LobbyErrorCode.AUTH_REQUIRED.exception(HttpStatus.UNAUTHORIZED));
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN);
        }
        return user;
    }

    private void requireHost(Lobby lobby, Long userId) {
        requireActiveUser(userId);
        if (!lobby.getHost().getId().equals(userId)) {
            throw LobbyErrorCode.HOST_REQUIRED.exception(HttpStatus.FORBIDDEN);
        }
        lobbyMembershipRepository
            .findByLobby_IdAndUser_IdAndStatus(lobby.getId(), userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
    }

    private void requireReceiptViewAccess(Lobby lobby, Long userId) {
        if (lobby.getOrderStatus() == LobbyOrderStatus.CLOSED) {
            lobbyMembershipRepository.findByLobby_IdAndUser_Id(lobby.getId(), userId)
                .orElseThrow(() -> LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
            return;
        }
        lobbyMembershipRepository.findByLobby_IdAndUser_IdAndStatus(lobby.getId(), userId, LobbyMembershipStatus.ACTIVE)
            .orElseThrow(() -> LobbyErrorCode.FORBIDDEN_ACCESS.exception(HttpStatus.FORBIDDEN));
    }

    private void requireReceiptEditableState(Lobby lobby) {
        if (lobby.getOrderStatus() != LobbyOrderStatus.ORDER_PLACED
            && lobby.getOrderStatus() != LobbyOrderStatus.OUT_FOR_DELIVERY
            && lobby.getOrderStatus() != LobbyOrderStatus.DELIVERED) {
            throw LobbyErrorCode.RECEIPT_INVALID_LOBBY_STATUS.exception(HttpStatus.CONFLICT);
        }
    }

    private String requireSupportedImageType(String contentType) {
        if (contentType == null) {
            throw LobbyErrorCode.INVALID_FILE_TYPE.exception(HttpStatus.BAD_REQUEST);
        }
        String normalized = contentType.trim().toLowerCase(Locale.ROOT);
        if (!SUPPORTED_IMAGE_TYPES.contains(normalized)) {
            throw LobbyErrorCode.INVALID_FILE_TYPE.exception(HttpStatus.BAD_REQUEST);
        }
        return normalized;
    }

    private Long requireValidFileSize(Long fileSizeBytes) {
        if (fileSizeBytes == null) {
            return null;
        }
        if (fileSizeBytes <= 0 || fileSizeBytes > MAX_RECEIPT_FILE_SIZE_BYTES) {
            throw LobbyErrorCode.FILE_TOO_LARGE.exception(HttpStatus.BAD_REQUEST);
        }
        return fileSizeBytes;
    }

    private String requireMediaUrl(String mediaUrl) {
        String normalized = normalizeOptional(mediaUrl, MAX_MEDIA_URL_LENGTH);
        if (normalized == null || !(normalized.startsWith("https://") || normalized.startsWith("http://"))) {
            throw LobbyErrorCode.INVALID_MEDIA_URL.exception(HttpStatus.BAD_REQUEST);
        }
        return normalized;
    }

    private String normalizeOptional(String value, int maxLength) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            return null;
        }
        if (normalized.length() > maxLength) {
            throw LobbyErrorCode.INVALID_RECEIPT_METADATA.exception(HttpStatus.BAD_REQUEST);
        }
        return normalized;
    }

    private ReceiptResponse toResponse(ReceiptAttachment receipt) {
        return new ReceiptResponse(
            receipt.getLobby().getId(),
            receipt.getReceiptImageUrl(),
            receipt.getUploadedBy().getId(),
            receipt.getCreatedAt() == null ? null : receipt.getCreatedAt().toString()
        );
    }
}
