import '../core/enums.dart';
import '../models/cart_item.dart';
import '../models/host_payment_info.dart';
import '../models/lobby.dart';
import '../models/lobby_member.dart';
import '../models/payment_record.dart';
import '../models/receipt_attachment.dart';
import '../services/lobby_service.dart';
import 'mock_data_store.dart';

class MockLobbyService implements LobbyService {
  MockLobbyService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<List<Lobby>> getLobbies({
    String? deliveryZone,
    String? restaurantName,
  }) async {
    return _store.lobbies.where((lobby) {
      final matchesDeliveryZone = deliveryZone == null ||
          lobby.deliveryZone.toLowerCase() == deliveryZone.toLowerCase();
      final matchesRestaurantName = restaurantName == null ||
          lobby.restaurantName
              .toLowerCase()
              .contains(restaurantName.toLowerCase());
      return _isSearchVisibleLobby(lobby) &&
          matchesDeliveryZone &&
          matchesRestaurantName;
    }).toList();
  }

  @override
  Future<Lobby?> getMyActiveLobby() async {
    for (final lobby in _store.lobbies) {
      if (_isCurrentUserInActiveLobby(lobby)) {
        return lobby;
      }
    }
    return null;
  }

  @override
  Future<List<Lobby>> getMyLobbies() async {
    return _store.lobbies.where((lobby) {
      return lobby.members.any(
        (member) => member.userId == _store.currentUser.id,
      );
    }).toList();
  }

  @override
  Future<Lobby> getLobbyDetail(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    if (!_shouldExposeHostPaymentInfo(lobby)) {
      return lobby;
    }

    final HostPaymentInfo? paymentInfo =
        _store.paymentInfoByUserId[lobby.hostUserId];
    if (paymentInfo == null || !paymentInfo.isComplete) {
      return lobby;
    }
    return lobby.copyWith(
      hostBankName: paymentInfo.bankName,
      hostAccountNumber: paymentInfo.accountNumber,
      hostAccountHolderName: paymentInfo.accountHolderName,
    );
  }

  @override
  Future<ReceiptAttachment?> getReceipt(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    final receiptImageUrl = lobby.receiptImageUrl;
    if (receiptImageUrl == null || receiptImageUrl.isEmpty) {
      return null;
    }
    return ReceiptAttachment(
      lobbyId: lobbyId,
      receiptImageUrl: receiptImageUrl,
      uploadedByUserId: lobby.hostUserId,
    );
  }

  @override
  Future<ReceiptAttachment> uploadReceiptImage(
    int lobbyId,
    ReceiptImageAttachment attachment,
  ) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the host can attach a receipt.');
    }
    if (!_canAttachReceipt(lobby)) {
      throw StateError('Receipt can be attached after order is placed.');
    }
    final receipt = ReceiptAttachment(
      lobbyId: lobbyId,
      receiptImageUrl: 'mock-receipt://${attachment.filename}',
      uploadedByUserId: _store.currentUser.id,
      uploadedAt: DateTime.now(),
    );
    _store.replaceLobby(
      lobby.copyWith(receiptImageUrl: receipt.receiptImageUrl),
    );
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'receipt.attached',
      content: '${_store.currentUser.name} attached a receipt.',
      targetUserId: _store.currentUser.id,
    );
    return receipt;
  }

  @override
  Future<Lobby> createLobby(CreateLobbyRequest request) async {
    if (_store.lobbies.any(_isCurrentUserInActiveLobby)) {
      throw StateError(
        'You cannot create a Lobby while you are in an active Lobby.',
      );
    }
    final paymentInfo = _store.paymentInfoByUserId[_store.currentUser.id];
    if (paymentInfo == null || !paymentInfo.isComplete) {
      throw StateError('Register payment info before creating a Lobby.');
    }

    final newLobby = Lobby(
      lobbyId: _store.nextLobbyId++,
      hostUserId: _store.currentUser.id,
      hostName: _store.currentUser.name,
      hostTrustScore: _store.currentUser.trustScore,
      restaurantName: request.restaurantName,
      deliveryZone: request.deliveryZone,
      minimumOrderAmount: request.minimumOrderAmount,
      currentTotalAmount: 0,
      remainingAmount: request.minimumOrderAmount,
      deliveryFee: request.deliveryFee,
      participantCount: 1,
      orderStatus: LobbyStatus.waiting,
      members: [
        LobbyMember(
          userId: _store.currentUser.id,
          name: _store.currentUser.name,
          roleInLobby: RoleInLobby.host,
          membershipStatus: MembershipStatus.active,
          joinedAt: DateTime.now(),
        ),
      ],
      cartItems: const [],
      paymentRecords: const [],
    );
    _store.lobbies.add(newLobby);
    _store.addSystemMessage(
      lobbyId: newLobby.lobbyId,
      eventType: 'lobby.created',
      content: '${_store.currentUser.name} created this Lobby.',
      targetUserId: _store.currentUser.id,
    );
    return newLobby;
  }

  @override
  Future<LobbyMember> joinLobby(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    if (!lobby.canJoin) {
      throw StateError('Only WAITING lobbies can be joined.');
    }

    final existingMember = lobby.members.where(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
    if (existingMember.isNotEmpty) {
      return existingMember.first;
    }

    if (_store.lobbies.any(_isCurrentUserInActiveLobby)) {
      throw StateError(
        'You cannot join another Lobby while you are in an active Lobby.',
      );
    }

    final newMember = LobbyMember(
      userId: _store.currentUser.id,
      name: _store.currentUser.name,
      roleInLobby: RoleInLobby.participant,
      membershipStatus: MembershipStatus.active,
      joinedAt: DateTime.now(),
    );
    final updatedMembers = [...lobby.members, newMember];
    _store.replaceLobby(
      lobby.copyWith(
        members: updatedMembers,
        participantCount:
            updatedMembers.where((member) => member.isActive).length,
      ),
    );
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.member_joined',
      content: '${_store.currentUser.name} joined the Lobby.',
      targetUserId: _store.currentUser.id,
    );
    return newMember;
  }

  bool _isCurrentUserInActiveLobby(Lobby lobby) {
    final isActiveStatus = lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
    if (!isActiveStatus) {
      return false;
    }
    return lobby.members.any(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
  }

  bool _isSearchVisibleLobby(Lobby lobby) {
    return lobby.orderStatus == LobbyStatus.waiting &&
        lobby.cartLockedAt == null;
  }

  bool _shouldExposeHostPaymentInfo(Lobby lobby) {
    final canExposeByStatus = lobby.orderStatus != LobbyStatus.waiting &&
        lobby.orderStatus != LobbyStatus.closed &&
        lobby.orderStatus != LobbyStatus.canceled;
    if (!canExposeByStatus) {
      return false;
    }

    return lobby.members.any(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
  }

  @override
  Future<void> leaveLobby(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.orderStatus != LobbyStatus.waiting) {
      throw StateError('Participants can only leave while WAITING.');
    }

    final currentMember = lobby.members.firstWhere(
      (member) => member.userId == _store.currentUser.id,
      orElse: () => throw StateError('You are not a Lobby member.'),
    );
    if (!currentMember.isActive) {
      throw StateError('You are not an active Lobby member.');
    }
    if (currentMember.isHost) {
      throw StateError('Host should cancel the Lobby or transfer host.');
    }

    final currentUserName = _store.currentUser.name;
    final updatedMembers = lobby.members.map((member) {
      if (member.userId != _store.currentUser.id) {
        return member;
      }
      return member.copyWith(
        membershipStatus: MembershipStatus.left,
        leftAt: DateTime.now(),
      );
    }).toList();
    final updatedItems = lobby.cartItems
        .where((item) => item.ownerUserId != _store.currentUser.id)
        .toList();
    final updatedTotal = _calculateCurrentTotal(updatedItems);
    _store.replaceLobby(
      lobby.copyWith(
        members: updatedMembers,
        cartItems: updatedItems,
        currentTotalAmount: updatedTotal,
        remainingAmount: _calculateRemaining(
          lobby.minimumOrderAmount,
          updatedTotal,
        ),
        participantCount:
            updatedMembers.where((member) => member.isActive).length,
      ),
    );
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.member_left',
      content: '$currentUserName left the Lobby.',
      targetUserId: _store.currentUser.id,
    );
  }

  @override
  Future<void> cancelLobby(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can cancel the Lobby.');
    }
    if (lobby.orderStatus != LobbyStatus.waiting) {
      throw StateError('Only WAITING lobbies can be canceled.');
    }

    final canceledAt = DateTime.now();
    final updatedMembers = lobby.members.map((member) {
      if (!member.isActive) {
        return member;
      }
      return member.copyWith(
        membershipStatus: MembershipStatus.left,
        leftAt: canceledAt,
      );
    }).toList();

    _store.replaceLobby(
      lobby.copyWith(
        orderStatus: LobbyStatus.canceled,
        members: updatedMembers,
        participantCount: 0,
      ),
    );
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.canceled',
      content: '${_store.currentUser.name} canceled the Lobby.',
      targetUserId: _store.currentUser.id,
    );
  }

  @override
  Future<Lobby> transferHost(int lobbyId, int targetUserId) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can transfer Host role.');
    }
    if (lobby.orderStatus != LobbyStatus.waiting) {
      throw StateError('Host can only be transferred while WAITING.');
    }
    if (targetUserId == _store.currentUser.id) {
      throw StateError('You are already the Host.');
    }

    final targetMember = lobby.members.firstWhere(
      (member) => member.userId == targetUserId,
      orElse: () => throw StateError('Lobby member not found: $targetUserId'),
    );
    if (!targetMember.isActive) {
      throw StateError('Host can only be transferred to active Participants.');
    }
    if (targetMember.isHost) {
      throw StateError('Target member is already the Host.');
    }

    final transferredAt = DateTime.now();
    final updatedMembers = lobby.members.map((member) {
      if (member.userId == _store.currentUser.id) {
        return member.copyWith(
          membershipStatus: MembershipStatus.removedByTransfer,
          leftAt: transferredAt,
        );
      }
      if (member.userId == targetUserId) {
        return member.copyWith(roleInLobby: RoleInLobby.host);
      }
      return member;
    }).toList();
    final updatedItems = lobby.cartItems
        .where((item) => item.ownerUserId != _store.currentUser.id)
        .toList();
    final updatedTotal = _calculateCurrentTotal(updatedItems);
    final updatedLobby = lobby.copyWith(
      hostUserId: targetMember.userId,
      hostName: targetMember.name,
      members: updatedMembers,
      cartItems: updatedItems,
      currentTotalAmount: updatedTotal,
      remainingAmount: _calculateRemaining(
        lobby.minimumOrderAmount,
        updatedTotal,
      ),
      paymentRecords: lobby.paymentRecords
          .where((record) => record.userId != _store.currentUser.id)
          .toList(),
      participantCount:
          updatedMembers.where((member) => member.isActive).length,
    );

    _store.replaceLobby(updatedLobby);
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.host_transferred',
      content: '${_store.currentUser.name} transferred Host to '
          '${targetMember.name}.',
      targetUserId: targetMember.userId,
    );
    return updatedLobby;
  }

  @override
  Future<Lobby> kickMember(int lobbyId, int userId) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can kick Participants.');
    }
    if (lobby.orderStatus != LobbyStatus.waiting &&
        lobby.orderStatus != LobbyStatus.locked) {
      throw StateError('Participants can only be kicked before order placed.');
    }
    if (userId == lobby.hostUserId) {
      throw StateError('The Host cannot be kicked.');
    }

    final targetMember = lobby.members.firstWhere(
      (member) => member.userId == userId,
      orElse: () => throw StateError('Lobby member not found: $userId'),
    );
    if (!targetMember.isActive) {
      throw StateError('Only active Participants can be kicked.');
    }
    if (targetMember.isHost) {
      throw StateError('Only Participants can be kicked.');
    }
    final targetName = targetMember.name;

    final kickedAt = DateTime.now();
    final updatedMembers = lobby.members.map((member) {
      if (member.userId != userId) {
        return member;
      }
      return member.copyWith(
        membershipStatus: MembershipStatus.kicked,
        leftAt: kickedAt,
      );
    }).toList();
    final updatedItems =
        lobby.cartItems.where((item) => item.ownerUserId != userId).toList();
    final updatedTotal = _calculateCurrentTotal(updatedItems);
    final activeMembers =
        updatedMembers.where((member) => member.isActive).toList();
    final updatedPaymentRecords = lobby.orderStatus == LobbyStatus.locked
        ? _rebuildPaymentRecords(
            lobby: lobby,
            activeMembers: activeMembers,
            activeItems: updatedItems,
          )
        : lobby.paymentRecords
            .where((record) => record.userId != userId)
            .toList();
    final updatedLobby = lobby.copyWith(
      members: updatedMembers,
      cartItems: updatedItems,
      currentTotalAmount: updatedTotal,
      remainingAmount: _calculateRemaining(
        lobby.minimumOrderAmount,
        updatedTotal,
      ),
      paymentRecords: updatedPaymentRecords,
      participantCount: activeMembers.length,
    );
    _store.replaceLobby(updatedLobby);
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.member_kicked',
      content: '$targetName was kicked from the Lobby.',
      targetUserId: userId,
    );
    return updatedLobby;
  }

  @override
  Future<Lobby> updateLobbyStatus(int lobbyId, String newStatus) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can update Lobby status.');
    }
    if (!_canTransition(lobby.orderStatus, newStatus)) {
      throw StateError('Invalid Lobby status transition.');
    }
    if (newStatus == LobbyStatus.orderPlaced && !lobby.allPaymentsPaid) {
      throw StateError('All payment records must be PAID before order placed.');
    }
    final previousStatus = lobby.orderStatus;
    final updatedLobby = lobby.copyWith(orderStatus: newStatus);
    _store.replaceLobby(updatedLobby);
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'lobby.status_updated',
      content: 'Lobby status changed from $previousStatus to $newStatus.',
    );
    return updatedLobby;
  }

  bool _canTransition(String currentStatus, String newStatus) {
    const allowedTransitions = {
      LobbyStatus.locked: LobbyStatus.orderPlaced,
      LobbyStatus.orderPlaced: LobbyStatus.outForDelivery,
      LobbyStatus.outForDelivery: LobbyStatus.delivered,
      LobbyStatus.delivered: LobbyStatus.closed,
    };

    return allowedTransitions[currentStatus] == newStatus;
  }

  bool _canAttachReceipt(Lobby lobby) {
    return lobby.orderStatus == LobbyStatus.orderPlaced ||
        lobby.orderStatus == LobbyStatus.outForDelivery ||
        lobby.orderStatus == LobbyStatus.delivered;
  }

  List<PaymentRecord> _rebuildPaymentRecords({
    required Lobby lobby,
    required List<LobbyMember> activeMembers,
    required List<CartItem> activeItems,
  }) {
    final memberCount = activeMembers.isEmpty ? 1 : activeMembers.length;
    final deliveryShare = lobby.deliveryFee ~/ memberCount;

    return activeMembers.map((member) {
      final previousRecord = _paymentRecordFor(lobby, member.userId);
      final itemTotal = activeItems
          .where((item) => item.ownerUserId == member.userId)
          .fold(0, (sum, item) => sum + item.subtotal);
      final isHost = member.userId == lobby.hostUserId;

      return PaymentRecord(
        paymentRecordId:
            previousRecord?.paymentRecordId ?? _store.nextPaymentRecordId++,
        lobbyId: lobby.lobbyId,
        userId: member.userId,
        amount: itemTotal + deliveryShare,
        status: isHost ? PaymentStatus.paid : PaymentStatus.unpaid,
        confirmedByHostId: isHost ? lobby.hostUserId : null,
        confirmedAt: isHost ? DateTime.now() : null,
      );
    }).toList();
  }

  PaymentRecord? _paymentRecordFor(Lobby lobby, int userId) {
    for (final record in lobby.paymentRecords) {
      if (record.userId == userId) {
        return record;
      }
    }
    return null;
  }

  int _calculateCurrentTotal(List<CartItem> items) {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }

  int _calculateRemaining(int minimumOrderAmount, int currentTotalAmount) {
    final remaining = minimumOrderAmount - currentTotalAmount;
    return remaining > 0 ? remaining : 0;
  }
}
