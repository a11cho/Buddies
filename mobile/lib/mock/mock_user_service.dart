import '../core/enums.dart';
import '../models/order_history_item.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import 'mock_data_store.dart';

class MockUserService implements UserService {
  MockUserService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<User> getMe() async => _store.currentUser;

  @override
  Future<User> updateMe(UpdateProfileRequest request) async {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('Name is required.');
    }

    final updatedUser = _store.currentUser.copyWith(
      name: name,
      profileImageUrl: request.profileImageUrl?.trim(),
      clearProfileImageUrl: request.profileImageUrl == null,
    );
    _store.currentUser = updatedUser;
    _syncCurrentUserNameToLobbies(name);
    return updatedUser;
  }

  @override
  Future<List<OrderHistoryItem>> getOrderHistory() async {
    final currentUserId = _store.currentUser.id;
    final historyLobbies = _store.lobbies.where((lobby) {
      final isHistoryStatus = lobby.orderStatus == LobbyStatus.closed ||
          lobby.orderStatus == LobbyStatus.canceled;
      final isMember = lobby.members.any(
        (member) => member.userId == currentUserId,
      );
      return isHistoryStatus && isMember;
    }).toList();

    historyLobbies.sort((left, right) => right.lobbyId.compareTo(left.lobbyId));
    return historyLobbies.map((lobby) {
      final participants = lobby.members
          .map(
            (member) => OrderHistoryParticipant(
              userId: member.userId,
              name: member.name,
            ),
          )
          .toList();
      final rateableParticipants = participants.where((participant) {
        return participant.userId != currentUserId &&
            !_store.submittedRatingKeys.contains(
              _ratingKey(lobby.lobbyId, currentUserId, participant.userId),
            );
      }).toList();
      final myAmount = lobby.paymentRecords
          .where((record) => record.userId == currentUserId)
          .fold(0, (sum, record) => sum + record.amount);
      final canRate = rateableParticipants.isNotEmpty;

      return OrderHistoryItem(
        lobbyId: lobby.lobbyId,
        currentUserId: currentUserId,
        restaurantName: lobby.restaurantName,
        deliveredAt: lobby.cartLockedAt,
        hostName: lobby.hostName ?? 'Host ${lobby.hostUserId}',
        participantCount: lobby.participantCount ?? lobby.members.length,
        totalAmount: lobby.currentTotalAmount,
        myAmount: myAmount,
        receiptImageUrl: null,
        canRate: canRate,
        participants: participants,
        rateableParticipants: rateableParticipants,
      );
    }).toList();
  }

  void _syncCurrentUserNameToLobbies(String name) {
    for (final lobby in List.of(_store.lobbies)) {
      final hasCurrentUser = lobby.members.any(
        (member) => member.userId == _store.currentUser.id,
      );
      if (!hasCurrentUser && lobby.hostUserId != _store.currentUser.id) {
        continue;
      }

      final updatedMembers = lobby.members.map((member) {
        if (member.userId != _store.currentUser.id) {
          return member;
        }
        return member.copyWith(name: name);
      }).toList();

      _store.replaceLobby(
        lobby.copyWith(
          hostName: lobby.hostUserId == _store.currentUser.id
              ? name
              : lobby.hostName,
          members: updatedMembers,
        ),
      );
    }
  }

  String _ratingKey(int lobbyId, int fromUserId, int targetUserId) {
    return '$lobbyId:$fromUserId:$targetUserId';
  }
}
