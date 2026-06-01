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

abstract class HelpService {
  Future<List<FaqItem>> getFaqs();

  Future<void> submitSupportTicket(
    SupportTicketRequest request,
  );
}
