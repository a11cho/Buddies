import '../core/enums.dart';
import '../services/rating_service.dart';
import 'mock_data_store.dart';

class MockRatingService implements RatingService {
  MockRatingService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<RatingSubmission> submitRating(RatingRequest request) async {
    final lobby = _store.findLobby(request.lobbyId);
    if (lobby.orderStatus != LobbyStatus.closed) {
      throw StateError('Ratings are only available for CLOSED lobbies.');
    }
    if (request.rating < 1 || request.rating > 5) {
      throw StateError('Rating must be between 1 and 5.');
    }
    if (request.targetUserId == _store.currentUser.id) {
      throw StateError('You cannot rate yourself.');
    }

    final currentUserWasMember = lobby.members.any(
      (member) => member.userId == _store.currentUser.id,
    );
    final targetWasMember = lobby.members.any(
      (member) => member.userId == request.targetUserId,
    );
    if (!currentUserWasMember || !targetWasMember) {
      throw StateError('Both users must have been in the same closed Lobby.');
    }

    final key = _ratingKey(
      request.lobbyId,
      _store.currentUser.id,
      request.targetUserId,
    );
    if (_store.submittedRatingKeys.contains(key)) {
      throw StateError('You already rated this user for this Lobby.');
    }
    _store.submittedRatingKeys.add(key);

    return RatingSubmission(
      ratingId: _store.nextRatingId++,
      lobbyId: request.lobbyId,
      targetUserId: request.targetUserId,
      rating: request.rating,
    );
  }

  String _ratingKey(int lobbyId, int fromUserId, int targetUserId) {
    return '$lobbyId:$fromUserId:$targetUserId';
  }
}
