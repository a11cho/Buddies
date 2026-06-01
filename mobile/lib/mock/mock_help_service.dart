import '../models/faq_item.dart';
import '../services/help_service.dart';
import 'mock_data_store.dart';

class MockHelpService implements HelpService {
  MockHelpService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<List<FaqItem>> getFaqs() async {
    return const [
      FaqItem(
        id: 1,
        category: 'OTP',
        question: 'OTP가 오지 않으면 어떻게 하나요?',
        answer: 'KAIST 이메일 주소를 확인한 뒤 OTP 재전송을 눌러 주세요.',
      ),
      FaqItem(
        id: 2,
        category: 'Lobby',
        question: '이미 Lobby에 들어가 있으면 새 Lobby를 만들 수 있나요?',
        answer: '아니요. 한 사용자는 동시에 하나의 active Lobby에만 속할 수 있습니다.',
      ),
      FaqItem(
        id: 3,
        category: 'Payment',
        question: '송금 확인은 누가 하나요?',
        answer: 'Host가 참가자의 송금을 확인하고 payment record를 PAID로 바꿉니다.',
      ),
    ];
  }

  @override
  Future<void> submitSupportTicket(
    SupportTicketRequest request,
  ) async {
    if (!SupportTicketCategory.values.contains(request.category)) {
      throw StateError('Invalid support category.');
    }
    if (request.title.trim().isEmpty || request.body.trim().isEmpty) {
      throw StateError('Support title and body are required.');
    }
    final lobbyId = request.lobbyId;
    if (lobbyId != null) {
      final lobby = _store.findLobby(lobbyId);
      final isMember = lobby.members.any(
        (member) => member.userId == _store.currentUser.id,
      );
      if (!isMember) {
        throw StateError('You can only attach a Lobby you participated in.');
      }
    }

    _store.nextSupportTicketId++;
  }
}
