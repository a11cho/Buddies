class FaqItem {
  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final int id;
  final String category;
  final String question;
  final String answer;

  factory FaqItem.fromJson(Map<String, dynamic> json, {int fallbackId = 0}) {
    final key = json['key'] as String?;
    return FaqItem(
      id: json['id'] as int? ?? fallbackId,
      category: json['category'] as String? ?? _categoryFromKey(key),
      question: json['question'] as String? ?? _questionFromKey(key),
      answer: json['answer'] as String? ?? '',
    );
  }

  static String _categoryFromKey(String? key) {
    if (key == null) {
      return 'General';
    }
    if (key.contains('otp')) {
      return 'OTP';
    }
    if (key.contains('payment') || key.contains('link')) {
      return 'Payment';
    }
    if (key.contains('lobby')) {
      return 'Lobby';
    }
    if (key.contains('report')) {
      return 'Report';
    }
    return 'General';
  }

  static String _questionFromKey(String? key) {
    return switch (key) {
      'otp_expired' => 'OTP가 만료되면 어떻게 하나요?',
      'deep_link_failed' => '외부 결제 앱이 열리지 않으면 어떻게 하나요?',
      'lobby_full' => '참여할 수 없는 Lobby는 어떤 상태인가요?',
      'payment_delayed' => '결제 확인이 지연되면 어떻게 하나요?',
      'report_user' => '문제가 있는 사용자는 어떻게 신고하나요?',
      _ => '도움말',
    };
  }
}
