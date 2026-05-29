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
}
