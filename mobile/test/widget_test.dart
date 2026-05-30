// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:buddies_mobile/app.dart';

void main() {
  // 앱이 최소 화면 요소를 렌더링하는지 확인하는 기본 widget test입니다.
  testWidgets('Buddies home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BuddiesApp());

    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('KAIST email ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
