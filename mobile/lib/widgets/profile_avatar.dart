import 'package:flutter/material.dart';

// Profile image URL이 있으면 이미지를 보여주고, 없으면 이름 첫 글자로 대체합니다.
// mock://profile/... 값은 mock mode에서 사진 업로드 결과를 간단히 표현합니다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.profileImageUrl,
    this.radius = 28,
  });

  final String name;
  final String? profileImageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profileImageUrl;
    final ImageProvider? backgroundImage = imageUrl != null &&
            (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))
        ? NetworkImage(imageUrl)
        : null;
    final isNetworkImage = backgroundImage != null;
    final mockColor = _mockProfileColor(imageUrl);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: mockColor ?? Theme.of(context).colorScheme.primary,
      backgroundImage: backgroundImage,
      child: isNetworkImage
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Color? _mockProfileColor(String? value) {
    return switch (value) {
      'mock://profile/blue' => const Color(0xFF2563EB),
      'mock://profile/green' => const Color(0xFF059669),
      'mock://profile/rose' => const Color(0xFFE11D48),
      'mock://profile/yellow' => const Color(0xFFCA8A04),
      'mock://profile/uploaded' => const Color(0xFF0F766E),
      _ => null,
    };
  }
}
