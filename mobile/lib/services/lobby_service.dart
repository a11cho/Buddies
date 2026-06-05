import 'dart:typed_data';

import '../models/lobby.dart';
import '../models/lobby_member.dart';
import '../models/receipt_attachment.dart';

class ReceiptImageAttachment {
  const ReceiptImageAttachment({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final Uint8List bytes;
}

class CreateLobbyRequest {
  const CreateLobbyRequest({
    required this.restaurantName,
    required this.deliveryZone,
    required this.minimumOrderAmount,
    required this.deliveryFee,
  });

  final String restaurantName;
  final String deliveryZone;
  final int minimumOrderAmount;
  final int deliveryFee;

  Map<String, dynamic> toJson() {
    return {
      'restaurantName': restaurantName,
      'deliveryZone': deliveryZone,
      'minimumOrderAmount': minimumOrderAmount,
      'deliveryFee': deliveryFee,
    };
  }
}

abstract class LobbyService {
  Future<List<Lobby>> getLobbies({
    String? deliveryZone,
    String? restaurantName,
  });

  Future<Lobby?> getMyActiveLobby();

  Future<List<Lobby>> getMyLobbies();

  Future<Lobby> getLobbyDetail(int lobbyId);

  Future<Lobby> createLobby(CreateLobbyRequest request);

  Future<LobbyMember> joinLobby(int lobbyId);

  Future<void> leaveLobby(int lobbyId);

  Future<void> cancelLobby(int lobbyId);

  Future<Lobby> transferHost(int lobbyId, int targetUserId);

  Future<Lobby> kickMember(int lobbyId, int userId);

  Future<Lobby> updateLobbyStatus(int lobbyId, String newStatus);

  Future<ReceiptAttachment?> getReceipt(int lobbyId);

  Future<ReceiptAttachment> uploadReceiptImage(
    int lobbyId,
    ReceiptImageAttachment attachment,
  );
}
