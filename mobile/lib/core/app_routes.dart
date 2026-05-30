import 'package:flutter/widgets.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/password_reset_confirm_screen.dart';
import '../screens/auth/password_reset_request_screen.dart';
import '../screens/auth/signup_request_screen.dart';
import '../screens/auth/signup_verify_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/help/support_ticket_screen.dart';
import '../screens/lobby/create_lobby_screen.dart';
import '../screens/lobby/lobby_detail_screen.dart';
import '../screens/lobby/lobby_list_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/order_history_screen.dart';
import '../screens/profile/payment_settings_screen.dart';
import '../screens/profile/profile_screen.dart';

// 화면 이동에 사용하는 route 이름을 한 곳에서 관리합니다.
// 문자열을 여러 파일에 직접 쓰면 오타가 나기 쉬워서 상수로 둡니다.
class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const signupRequest = '/signup/request';
  static const signupVerify = '/signup/verify';
  static const passwordResetRequest = '/password-reset/request';
  static const passwordResetConfirm = '/password-reset/confirm';
  static const lobbyList = '/lobbies';
  static const createLobby = '/lobbies/create';
  static const lobbyDetail = '/lobbies/detail';
  static const chat = '/lobbies/chat';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const paymentSettings = '/profile/payment-settings';
  static const orderHistory = '/profile/order-history';
  static const help = '/help';
  static const supportTicket = '/support/tickets';
}

// MaterialApp이 사용할 route table입니다.
// 예: Navigator.pushNamed(context, AppRoutes.createLobby)를 호출하면
// CreateLobbyScreen이 화면에 올라옵니다.
Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.signupRequest: (_) => const SignupRequestScreen(),
    AppRoutes.signupVerify: (_) => const SignupVerifyScreen(),
    AppRoutes.passwordResetRequest: (_) => const PasswordResetRequestScreen(),
    AppRoutes.passwordResetConfirm: (_) => const PasswordResetConfirmScreen(),
    AppRoutes.lobbyList: (_) => const LobbyListScreen(),
    AppRoutes.createLobby: (_) => const CreateLobbyScreen(),
    AppRoutes.lobbyDetail: (_) => const LobbyDetailScreen(),
    AppRoutes.chat: (_) => const ChatScreen(),
    AppRoutes.profile: (_) => const ProfileScreen(),
    AppRoutes.editProfile: (_) => const EditProfileScreen(),
    AppRoutes.paymentSettings: (_) => const PaymentSettingsScreen(),
    AppRoutes.orderHistory: (_) => const OrderHistoryScreen(),
    AppRoutes.help: (_) => const HelpScreen(),
    AppRoutes.supportTicket: (_) => const SupportTicketScreen(),
  };
}
