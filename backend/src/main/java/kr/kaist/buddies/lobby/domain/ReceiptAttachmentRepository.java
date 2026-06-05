package kr.kaist.buddies.lobby.domain;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReceiptAttachmentRepository extends JpaRepository<ReceiptAttachment, Long> {
    Optional<ReceiptAttachment> findByLobby_IdAndStatus(Long lobbyId, ReceiptAttachmentStatus status);
}
