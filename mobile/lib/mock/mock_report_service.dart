import '../models/lobby.dart';
import '../services/report_service.dart';
import 'mock_data_store.dart';

class MockReportService implements ReportService {
  MockReportService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<void> submitReport(ReportRequest request) async {
    final lobby = _store.findLobby(request.lobbyId);
    _ensureCurrentUserCanReport(lobby);
    if (request.reportedUserId == _store.currentUser.id) {
      throw StateError('You cannot report yourself.');
    }
    final reportedUserInLobby = lobby.members.any(
      (member) => member.userId == request.reportedUserId,
    );
    if (!reportedUserInLobby) {
      throw StateError('Reported user is not a member of this Lobby.');
    }
    if (request.reason.trim().isEmpty) {
      throw StateError('Report reason is required.');
    }
    if (request.description.trim().isEmpty) {
      throw StateError('Report description is required.');
    }
    if (request.reportedMessageId != null) {
      final message = _store.findMessages(request.lobbyId).firstWhere(
        (message) => message.id == request.reportedMessageId,
        orElse: () => throw StateError(
          'Reported message not found: ${request.reportedMessageId}',
        ),
      );
      if (message.senderUserId != request.reportedUserId) {
        throw StateError('Reported message does not belong to that user.');
      }
    }

    _store.nextReportId++;
  }

  void _ensureCurrentUserCanReport(Lobby lobby) {
    final isMember = lobby.members.any(
      (member) => member.userId == _store.currentUser.id && member.isActive,
    );
    if (!isMember) {
      throw StateError('Only active Lobby members can submit reports.');
    }
  }
}
