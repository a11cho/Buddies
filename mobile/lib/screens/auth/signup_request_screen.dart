import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/auth_screen_shell.dart';
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

  bool get _canRequestOtp {
    final emailId = _emailController.text.trim();
    final name = _nameController.text.trim();
    return emailId.isNotEmpty &&
        !emailId.contains('@') &&
        name.isNotEmpty &&
        _isPasswordValid;
  }

  bool get _isPasswordValid {
    final password = _passwordController.text;
    return _hasMinPasswordLength(password) &&
        _hasLetter(password) &&
        _hasNumber(password) &&
        _hasSpecialCharacter(password);
  }

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
      titleWidget: const AuthLogoTitle(),
      centerTitle: true,
      appBarBackgroundColor: authBackgroundColor,
      body: AuthScreenBody(
        children: [
          AuthCard(
            children: [
              TextInputField(
                controller: _emailController,
                label: 'KAIST email ID',
                hintText: 'example',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                suffixText: '@kaist.ac.kr',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextInputField(
                controller: _nameController,
                label: 'Name',
                prefixIcon: Icons.badge_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextInputField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: authBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
                child: _PasswordRequirementList(
                  password: _passwordController.text,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Request OTP',
                icon: Icons.mark_email_read_outlined,
                isLoading: _isSubmitting,
                onPressed: _canRequestOtp ? _submit : null,
              ),
              if (!_canRequestOtp) ...[
                const SizedBox(height: 8),
                Text(
                  '이메일 ID, 이름, 비밀번호 조건을 모두 만족해야 합니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
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

    if (emailId.isEmpty || request.name.isEmpty || request.password.isEmpty) {
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

    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호 조건을 모두 만족해야 합니다.')),
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
      // OTP를 보낸 뒤에는 이 화면으로 돌아와서 OTP를 다시 보낼 수 없게 교체 이동합니다.
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.signupVerify,
        arguments: request.email,
        result: true,
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

  bool _hasMinPasswordLength(String password) {
    return password.length >= 8;
  }

  bool _hasLetter(String password) {
    return RegExp(r'[A-Za-z]').hasMatch(password);
  }

  bool _hasNumber(String password) {
    return RegExp(r'[0-9]').hasMatch(password);
  }

  bool _hasSpecialCharacter(String password) {
    const allowedSpecialCharacters = r'''!@#$%^&*()_+-=[]{};':"\|,.<>/?`~''';
    return password.split('').any(allowedSpecialCharacters.contains);
  }
}

class _PasswordRequirementList extends StatelessWidget {
  const _PasswordRequirementList({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PasswordRequirementRow(
          isMet: password.length >= 8,
          label: '8자 이상',
        ),
        _PasswordRequirementRow(
          isMet: RegExp(r'[A-Za-z]').hasMatch(password),
          label: '영문 1개 이상',
        ),
        _PasswordRequirementRow(
          isMet: RegExp(r'[0-9]').hasMatch(password),
          label: '숫자 1개 이상',
        ),
        _PasswordRequirementRow(
          isMet: _hasSpecialCharacter(password),
          label: '특수문자 1개 이상',
        ),
      ],
    );
  }

  bool _hasSpecialCharacter(String password) {
    const allowedSpecialCharacters = r'''!@#$%^&*()_+-=[]{};':"\|,.<>/?`~''';
    return password.split('').any(allowedSpecialCharacters.contains);
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  const _PasswordRequirementRow({
    required this.isMet,
    required this.label,
  });

  final bool isMet;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = isMet
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
