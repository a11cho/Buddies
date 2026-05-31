import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 이메일 링크로 받은 token과 새 비밀번호를 입력하는 화면입니다.
class PasswordResetConfirmScreen extends StatefulWidget {
  const PasswordResetConfirmScreen({super.key});

  @override
  State<PasswordResetConfirmScreen> createState() =>
      _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState
    extends State<PasswordResetConfirmScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _loadedInitialToken = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInitialToken) {
      return;
    }
    final token = ModalRoute.of(context)?.settings.arguments as String?;
    if (token != null) {
      _tokenController.text = token;
    }
    _loadedInitialToken = true;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New Password',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextInputField(
            controller: _tokenController,
            label: 'Reset token',
            prefixIcon: Icons.key_outlined,
          ),
          const SizedBox(height: 12),
          TextInputField(
            controller: _passwordController,
            label: 'New password',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 12),
          TextInputField(
            controller: _confirmController,
            label: 'Confirm new password',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Change password',
            icon: Icons.check_circle_outline,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_tokenController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.authService.confirmPasswordReset(
        PasswordResetConfirmRequest(
          token: _tokenController.text.trim(),
          newPassword: _passwordController.text,
          newPasswordConfirm: _confirmController.text,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Please log in.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
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
