import 'dart:async';
import 'dart:io';

import 'web_socket_transport_base.dart';

Future<WebSocketTransport> connectWebSocketTransport(Uri uri) async {
  final socket = await WebSocket.connect(uri.toString());
  return _IoWebSocketTransport(socket);
}

class _IoWebSocketTransport implements WebSocketTransport {
  _IoWebSocketTransport(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages => _socket.where((message) {
        return message is String;
      }).cast<String>();

  @override
  void send(String data) {
    _socket.add(data);
  }

  @override
  Future<void> close() {
    return _socket.close();
  }
}
