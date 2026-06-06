import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/enums.dart';
import '../models/cart_item.dart';
import '../models/json_parsing.dart';
import '../models/lobby.dart';
import '../models/lobby_member.dart';
import '../models/payment_record.dart';
import '../models/receipt_attachment.dart';
import '../models/user.dart';
import '../services/lobby_service.dart';

class ApiLobbyService implements LobbyService {
  ApiLobbyService({
    required ApiClient apiClient,
    this.lobbyBasePath = '/lobbies',
    this.userBasePath = '/users',
    this.authBasePath = '/auth',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String lobbyBasePath;
  final String userBasePath;
  final String authBasePath;

  @override
  Future<List<Lobby>> getLobbies({
    String? deliveryZone,
    String? restaurantName,
  }) async {
    final response = await _apiClient.get(
      lobbyBasePath,
      queryParameters: {
        'deliveryZone': _blankToNull(deliveryZone),
        'restaurantName': _blankToNull(restaurantName),
      },
    );
    return _objectList(
      response,
      message: 'Invalid lobby list response.',
    ).map(Lobby.fromJson).toList();
  }

  @override
  Future<Lobby?> getMyActiveLobby() async {
    final response = await _apiClient.get('$lobbyBasePath/me/active');
    if (response == null) {
      return null;
    }
    return Lobby.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid active lobby response.',
      ),
    );
  }

  @override
  Future<List<Lobby>> getMyLobbies() async {
    final currentUser = await _getCurrentUser();
    final response = await _apiClient.get('$lobbyBasePath/me');
    return _objectList(
      response,
      message: 'Invalid my lobbies response.',
    ).map((json) => _myLobbyFromJson(json, currentUser)).toList();
  }

  @override
  Future<Lobby> getLobbyDetail(int lobbyId) async {
    final base = await _getLobbyBaseOrFallback(lobbyId);
    final lobby = base.lobby;
    final members = await _getLobbyMembersOrFallback(
      lobbyId,
      lobby,
      canAssumeCurrentUserIsActiveMember:
          base.canAssumeCurrentUserIsActiveMember,
    );
    final cartItems = await _getOptionalCartItems(lobbyId);
    final paymentRecords = await _getOptionalPaymentRecords(lobbyId);

    return lobby.copyWith(
      members: members,
      cartItems: cartItems,
      paymentRecords: paymentRecords,
    );
  }

  @override
  Future<Lobby> createLobby(CreateLobbyRequest request) async {
    final response = await _apiClient.post(
      lobbyBasePath,
      body: request.toJson(),
    );
    final lobby = Lobby.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid create lobby response.',
      ),
    );
    return getLobbyDetail(lobby.lobbyId);
  }

  @override
  Future<LobbyMember> joinLobby(int lobbyId) async {
    final currentUser = await _getCurrentUser();
    final response = await _apiClient.post('$lobbyBasePath/$lobbyId/join');
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid join lobby response.',
    );
    return _memberFromMembershipJson(json, currentUser);
  }

  @override
  Future<void> leaveLobby(int lobbyId) async {
    await _apiClient.post('$lobbyBasePath/$lobbyId/leave');
  }

  @override
  Future<void> cancelLobby(int lobbyId) async {
    await _apiClient.delete('$lobbyBasePath/$lobbyId');
  }

  @override
  Future<Lobby> transferHost(int lobbyId, int targetUserId) async {
    await _apiClient.post(
      '$lobbyBasePath/$lobbyId/transfer-host',
      body: {
        'newHostUserId': targetUserId,
      },
    );
    return getLobbyDetail(lobbyId);
  }

  @override
  Future<Lobby> kickMember(int lobbyId, int userId) async {
    await _apiClient.post(
      '$lobbyBasePath/$lobbyId/kick',
      body: {
        'targetUserId': userId,
      },
    );
    return getLobbyDetail(lobbyId);
  }

  @override
  Future<Lobby> updateLobbyStatus(int lobbyId, String newStatus) async {
    await _apiClient.patch(
      '$lobbyBasePath/$lobbyId/status',
      body: {
        'newStatus': newStatus,
      },
    );
    return getLobbyDetail(lobbyId);
  }

  @override
  Future<ReceiptAttachment?> getReceipt(int lobbyId) async {
    try {
      final response = await _apiClient.get('$lobbyBasePath/$lobbyId/receipt');
      return ReceiptAttachment.fromJson(
        ApiResponseParser.requireObject(
          response,
          message: 'Invalid receipt response.',
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        return null;
      }
      rethrow;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<ReceiptAttachment> uploadReceiptImage(
    int lobbyId,
    ReceiptImageAttachment attachment,
  ) async {
    final uploadResponse = await _apiClient.post(
      '$lobbyBasePath/$lobbyId/receipt/upload-url',
      body: {
        'filename': attachment.filename,
        'contentType': attachment.contentType,
        'fileSizeBytes': attachment.bytes.length,
      },
    );
    final uploadJson = ApiResponseParser.requireObject(
      uploadResponse,
      message: 'Invalid receipt upload response.',
    );
    final uploadUrl = uploadJson['uploadUrl'] as String?;
    final mediaUrl = uploadJson['mediaUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw ApiException(
        message: 'Receipt upload response did not include uploadUrl.',
        responseBody: uploadResponse,
      );
    }
    if (mediaUrl == null || mediaUrl.isEmpty) {
      throw ApiException(
        message: 'Receipt upload response did not include mediaUrl.',
        responseBody: uploadResponse,
      );
    }

    await _uploadReceiptBytes(uploadUrl, attachment);
    final receiptResponse = await _apiClient.post(
      '$lobbyBasePath/$lobbyId/receipt',
      body: {
        'receiptImageUrl': _resolveHttpUrl(mediaUrl).toString(),
        'originalFilename': attachment.filename,
        'contentType': attachment.contentType,
        'fileSizeBytes': attachment.bytes.length,
      },
    );
    return ReceiptAttachment.fromJson(
      ApiResponseParser.requireObject(
        receiptResponse,
        message: 'Invalid receipt attach response.',
      ),
    );
  }

  Future<User> _getCurrentUser() async {
    try {
      return await _getUserFrom('$userBasePath/me');
    } on ApiException {
      return _getUserFrom('$authBasePath/me');
    } on FormatException {
      return _getUserFrom('$authBasePath/me');
    }
  }

  Future<User> _getUserFrom(String path) async {
    final response = await _apiClient.get(path);
    return User.fromJson(
      ApiResponseParser.requireObject(
        response,
        message: 'Invalid current user response.',
      ),
    );
  }

  Future<List<LobbyMember>> _getLobbyMembers(int lobbyId) async {
    final response = await _apiClient.get('$lobbyBasePath/$lobbyId/members');
    return _objectList(
      response,
      message: 'Invalid lobby members response.',
    ).map(LobbyMember.fromJson).toList();
  }

  Future<List<CartItem>> _getCartItems(int lobbyId) async {
    final response = await _apiClient.get('$lobbyBasePath/$lobbyId/cart-items');
    return _objectList(
      response,
      message: 'Invalid cart item list response.',
    ).map(CartItem.fromJson).toList();
  }

  Future<List<PaymentRecord>> _getPaymentRecords(int lobbyId) async {
    final response =
        await _apiClient.get('$lobbyBasePath/$lobbyId/payment-records');
    return _objectList(
      response,
      message: 'Invalid payment record list response.',
    ).map(PaymentRecord.fromJson).toList();
  }

  Future<void> _uploadReceiptBytes(
    String uploadUrl,
    ReceiptImageAttachment attachment,
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
          .timeout(_apiClient.config.effectiveUploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          responseBody: response.body,
          message: 'Receipt image upload failed.',
        );
      }
    } on TimeoutException {
      throw const ApiException(message: 'Receipt image upload timed out.');
    } on http.ClientException catch (error) {
      throw ApiException(
        message: kIsWeb
            ? 'Image upload was blocked by the browser. Storage CORS must allow PUT with Content-Type.'
            : 'Receipt image upload connection failed: ${error.message}',
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

  Future<_LobbyBaseResult> _getLobbyBaseOrFallback(int lobbyId) async {
    try {
      final lobbyResponse = await _apiClient.get('$lobbyBasePath/$lobbyId');
      final lobby = Lobby.fromJson(
        ApiResponseParser.requireObject(
          lobbyResponse,
          message: 'Invalid lobby detail response.',
        ),
      );
      return _LobbyBaseResult(
        lobby: await _applySummaryFields(lobby),
        canAssumeCurrentUserIsActiveMember: true,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 500) {
        final fallback = await _findFallbackLobbySummary(lobbyId);
        if (fallback != null) {
          return fallback;
        }
      }
      rethrow;
    }
  }

  Future<List<LobbyMember>> _getLobbyMembersOrFallback(
    int lobbyId,
    Lobby lobby, {
    required bool canAssumeCurrentUserIsActiveMember,
  }) async {
    final currentUser = await _getCurrentUser();
    try {
      final apiMembers = await _getLobbyMembers(lobbyId);
      return _withKnownTrustScores(
        _dedupeMembers([
          ...apiMembers,
          ..._summaryMembers(lobby),
        ]),
        lobby,
        currentUser,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 500) {
        final fallbackMembers = _fallbackMembers(
          lobby,
          currentUser,
          includeCurrentUser: canAssumeCurrentUserIsActiveMember,
        );
        if (fallbackMembers.isNotEmpty) {
          return fallbackMembers;
        }
        return const [];
      }
      rethrow;
    } on FormatException {
      final fallbackMembers = _fallbackMembers(
        lobby,
        currentUser,
        includeCurrentUser: canAssumeCurrentUserIsActiveMember,
      );
      if (fallbackMembers.isNotEmpty) {
        return fallbackMembers;
      }
      return const [];
    }
  }

  Future<List<CartItem>> _getOptionalCartItems(int lobbyId) async {
    try {
      return await _getCartItems(lobbyId);
    } on ApiException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 500) {
        return const [];
      }
      rethrow;
    } on FormatException {
      return const [];
    }
  }

  Future<List<PaymentRecord>> _getOptionalPaymentRecords(int lobbyId) async {
    try {
      return await _getPaymentRecords(lobbyId);
    } on ApiException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 500) {
        return const [];
      }
      rethrow;
    } on FormatException {
      return const [];
    }
  }

  Future<_LobbyBaseResult?> _findFallbackLobbySummary(int lobbyId) async {
    final activeLobby = await _findActiveLobbySummary(lobbyId);
    if (activeLobby != null) {
      return _LobbyBaseResult(
        lobby: activeLobby,
        canAssumeCurrentUserIsActiveMember: true,
      );
    }
    final myLobby = await _findMyLobbySummary(lobbyId);
    final availableLobby = await _findAvailableLobbySummary(lobbyId);
    if (myLobby != null) {
      final mergedLobby = availableLobby == null
          ? myLobby
          : _mergeMyLobbyWithAvailableSummary(myLobby, availableLobby);
      return _LobbyBaseResult(
        lobby: mergedLobby,
        canAssumeCurrentUserIsActiveMember:
            myLobby.members.any((member) => member.isActive),
      );
    }
    if (availableLobby != null) {
      return _LobbyBaseResult(
        lobby: availableLobby,
        canAssumeCurrentUserIsActiveMember: false,
      );
    }
    return null;
  }

  Lobby _mergeMyLobbyWithAvailableSummary(
    Lobby myLobby,
    Lobby availableLobby,
  ) {
    return availableLobby.copyWith(
      minimumOrderAmount: availableLobby.orderAmountsKnown
          ? availableLobby.minimumOrderAmount
          : myLobby.minimumOrderAmount,
      currentTotalAmount: availableLobby.orderAmountsKnown
          ? availableLobby.currentTotalAmount
          : myLobby.currentTotalAmount,
      remainingAmount: availableLobby.orderAmountsKnown
          ? availableLobby.remainingAmount
          : myLobby.remainingAmount,
      deliveryFee: availableLobby.deliveryFeeKnown
          ? availableLobby.deliveryFee
          : myLobby.deliveryFee,
      members: _dedupeMembers([
        ...availableLobby.members,
        ...myLobby.members,
      ]),
      participantCount:
          availableLobby.participantCount ?? myLobby.participantCount,
      lastReadMessageId:
          availableLobby.lastReadMessageId ?? myLobby.lastReadMessageId,
      unreadCount: availableLobby.unreadCount,
      orderAmountsKnown:
          availableLobby.orderAmountsKnown || myLobby.orderAmountsKnown,
      deliveryFeeKnown:
          availableLobby.deliveryFeeKnown || myLobby.deliveryFeeKnown,
      receiptImageUrl:
          availableLobby.receiptImageUrl ?? myLobby.receiptImageUrl,
    );
  }

  Future<Lobby> _applySummaryFields(Lobby lobby) async {
    if (lobby.hostTrustScore != null && lobby.hostName != null) {
      return lobby;
    }

    final summary = await _findActiveLobbySummary(lobby.lobbyId) ??
        await _findAvailableLobbySummary(lobby.lobbyId);
    if (summary == null) {
      return lobby;
    }

    return lobby.copyWith(
      hostName: lobby.hostName ?? summary.hostName,
      hostTrustScore: lobby.hostTrustScore ?? summary.hostTrustScore,
      participantCount: lobby.participantCount ?? summary.participantCount,
      members: lobby.members.isEmpty ? summary.members : lobby.members,
    );
  }

  Future<Lobby?> _findActiveLobbySummary(int lobbyId) async {
    try {
      final response = await _apiClient.get('$lobbyBasePath/me/active');
      if (response == null) {
        return null;
      }
      final lobby = Lobby.fromJson(
        ApiResponseParser.requireObject(
          response,
          message: 'Invalid active lobby response.',
        ),
      );
      return lobby.lobbyId == lobbyId ? _withSyntheticHostMember(lobby) : null;
    } on ApiException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<Lobby?> _findMyLobbySummary(int lobbyId) async {
    try {
      final currentUser = await _getCurrentUser();
      final response = await _apiClient.get('$lobbyBasePath/me');
      final matches = _objectList(
        response,
        message: 'Invalid my lobbies response.',
      )
          .where((json) => parseJsonInt(json['lobbyId'], 'lobbyId') == lobbyId)
          .map((json) => _myLobbyFromJson(json, currentUser))
          .toList();
      if (matches.isEmpty) {
        return null;
      }
      matches.sort((first, second) {
        final firstIsActive = first.members.any((member) => member.isActive);
        final secondIsActive = second.members.any((member) => member.isActive);
        if (firstIsActive != secondIsActive) {
          return firstIsActive ? -1 : 1;
        }
        return 0;
      });
      return matches.first;
    } on ApiException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<Lobby?> _findAvailableLobbySummary(int lobbyId) async {
    try {
      final response = await _apiClient.get(lobbyBasePath);
      for (final json in _objectList(
        response,
        message: 'Invalid lobby list response.',
      )) {
        if (parseJsonInt(json['lobbyId'], 'lobbyId') == lobbyId) {
          return _withSyntheticHostMember(Lobby.fromJson(json));
        }
      }
      return null;
    } on ApiException {
      return null;
    } on FormatException {
      return null;
    }
  }

  List<LobbyMember> _dedupeMembers(List<LobbyMember> members) {
    final byUserId = <int, LobbyMember>{};
    for (final member in members) {
      final existing = byUserId[member.userId];
      if (existing == null) {
        byUserId[member.userId] = member;
      } else if (_isPreferredMember(member, existing)) {
        byUserId[member.userId] = _mergeMemberData(member, existing);
      } else {
        byUserId[member.userId] = _mergeMemberData(existing, member);
      }
    }
    return byUserId.values.toList();
  }

  List<LobbyMember> _summaryMembers(Lobby lobby) {
    return _dedupeMembers([
      ...lobby.members,
      if (lobby.hostUserId > 0) _syntheticHostMember(lobby),
    ]);
  }

  List<LobbyMember> _fallbackMembers(
    Lobby lobby,
    User currentUser, {
    required bool includeCurrentUser,
  }) {
    return _withKnownTrustScores(
      _dedupeMembers([
        ..._summaryMembers(lobby),
        if (includeCurrentUser) _syntheticCurrentMember(lobby, currentUser),
      ]),
      lobby,
      currentUser,
    );
  }

  Lobby _withSyntheticHostMember(Lobby lobby) {
    if (lobby.hostUserId <= 0 ||
        lobby.members.any((member) => member.userId == lobby.hostUserId)) {
      return lobby;
    }
    return lobby.copyWith(
      members: [
        _syntheticHostMember(lobby),
        ...lobby.members,
      ],
    );
  }

  LobbyMember _mergeMemberData(
    LobbyMember preferred,
    LobbyMember fallback,
  ) {
    if (preferred.trustScore != null || fallback.trustScore == null) {
      return preferred;
    }
    return preferred.copyWith(trustScore: fallback.trustScore);
  }

  List<LobbyMember> _withKnownTrustScores(
    List<LobbyMember> members,
    Lobby lobby,
    User currentUser,
  ) {
    return members.map((member) {
      final trustScore = member.trustScore ??
          (member.userId == currentUser.id ? currentUser.trustScore : null) ??
          (member.userId == lobby.hostUserId ? lobby.hostTrustScore : null);
      if (trustScore == null) {
        return member;
      }
      return member.copyWith(trustScore: trustScore);
    }).toList();
  }

  bool _isPreferredMember(LobbyMember candidate, LobbyMember existing) {
    if (candidate.isActive != existing.isActive) {
      return candidate.isActive;
    }
    if (candidate.isHost != existing.isHost) {
      return candidate.isHost;
    }
    final candidateJoinedAt = candidate.joinedAt;
    final existingJoinedAt = existing.joinedAt;
    if (candidateJoinedAt != null && existingJoinedAt != null) {
      return candidateJoinedAt.isAfter(existingJoinedAt);
    }
    return candidateJoinedAt != null && existingJoinedAt == null;
  }

  LobbyMember _syntheticCurrentMember(Lobby lobby, User currentUser) {
    return LobbyMember(
      userId: currentUser.id,
      name: currentUser.name,
      roleInLobby: lobby.hostUserId == currentUser.id
          ? RoleInLobby.host
          : RoleInLobby.participant,
      membershipStatus: MembershipStatus.active,
      trustScore: currentUser.trustScore,
    );
  }

  LobbyMember _syntheticHostMember(Lobby lobby) {
    return LobbyMember(
      userId: lobby.hostUserId,
      name: lobby.hostName ?? 'User ${lobby.hostUserId}',
      roleInLobby: RoleInLobby.host,
      membershipStatus: MembershipStatus.active,
      trustScore: lobby.hostTrustScore,
    );
  }

  Lobby _myLobbyFromJson(Map<String, dynamic> json, User currentUser) {
    final roleInLobby =
        json['roleInLobby'] as String? ?? RoleInLobby.participant;
    final membershipStatus =
        json['membershipStatus'] as String? ?? MembershipStatus.active;
    final isActive = membershipStatus == MembershipStatus.active;
    final isHost = roleInLobby == RoleInLobby.host;
    final hasCurrentTotalAmount = _hasAnyJsonKey(
      json,
      ['currentTotalAmount', 'currentTotal', 'totalAmount'],
    );
    final hasMinimumOrderAmount = _hasAnyJsonKey(
      json,
      ['minimumOrderAmount', 'minOrderAmount'],
    );
    final hasDeliveryFee = _hasAnyJsonKey(
      json,
      ['deliveryFee', 'deliveryCharge', 'deliveryCost', 'delivery_fee'],
    );
    final currentTotalAmount = parseJsonInt(
      json['currentTotalAmount'] ??
          json['currentTotal'] ??
          json['totalAmount'] ??
          0,
      'currentTotalAmount',
    );
    final minimumOrderAmount = parseJsonInt(
      json['minimumOrderAmount'] ?? json['minOrderAmount'] ?? 0,
      'minimumOrderAmount',
    );
    final computedRemaining = minimumOrderAmount - currentTotalAmount;

    return Lobby(
      lobbyId: parseJsonInt(json['lobbyId'], 'lobbyId'),
      hostUserId: parseNullableJsonInt(json['hostUserId'], 'hostUserId') ??
          (isActive && isHost ? currentUser.id : 0),
      hostName: json['hostName'] as String?,
      hostTrustScore: json['hostTrustScore'] == null
          ? null
          : parseJsonDouble(json['hostTrustScore'], 'hostTrustScore'),
      hostBankName: json['hostBankName'] as String?,
      hostAccountNumber: json['hostAccountNumber'] as String?,
      hostAccountHolderName: json['hostAccountHolderName'] as String?,
      restaurantName: json['restaurantName'] as String? ?? '',
      deliveryZone: json['deliveryZone'] as String? ?? '',
      minimumOrderAmount: minimumOrderAmount,
      currentTotalAmount: currentTotalAmount,
      remainingAmount:
          parseNullableJsonInt(json['remainingAmount'], 'remainingAmount') ??
              (computedRemaining > 0 ? computedRemaining : 0),
      deliveryFee: parseJsonInt(
        json['deliveryFee'] ??
            json['deliveryCharge'] ??
            json['deliveryCost'] ??
            json['delivery_fee'] ??
            0,
        'deliveryFee',
      ),
      participantCount:
          parseNullableJsonInt(json['participantCount'], 'participantCount'),
      orderStatus: json['orderStatus'] as String? ?? LobbyStatus.waiting,
      cartLockedAt: parseNullableDateTime(json['cartLockedAt']),
      lastReadMessageId:
          parseNullableJsonInt(json['lastReadMessageId'], 'lastReadMessageId'),
      unreadCount: parseJsonInt(json['unreadCount'] ?? 0, 'unreadCount'),
      orderAmountsKnown: hasCurrentTotalAmount && hasMinimumOrderAmount,
      deliveryFeeKnown: hasDeliveryFee,
      receiptImageUrl: json['receiptImageUrl'] as String?,
      members: [
        LobbyMember(
          userId: currentUser.id,
          name: currentUser.name,
          roleInLobby: roleInLobby,
          membershipStatus: membershipStatus,
          joinedAt: parseNullableDateTime(json['joinedAt']),
          leftAt: parseNullableDateTime(json['leftAt']),
          trustScore: currentUser.trustScore,
        ),
      ],
      cartItems: const [],
      paymentRecords: const [],
    );
  }

  LobbyMember _memberFromMembershipJson(
    Map<String, dynamic> json,
    User currentUser,
  ) {
    return LobbyMember(
      userId: parseJsonInt(json['userId'], 'userId'),
      name: currentUser.name,
      roleInLobby: json['roleInLobby'] as String? ?? RoleInLobby.participant,
      membershipStatus:
          json['membershipStatus'] as String? ?? MembershipStatus.active,
      joinedAt: parseNullableDateTime(json['joinedAt']),
      leftAt: parseNullableDateTime(json['leftAt']),
      trustScore: currentUser.trustScore,
    );
  }

  List<Map<String, dynamic>> _objectList(
    Object? response, {
    required String message,
  }) {
    return ApiResponseParser.requireList(
      response,
      message: message,
    ).map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      throw ApiException(message: message, responseBody: response);
    }).toList();
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  bool _hasAnyJsonKey(Map<String, dynamic> json, Iterable<String> keys) {
    return keys.any(json.containsKey);
  }
}

class _LobbyBaseResult {
  const _LobbyBaseResult({
    required this.lobby,
    required this.canAssumeCurrentUserIsActiveMember,
  });

  final Lobby lobby;
  final bool canAssumeCurrentUserIsActiveMember;
}
