import '../core/api_client.dart';
import '../services/rating_service.dart';

class ApiRatingService implements RatingService {
  ApiRatingService({
    required ApiClient apiClient,
    this.ratingBasePath = '/ratings',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String ratingBasePath;

  @override
  Future<void> submitRating(RatingRequest request) async {
    await _apiClient.post(
      ratingBasePath,
      body: {
        'lobbyId': request.lobbyId,
        'targetUserId': request.targetUserId,
        'rating': request.rating,
        'feedback': request.feedback,
      },
    );
  }
}
