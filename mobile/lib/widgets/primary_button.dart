import 'package:flutter/material.dart';

// 로그인, Lobby 생성, Cart Lock처럼 중요한 동작에 쓰는 공통 버튼입니다.
// onPressed가 null이면 Flutter가 자동으로 disabled 상태로 표시합니다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final colorScheme = Theme.of(context).colorScheme;
    final child = isLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final button = icon == null
        ? FilledButton(
            onPressed: effectiveOnPressed,
            child: child,
          )
        : FilledButton.icon(
            onPressed: effectiveOnPressed,
            icon: Icon(icon),
            label: child,
          );

    final decoratedButton = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: effectiveOnPressed == null
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: button,
    );

    if (!fullWidth) {
      return decoratedButton;
    }

    return SizedBox(
      width: double.infinity,
      child: decoratedButton,
    );
  }
}
