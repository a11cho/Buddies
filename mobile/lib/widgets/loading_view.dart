import 'package:flutter/material.dart';

// API 호출이나 mock service 작업을 기다리는 동안 보여줄 공통 로딩 화면입니다.
class LoadingView extends StatelessWidget {
  const LoadingView({
    this.message,
    super.key,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
