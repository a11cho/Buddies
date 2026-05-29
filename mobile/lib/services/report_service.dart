class ReportReason {
  const ReportReason._();

  static const abusiveLanguage = 'ABUSIVE_LANGUAGE';
  static const spam = 'SPAM';
  static const inappropriateContent = 'INAPPROPRIATE_CONTENT';
  static const other = 'OTHER';

  static const values = [
    abusiveLanguage,
    spam,
    inappropriateContent,
    other,
  ];
}

class ReportRequest {
  const ReportRequest({
    required this.lobbyId,
    required this.reportedUserId,
    required this.reason,
    required this.description,
    this.reportedMessageId,
  });

  final int lobbyId;
  final int reportedUserId;
  final int? reportedMessageId;
  final String reason;
  final String description;

  Map<String, dynamic> toJson() {
    return {
      'lobbyId': lobbyId,
      'reportedUserId': reportedUserId,
      'reportedMessageId': reportedMessageId,
      'reason': reason,
      'description': description,
    };
  }
}

class ReportSubmission {
  const ReportSubmission({
    required this.reportId,
    required this.createdAt,
    required this.status,
  });

  final int reportId;
  final DateTime createdAt;
  final String status;
}

abstract class ReportService {
  Future<ReportSubmission> submitReport(ReportRequest request);
}
