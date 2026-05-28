import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 회원가입 요청 화면입니다.
// 성공하면 OTP 검증 화면으로 email을 넘깁니다.
class SignupRequestScreen extends StatefulWidget {
  const SignupRequestScreen({super.key});

  @override
  State<SignupRequestScreen> createState() => _SignupRequestScreenState();
}

class _SignupRequestScreenState extends State<SignupRequestScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sign Up',
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
          const SizedBox(height: 12),
          TextInputField(
            controller: _nameController,
            label: 'Name',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          TextInputField(
            controller: _passwordController,
            label: 'Password',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Request OTP',
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
    final request = SignupRequest(
      email: '$emailId@kaist.ac.kr',
      name: _nameController.text.trim(),
      password: _passwordController.text,
    );

    if (emailId.isEmpty ||
        request.name.isEmpty ||
        request.password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
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
      await AppServices.authService.requestSignup(request);
      if (!mounted) {
        return;
      }
      Navigator.pushNamed(
        context,
        AppRoutes.signupVerify,
        arguments: request.email,
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
