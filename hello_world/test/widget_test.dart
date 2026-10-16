import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hello_world/screens/home_screen.dart';

void main() {
  testWidgets('Home screen shows its title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('Home'), findsOneWidget);
  });
}
