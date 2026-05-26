import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/text_input_field.dart';

// 로그인 화면의 임시 뼈대입니다.
// 실제 이메일/비밀번호 입력과 AuthService 연결은 Auth Phase에서 구현합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Buddies',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          TextInputField(
            controller: _emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
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
            label: 'Continue',
            icon: Icons.login,
            onPressed: () {
              // 로그인 성공을 가정하고 Lobby 목록으로 이동하는 임시 동작입니다.
              // pushReplacementNamed는 현재 Login 화면을 뒤로가기 stack에서 제거합니다.
              Navigator.pushReplacementNamed(context, AppRoutes.lobbyList);
            },
          ),
        ],
      ),
    );
  }
}
