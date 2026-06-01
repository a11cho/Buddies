import '../core/enums.dart';
import '../models/lobby.dart';
import '../models/payment_record.dart';
import '../services/payment_service.dart';
import 'mock_data_store.dart';

class MockPaymentService implements PaymentService {
  MockPaymentService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<PaymentRecord> confirmPaymentRecord(
    int lobbyId,
    int paymentRecordId,
  ) async {
    final lobby = _store.findLobby(lobbyId);
    if (lobby.orderStatus != LobbyStatus.locked) {
      throw StateError('Payment records can only be confirmed in LOCKED state.');
    }
    if (lobby.hostUserId != _store.currentUser.id) {
      throw StateError('Only the Host can confirm payment records.');
    }

    final confirmedAt = DateTime.now();
    final targetRecord = lobby.paymentRecords.firstWhere(
      (record) => record.paymentRecordId == paymentRecordId,
      orElse: () => throw StateError('PaymentRecord not found: $paymentRecordId'),
    );
    if (targetRecord.isPaid) {
      throw StateError('PaymentRecord is already PAID.');
    }
    final updatedRecords = lobby.paymentRecords.map((record) {
      if (record.paymentRecordId != paymentRecordId) {
        return record;
      }
      return record.copyWith(
        status: PaymentStatus.paid,
        confirmedByHostId: lobby.hostUserId,
        confirmedAt: confirmedAt,
      );
    }).toList();

    final updatedRecord = updatedRecords.firstWhere(
      (record) => record.paymentRecordId == paymentRecordId,
    );
    _store.replaceLobby(lobby.copyWith(paymentRecords: updatedRecords));
    _store.addSystemMessage(
      lobbyId: lobbyId,
      eventType: 'payment.record_updated',
      content: 'Payment from ${_memberNameById(lobby, targetRecord.userId)} '
          'was confirmed.',
      targetUserId: targetRecord.userId,
    );

    return updatedRecord;
  }

  String _memberNameById(Lobby lobby, int userId) {
    for (final member in lobby.members) {
      if (member.userId == userId) {
        return member.name;
      }
    }
    return 'User $userId';
  }
}
