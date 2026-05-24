import 'package:flutter_test/flutter_test.dart';

import 'package:buddies_mobile/main.dart';

void main() {
  testWidgets('renders the lobby browser shell', (WidgetTester tester) async {
    await tester.pumpWidget(const BuddiesApp());

    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Delivery Zone'), findsOneWidget);
    expect(find.text('Create Lobby'), findsOneWidget);
  });
}
