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

class RatingSubmission {
  const RatingSubmission({
    required this.ratingId,
    required this.lobbyId,
    required this.targetUserId,
    required this.rating,
  });

  final int ratingId;
  final int lobbyId;
  final int targetUserId;
  final int rating;
}

abstract class RatingService {
  Future<RatingSubmission> submitRating(RatingRequest request);
}
