import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/service_registry.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/auth_screen_shell.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 로그인 화면입니다.
// AuthService.login 성공 시 accessToken을 저장하고 Lobby 목록으로 이동합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Login',
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
                label: 'Login',
                icon: Icons.login,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    style: _compactLinkButtonStyle(),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final shouldClearFields = await Navigator.pushNamed(
                              context,
                              AppRoutes.signupRequest,
                            );
                            if (!mounted) {
                              return;
                            }
                            if (shouldClearFields == true) {
                              _emailController.clear();
                              _passwordController.clear();
                            }
                          },
                    child: const Text(
                      'Create account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    style: _compactLinkButtonStyle(),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.passwordResetRequest,
                            );
                          },
                    child: const Text(
                      'Forgot password?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _compactLinkButtonStyle() {
    return TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  Future<void> _submit() async {
    final emailId = _emailController.text.trim();
    final password = _passwordController.text;

    if (emailId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email ID and password are required.')),
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
      final session = await AppServices.authService.login(
        email: '$emailId@kaist.ac.kr',
        password: password,
      );
      await AppServices.tokenStorage.saveAccessToken(session.accessToken);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, AppRoutes.lobbyList);
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
