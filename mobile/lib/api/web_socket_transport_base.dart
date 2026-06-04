abstract class WebSocketTransport {
  Stream<String> get messages;

  void send(String data);

  Future<void> close();
}
