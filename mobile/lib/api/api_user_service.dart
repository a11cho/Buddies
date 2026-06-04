import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../models/host_payment_info.dart';
import '../models/order_history_item.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class ApiUserService implements UserService {
  ApiUserService({
    required ApiClient apiClient,
    this.userBasePath = '/users',
    this.lobbyBasePath = '/lobbies',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String userBasePath;
  final String lobbyBasePath;

  @override
  Future<User> getMe() async {
    final response = await _apiClient.get('$userBasePath/me');
    return User.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid profile response.',
      ),
    );
  }

  @override
  Future<User> updateMe(UpdateProfileRequest request) async {
    final response = await _apiClient.patch(
      '$userBasePath/me',
      body: request.toJson(),
    );
    return User.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid profile update response.',
      ),
    );
  }

  @override
  Future<String> uploadProfileImage(ProfileImageAttachment attachment) async {
    final response = await _apiClient.post(
      '$userBasePath/me/profile-image/upload-url',
      body: {
        'filename': attachment.filename,
        'contentType': attachment.contentType,
      },
    );
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid profile image upload response.',
    );
    final uploadUrl = json['uploadUrl'] as String?;
    final mediaUrl = json['mediaUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw ApiException(
        message: 'Profile image upload response did not include uploadUrl.',
        responseBody: response,
      );
    }
    if (mediaUrl == null || mediaUrl.isEmpty) {
      throw ApiException(
        message: 'Profile image upload response did not include mediaUrl.',
        responseBody: response,
      );
    }

    await _uploadImageBytes(uploadUrl, attachment);
    return _resolveHttpUrl(mediaUrl).toString();
  }

  @override
  Future<HostPaymentInfo?> getPaymentInfo() async {
    try {
      final response = await _apiClient.get('$userBasePath/me/payment-info');
      return HostPaymentInfo.fromJson(
        ApiResponseParser.requireObject(
          response,
          message: 'Invalid payment info response.',
        ),
      );
    } on ApiException catch (error) {
      // 현재 backend에 payment-info endpoint가 없으면 404가 옵니다.
      // 화면에서는 이것을 "등록된 계좌 없음" 상태로 다룹니다.
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<HostPaymentInfo> updatePaymentInfo(
    UpdatePaymentInfoRequest request,
  ) async {
    final response = await _apiClient.patch(
      '$userBasePath/me/payment-info',
      body: request.toJson(),
    );
    return HostPaymentInfo.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid payment info update response.',
      ),
    );
  }

  @override
  Future<List<OrderHistoryItem>> getOrderHistory() async {
    final currentUser = await getMe();
    final response = await _apiClient.get('$userBasePath/me/order-history');
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid order history response.',
    );
    final items = ApiResponseParser.requireList(
      json['items'],
      message: 'Invalid order history items response.',
    );

    final historyItems = items
        .map(
          (item) => OrderHistoryItem.fromJson(
            item as Map<String, dynamic>,
            currentUserId: currentUser.id,
          ),
        )
        .toList();

    return Future.wait(
      historyItems.map(_populateRateableParticipants),
    );
  }

  Future<OrderHistoryItem> _populateRateableParticipants(
    OrderHistoryItem item,
  ) async {
    if (!item.canRate || item.rateableParticipants.isNotEmpty) {
      return item;
    }

    try {
      final participants = await _getLobbyParticipants(
        lobbyId: item.lobbyId,
        currentUserId: item.currentUserId,
      );
      if (participants.isEmpty) {
        return item;
      }
      return item.copyWith(
        participants:
            item.participants.isEmpty ? participants : item.participants,
        rateableParticipants: participants,
      );
    } on ApiException {
      return item;
    }
  }

  Future<List<OrderHistoryParticipant>> _getLobbyParticipants({
    required int lobbyId,
    required int currentUserId,
  }) async {
    final response = await _apiClient.get('$lobbyBasePath/$lobbyId/members');
    final members = ApiResponseParser.requireList(
      response,
      message: 'Invalid lobby members response.',
    );

    return _dedupeParticipants(members
        .map((member) {
          final json = member as Map<String, dynamic>;
          return OrderHistoryParticipant.fromJson(json);
        })
        .where((participant) => participant.userId != currentUserId)
        .toList());
  }

  List<OrderHistoryParticipant> _dedupeParticipants(
    List<OrderHistoryParticipant> participants,
  ) {
    final byUserId = <int, OrderHistoryParticipant>{};
    for (final participant in participants) {
      byUserId.putIfAbsent(participant.userId, () => participant);
    }
    return byUserId.values.toList();
  }

  Future<void> _uploadImageBytes(
    String uploadUrl,
    ProfileImageAttachment attachment,
  ) async {
    try {
      final response = await http
          .put(
            _resolveHttpUrl(uploadUrl),
            headers: {
              'Content-Type': attachment.contentType,
            },
            body: attachment.bytes,
          )
          .timeout(_apiClient.config.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          responseBody: response.body,
          message: 'Profile image upload failed.',
        );
      }
    } on TimeoutException {
      throw const ApiException(message: 'Profile image upload timed out.');
    } on http.ClientException {
      throw const ApiException(
        message: 'Image upload was blocked by the browser. '
            'Storage CORS must allow PUT with Content-Type.',
      );
    }
  }

  Uri _resolveHttpUrl(String value) {
    final parsed = Uri.parse(value);
    if (parsed.hasScheme) {
      return parsed;
    }
    return _apiClient.buildUri(value);
  }
}
