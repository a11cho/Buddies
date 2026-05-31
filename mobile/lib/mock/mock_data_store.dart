import '../core/enums.dart';
import '../models/chat_message.dart';
import '../models/host_payment_info.dart';
import '../models/lobby.dart';
import '../models/user.dart';
import 'mock_data.dart';

// 여러 mock service가 같은 앱 상태를 공유하도록 하는 in-memory 저장소입니다.
class MockDataStore {
  MockDataStore({
    User currentUser = mockCurrentUser,
    List<Lobby>? initialLobbies,
    Map<int, List<ChatMessage>>? initialMessagesByLobbyId,
    Map<int, HostPaymentInfo>? initialPaymentInfoByUserId,
  })  : currentUser = currentUser,
        lobbies = List<Lobby>.from(initialLobbies ?? createInitialMockLobbies()),
        messagesByLobbyId = (initialMessagesByLobbyId ??
                createInitialMockMessages())
            .map((key, value) => MapEntry(key, List<ChatMessage>.from(value))),
        paymentInfoByUserId =
            Map<int, HostPaymentInfo>.from(initialPaymentInfoByUserId ??
                createInitialMockPaymentInfoByUserId());

  User currentUser;
  final List<Lobby> lobbies;
  final Map<int, List<ChatMessage>> messagesByLobbyId;
  final Map<int, HostPaymentInfo> paymentInfoByUserId;
  final Map<String, List<DateTime>> chatSendTimestampsByLobbyUser = {};
  final Map<String, String> passwordResetTokensByEmail = {};
  final Set<String> submittedRatingKeys = {};

  int nextLobbyId = 100;
  int nextCartItemId = 1000;
  int nextPaymentRecordId = 2000;
  int nextMessageId = 3000;
  int nextReportId = 4000;
  int nextRatingId = 5000;
  int nextSupportTicketId = 6000;

  Lobby findLobby(int lobbyId) {
    return lobbies.firstWhere(
      (lobby) => lobby.lobbyId == lobbyId,
      orElse: () => throw StateError('Lobby not found: $lobbyId'),
    );
  }

  void replaceLobby(Lobby updatedLobby) {
    final index = lobbies.indexWhere(
      (lobby) => lobby.lobbyId == updatedLobby.lobbyId,
    );
    if (index == -1) {
      throw StateError('Lobby not found: ${updatedLobby.lobbyId}');
    }
    lobbies[index] = updatedLobby;
  }

  List<ChatMessage> findMessages(int lobbyId) {
    return messagesByLobbyId.putIfAbsent(lobbyId, () => []);
  }

  ChatMessage addSystemMessage({
    required int lobbyId,
    required String eventType,
    required String content,
    int? targetUserId,
  }) {
    final message = ChatMessage(
      id: nextMessageId++,
      lobbyId: lobbyId,
      senderUserId: null,
      messageType: ChatMessageType.system,
      content: content,
      eventType: eventType,
      targetUserId: targetUserId,
      createdAt: DateTime.now(),
    );
    findMessages(lobbyId).add(message);
    return message;
  }
}

final mockDataStore = MockDataStore();
