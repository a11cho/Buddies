// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'web_socket_transport_base.dart';

Future<WebSocketTransport> connectWebSocketTransport(Uri uri) {
  final socket = html.WebSocket(uri.toString());
  final opened = Completer<WebSocketTransport>();
  late _WebWebSocketTransport transport;
  transport = _WebWebSocketTransport(socket);

  late StreamSubscription openSubscription;
  late StreamSubscription errorSubscription;
  openSubscription = socket.onOpen.listen((_) {
    if (!opened.isCompleted) {
      opened.complete(transport);
    }
    openSubscription.cancel();
    errorSubscription.cancel();
  });
  errorSubscription = socket.onError.listen((_) {
    if (!opened.isCompleted) {
      opened.completeError(StateError('WebSocket connection failed.'));
    }
    openSubscription.cancel();
    errorSubscription.cancel();
  });

  return opened.future;
}

class _WebWebSocketTransport implements WebSocketTransport {
  _WebWebSocketTransport(this._socket) {
    _messageSubscription = _socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String) {
        _controller.add(data);
      }
    });
    _closeSubscription = _socket.onClose.listen((_) {
      _controller.close();
    });
    _errorSubscription = _socket.onError.listen((_) {
      _controller.addError(StateError('WebSocket connection failed.'));
    });
  }

  final html.WebSocket _socket;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  late final StreamSubscription _messageSubscription;
  late final StreamSubscription _closeSubscription;
  late final StreamSubscription _errorSubscription;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String data) {
    _socket.send(data);
  }

  @override
  Future<void> close() async {
    await _messageSubscription.cancel();
    await _closeSubscription.cancel();
    await _errorSubscription.cancel();
    if (_socket.readyState == html.WebSocket.OPEN ||
        _socket.readyState == html.WebSocket.CONNECTING) {
      _socket.close();
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
