import 'package:flutter/widgets.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_request_screen.dart';
import '../screens/auth/signup_verify_screen.dart';
import '../screens/lobby/create_lobby_screen.dart';
import '../screens/lobby/lobby_list_screen.dart';

// 화면 이동에 사용하는 route 이름을 한 곳에서 관리합니다.
// 문자열을 여러 파일에 직접 쓰면 오타가 나기 쉬워서 상수로 둡니다.
class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const signupRequest = '/signup/request';
  static const signupVerify = '/signup/verify';
  static const lobbyList = '/lobbies';
  static const createLobby = '/lobbies/create';
}

// MaterialApp이 사용할 route table입니다.
// 예: Navigator.pushNamed(context, AppRoutes.createLobby)를 호출하면
// CreateLobbyScreen이 화면에 올라옵니다.
Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signupRequest: (_) => const SignupRequestScreen(),
    AppRoutes.signupVerify: (_) => const SignupVerifyScreen(),
    AppRoutes.lobbyList: (_) => const LobbyListScreen(),
    AppRoutes.createLobby: (_) => const CreateLobbyScreen(),
  };
}
