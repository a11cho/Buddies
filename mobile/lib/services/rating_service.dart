class RatingRequest {
  const RatingRequest({
    required this.lobbyId,
    required this.targetUserId,
    required this.rating,
    required this.feedback,
  });

  final int lobbyId;
  final int targetUserId;
  final int rating;
  final String feedback;
}

abstract class RatingService {
  Future<void> submitRating(RatingRequest request);
}
