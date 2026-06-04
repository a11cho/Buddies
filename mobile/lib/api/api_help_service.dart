import '../core/api_client.dart';
import '../models/faq_item.dart';
import '../services/help_service.dart';

class ApiHelpService implements HelpService {
  ApiHelpService({
    required ApiClient apiClient,
    this.helpBasePath = '/help',
    this.supportBasePath = '/support',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String helpBasePath;
  final String supportBasePath;

  @override
  Future<List<FaqItem>> getFaqs() async {
    final response = await _apiClient.get('$helpBasePath/faqs');
    final items = ApiResponseParser.requireList(
      response,
      message: 'Invalid FAQ response.',
    );

    return [
      for (var index = 0; index < items.length; index += 1)
        FaqItem.fromJson(
          items[index] as Map<String, dynamic>,
          fallbackId: index + 1,
        ),
    ];
  }

  @override
  Future<void> submitSupportTicket(SupportTicketRequest request) async {
    await _apiClient.post(
      '$supportBasePath/tickets',
      body: {
        'category': request.category,
        'title': request.title,
        'body': request.body,
        'lobbyId': request.lobbyId,
      },
    );
  }
}
