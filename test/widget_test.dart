// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:kosfinder_app/main.dart';

void main() {
  testWidgets('App loads LoginPage', (WidgetTester tester) async {
    await tester.pumpWidget(const KosFinderApp());

    // Verify that LoginPage is shown
    expect(find.text('Login KosFinder'), findsOneWidget);
  });
}