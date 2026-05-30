import 'package:flutter/material.dart';

// 제목과 값을 세로로 보여주는 작은 재사용 카드입니다.
// 여러 화면에서 상태 요약을 보여줄 때 사용할 수 있습니다.
class StatusCard extends StatelessWidget {
  const StatusCard({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
