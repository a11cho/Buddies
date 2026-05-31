import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 비밀번호 재설정 링크 요청 화면입니다.
// 실제 API는 이메일 링크를 보내지만, mock에서는 확인용 token을 다음 화면에 넘깁니다.
class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  State<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends State<PasswordResetRequestScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reset Password',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextInputField(
            controller: _emailController,
            label: 'KAIST email ID',
            hintText: 'example',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            suffixText: '@kaist.ac.kr',
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send reset link',
            icon: Icons.mark_email_read_outlined,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final emailId = _emailController.text.trim();
    if (emailId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email ID is required.')),
      );
      return;
    }
    if (emailId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter only the part before @kaist.ac.kr.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await AppServices.authService.requestPasswordReset(
        '$emailId@kaist.ac.kr',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent.')),
      );
      await Navigator.pushNamed(
        context,
        AppRoutes.passwordResetConfirm,
        arguments: result.mockResetToken,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
