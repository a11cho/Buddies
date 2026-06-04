import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/enums.dart';
import '../models/chat_history_response.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'web_socket_transport.dart';

class ApiChatService implements ChatService {
  ApiChatService({
    required ApiClient apiClient,
    this.lobbyBasePath = '/lobbies',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String lobbyBasePath;
  final Map<int, _StompChatSession> _sessions = {};
  final Map<int, StreamController<ChatMessage>> _messageControllers = {};

  @override
  Future<ChatConnectionInfo> getConnectionInfo(int lobbyId) async {
    final response =
        await _apiClient.get('$lobbyBasePath/$lobbyId/chat/connection');
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid chat connection response.',
    );
    return ChatConnectionInfo.fromServerUrl(
      lobbyId: lobbyId,
      serverUrl: _resolveWebSocketUrl(json['serverUrl'] as String? ?? '/ws'),
    );
  }

  @override
  Stream<ChatMessage> watchMessages(int lobbyId) {
    final controller = _messageControllers.putIfAbsent(
      lobbyId,
      () => StreamController<ChatMessage>.broadcast(),
    );
    unawaited(() async {
      try {
        await _ensureSession(lobbyId);
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }());
    return controller.stream;
  }

  @override
  Future<ChatHistoryResponse> getMessages(
    int lobbyId, {
    int limit = ChatValidation.defaultHistoryLimit,
    int? cursor,
  }) async {
    final response = await _apiClient.get(
      '$lobbyBasePath/$lobbyId/chat/messages',
      queryParameters: {
        'limit': limit,
        'cursor': cursor,
      },
    );
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid chat history response.',
    );
    final messages = ChatHistoryResponse.fromJson(json).messages;
    final hasMore = messages.length >= limit;
    return ChatHistoryResponse(
      lastReadMessageId: ChatHistoryResponse.fromJson(json).lastReadMessageId,
      messages: messages,
      hasMore: hasMore,
      nextCursor: hasMore && messages.isNotEmpty ? messages.first.id : null,
    );
  }

  @override
  Future<void> sendMessage(int lobbyId, String content) async {
    final session = await _ensureSession(lobbyId);
    await session.send(
      destination: ChatConnectionInfo.fromServerUrl(
        lobbyId: lobbyId,
        serverUrl: '',
      ).sendDestination,
      body: {
        'messageType': ChatMessageType.user,
        'content': content.trim(),
      },
    );
  }

  @override
  Future<void> sendMediaMessage(int lobbyId, String mediaUrl) async {
    final session = await _ensureSession(lobbyId);
    await session.send(
      destination: ChatConnectionInfo.fromServerUrl(
        lobbyId: lobbyId,
        serverUrl: '',
      ).sendDestination,
      body: {
        'messageType': ChatMessageType.media,
        'mediaUrl': mediaUrl.trim(),
      },
    );
  }

  @override
  Future<void> sendImageMessage(
    int lobbyId,
    ChatImageAttachment attachment,
  ) async {
    final response = await _apiClient.post(
      '$lobbyBasePath/$lobbyId/chat/upload-url',
      body: {
        'filename': attachment.filename,
        'contentType': attachment.contentType,
      },
    );
    final json = ApiResponseParser.requireObject(
      response,
      message: 'Invalid chat image upload response.',
    );
    final uploadUrl = json['uploadUrl'] as String?;
    final mediaUrl = json['mediaUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw ApiException(
        message: 'Image upload response did not include uploadUrl.',
        responseBody: response,
      );
    }
    if (mediaUrl == null || mediaUrl.isEmpty) {
      throw ApiException(
        message: 'Image upload response did not include mediaUrl.',
        responseBody: response,
      );
    }

    await _uploadImageBytes(uploadUrl, attachment);
    await sendMediaMessage(lobbyId, _resolveHttpUrl(mediaUrl).toString());
  }

  @override
  Future<void> markAsRead(int lobbyId, int messageId) async {
    await _apiClient.patch(
      '$lobbyBasePath/$lobbyId/chat/read-state',
      body: {
        'lastReadMessageId': messageId,
      },
    );
  }

  Future<void> _uploadImageBytes(
    String uploadUrl,
    ChatImageAttachment attachment,
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
          message: 'Image upload failed.',
        );
      }
    } on TimeoutException {
      throw const ApiException(message: 'Image upload timed out.');
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

  @override
  Future<void> disconnect(int lobbyId) async {
    final session = _sessions.remove(lobbyId);
    await session?.close();
  }

  Future<_StompChatSession> _ensureSession(int lobbyId) async {
    final existing = _sessions[lobbyId];
    if (existing != null && !existing.isClosed) {
      return existing;
    }

    final connectionInfo = await getConnectionInfo(lobbyId);
    final accessToken = await _apiClient.tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(message: 'Login is required for chat.');
    }

    final session = await _StompChatSession.connect(
      connectionInfo: connectionInfo,
      accessToken: accessToken,
    );
    _sessions[lobbyId] = session;
    session.messages.listen(
      (message) {
        _messageControllers[lobbyId]?.add(message);
      },
      onError: (Object error, StackTrace stackTrace) {
        _messageControllers[lobbyId]?.addError(error, stackTrace);
      },
      onDone: () {
        _sessions.remove(lobbyId);
      },
    );
    return session;
  }

  String _resolveWebSocketUrl(String serverUrl) {
    final parsed = Uri.tryParse(serverUrl);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }

    final baseUri = Uri.parse(_apiClient.config.baseUrl);
    final normalizedPath =
        serverUrl.startsWith('/') ? serverUrl : '/$serverUrl';
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri
        .replace(
          scheme: scheme,
          path: normalizedPath,
          query: null,
          fragment: null,
        )
        .toString();
  }
}

class _StompChatSession {
  _StompChatSession._({
    required WebSocketTransport socket,
    required ChatConnectionInfo connectionInfo,
  })  : _socket = socket,
        _connectionInfo = connectionInfo;

  final WebSocketTransport _socket;
  final ChatConnectionInfo _connectionInfo;
  final StreamController<ChatMessage> _messages =
      StreamController<ChatMessage>.broadcast();
  final Completer<void> _connected = Completer<void>();
  StreamSubscription<String>? _socketSubscription;
  Timer? _heartbeatTimer;
  bool _isClosed = false;

  Stream<ChatMessage> get messages => _messages.stream;

  bool get isClosed => _isClosed;

  static Future<_StompChatSession> connect({
    required ChatConnectionInfo connectionInfo,
    required String accessToken,
  }) async {
    final socket = await connectWebSocketTransport(
      Uri.parse(connectionInfo.serverUrl),
    );
    final session = _StompChatSession._(
      socket: socket,
      connectionInfo: connectionInfo,
    );
    session._start(accessToken);
    await session._connected.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw const ApiException(message: 'Chat connection timed out.');
      },
    );
    session._subscribe();
    return session;
  }

  Future<void> send({
    required String destination,
    required Map<String, Object?> body,
  }) async {
    await _connected.future;
    _sendFrame(
      'SEND',
      headers: {
        'destination': destination,
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _heartbeatTimer?.cancel();
    try {
      _sendFrame('DISCONNECT');
    } catch (_) {
      // Socket may already be closed.
    }
    await _socketSubscription?.cancel();
    await _socket.close();
    await _messages.close();
  }

  void _start(String accessToken) {
    _socketSubscription = _socket.messages.listen(
      _handleRawMessage,
      onError: (Object error, StackTrace stackTrace) {
        if (!_connected.isCompleted) {
          _connected.completeError(error, stackTrace);
        }
        _messages.addError(error, stackTrace);
      },
      onDone: () {
        _isClosed = true;
        if (!_connected.isCompleted) {
          _connected.completeError(
            const ApiException(message: 'Chat connection closed.'),
          );
        }
        _messages.close();
      },
    );
    _sendFrame(
      'CONNECT',
      headers: {
        'accept-version': '1.2',
        'heart-beat': '10000,10000',
        'host': Uri.parse(_connectionInfo.serverUrl).host,
        'Authorization': 'Bearer $accessToken',
      },
    );
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isClosed) {
        _socket.send('\n');
      }
    });
  }

  void _subscribe() {
    _sendFrame(
      'SUBSCRIBE',
      headers: {
        'id': 'chat-${_connectionInfo.subscribeDestination}',
        'destination': _connectionInfo.subscribeDestination,
        'ack': 'auto',
      },
    );
    _sendFrame(
      'SUBSCRIBE',
      headers: {
        'id': 'chat-errors',
        'destination': _connectionInfo.errorDestination,
        'ack': 'auto',
      },
    );
  }

  void _handleRawMessage(String rawMessage) {
    for (final frame in _StompFrame.parseFrames(rawMessage)) {
      switch (frame.command) {
        case 'CONNECTED':
          if (!_connected.isCompleted) {
            _connected.complete();
          }
        case 'MESSAGE':
          _handleMessageFrame(frame);
        case 'ERROR':
          _messages.addError(
            ApiException(
              message: frame.body.isEmpty ? 'Chat error.' : frame.body,
            ),
          );
      }
    }
  }

  void _handleMessageFrame(_StompFrame frame) {
    final destination = frame.headers['destination'] ?? '';
    final decoded = jsonDecode(frame.body);
    if (destination.contains('chat-errors')) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error'] as String? ?? 'Chat error.'
          : 'Chat error.';
      _messages.addError(ApiException(message: message));
      return;
    }

    if (decoded is Map<String, dynamic>) {
      _messages.add(ChatMessage.fromJson(decoded));
    }
  }

  void _sendFrame(
    String command, {
    Map<String, String> headers = const {},
    String? body,
  }) {
    final buffer = StringBuffer(command)..write('\n');
    for (final entry in headers.entries) {
      buffer
        ..write(entry.key)
        ..write(':')
        ..write(entry.value)
        ..write('\n');
    }
    buffer.write('\n');
    if (body != null) {
      buffer.write(body);
    }
    buffer.write('\u0000');
    _socket.send(buffer.toString());
  }
}

class _StompFrame {
  const _StompFrame({
    required this.command,
    required this.headers,
    required this.body,
  });

  final String command;
  final Map<String, String> headers;
  final String body;

  static List<_StompFrame> parseFrames(String rawMessage) {
    final frames = <_StompFrame>[];
    for (final rawFrame in rawMessage.split('\u0000')) {
      final normalized =
          rawFrame.replaceAll('\r\n', '\n').replaceFirst(RegExp(r'^\n+'), '');
      if (normalized.trim().isEmpty) {
        continue;
      }

      final separatorIndex = normalized.indexOf('\n\n');
      if (separatorIndex < 0) {
        continue;
      }
      final headerBlock = normalized.substring(0, separatorIndex);
      final body = normalized.substring(separatorIndex + 2);
      final lines = headerBlock.split('\n');
      if (lines.isEmpty) {
        continue;
      }

      final headers = <String, String>{};
      for (final line in lines.skip(1)) {
        final separator = line.indexOf(':');
        if (separator <= 0) {
          continue;
        }
        headers[line.substring(0, separator).trim()] =
            line.substring(separator + 1).trim();
      }

      frames.add(
        _StompFrame(
          command: lines.first.trim(),
          headers: headers,
          body: body,
        ),
      );
    }
    return frames;
  }
}
