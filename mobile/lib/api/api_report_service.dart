import '../core/api_client.dart';
import '../services/report_service.dart';

class ApiReportService implements ReportService {
  ApiReportService({
    required ApiClient apiClient,
    this.reportBasePath = '/reports',
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final String reportBasePath;

  @override
  Future<void> submitReport(ReportRequest request) async {
    await _apiClient.post(
      reportBasePath,
      body: request.toJson(),
    );
  }
}
