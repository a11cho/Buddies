import '../core/enums.dart';
import '../models/lobby.dart';
import '../models/lobby_member.dart';
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
      return matchesDeliveryZone && matchesRestaurantName;
    }).toList();
  }

  @override
  Future<Lobby> getLobbyDetail(int lobbyId) async {
    return _store.findLobby(lobbyId);
  }

  @override
  Future<Lobby> createLobby(CreateLobbyRequest request) async {
    if (_store.lobbies.any(_isCurrentUserInActiveLobby)) {
      throw StateError(
        'You cannot create a Lobby while you are in an active Lobby.',
      );
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

  @override
  Future<void> leaveLobby(int lobbyId) async {
    final lobby = _store.findLobby(lobbyId);
    final updatedMembers = lobby.members.map((member) {
      if (member.userId != _store.currentUser.id) {
        return member;
      }
      return member.copyWith(
        membershipStatus: MembershipStatus.left,
        leftAt: DateTime.now(),
      );
    }).toList();
    _store.replaceLobby(
      lobby.copyWith(
        members: updatedMembers,
        participantCount:
            updatedMembers.where((member) => member.isActive).length,
      ),
    );
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
    final updatedLobby = lobby.copyWith(orderStatus: newStatus);
    _store.replaceLobby(updatedLobby);
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
}
