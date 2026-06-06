import 'package:flutter/material.dart';

import 'core/app_notifications.dart';
import 'core/app_routes.dart';

// 앱 전체의 공통 설정을 담당하는 최상위 Widget입니다.
// MaterialApp 안에 theme, 첫 화면, route 목록을 모아둡니다.
class BuddiesApp extends StatelessWidget {
  const BuddiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buddies',
      navigatorObservers: [appRouteTracker],
      // 앱 전체에서 공통으로 사용할 기본 Material theme입니다.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0054FF)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: Color(0xFF111111),
            fontFamily: 'Jalnan2',
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // 앱을 처음 켰을 때 보여줄 화면입니다.
      initialRoute: AppRoutes.login,
      // 문자열 route 이름과 실제 화면 Widget을 연결합니다.
      routes: buildAppRoutes(),
      builder: (context, child) {
        return AppNotificationHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
