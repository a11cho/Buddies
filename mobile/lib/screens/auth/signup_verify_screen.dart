import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 회원가입 OTP 검증 화면입니다.
class SignupVerifyScreen extends StatefulWidget {
  const SignupVerifyScreen({super.key});

  @override
  State<SignupVerifyScreen> createState() => _SignupVerifyScreenState();
}

class _SignupVerifyScreenState extends State<SignupVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return AppScaffold(
      title: 'Verify OTP',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            email,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextInputField(
            controller: _otpController,
            label: 'OTP',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.password_outlined,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Verify',
            icon: Icons.verified_outlined,
            isLoading: _isSubmitting,
            onPressed: () => _submit(email),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmitting || _isResending
                ? null
                : () => _resendOtp(email),
            icon: _isResending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Resend OTP'),
          ),
        ],
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _submit(String email) async {
    if (email.isEmpty || _otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP is required.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.authService.verifySignup(
        SignupVerifyRequest(
          email: email,
          otp: _otpController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      _goToLogin();
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

  Future<void> _resendOtp(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email is missing.')),
      );
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await AppServices.authService.resendSignupOtp(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent.')),
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
          _isResending = false;
        });
      }
    }
  }
}
