import 'package:flutter/material.dart';

// 앱에서 반복해서 쓰는 입력창입니다.
// controller는 화면 State가 들고 있고, 이 widget은 표시와 입력 옵션만 담당합니다.
class TextInputField extends StatelessWidget {
  const TextInputField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final int maxLines;
  final IconData? prefixIcon;
  final String? suffixText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
