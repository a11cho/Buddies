import '../models/faq_item.dart';

class SupportTicketCategory {
  const SupportTicketCategory._();

  static const payment = 'PAYMENT';
  static const account = 'ACCOUNT';
  static const lobby = 'LOBBY';
  static const other = 'OTHER';

  static const values = [
    payment,
    account,
    lobby,
    other,
  ];
}

class SupportTicketRequest {
  const SupportTicketRequest({
    required this.category,
    required this.title,
    required this.body,
    this.lobbyId,
  });

  final String category;
  final String title;
  final String body;
  final int? lobbyId;
}

class SupportTicketSubmission {
  const SupportTicketSubmission({
    required this.ticketId,
    required this.status,
  });

  final int ticketId;
  final String status;
}

abstract class HelpService {
  Future<List<FaqItem>> getFaqs();

  Future<SupportTicketSubmission> submitSupportTicket(
    SupportTicketRequest request,
  );
}
