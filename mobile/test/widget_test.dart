import 'package:flutter_test/flutter_test.dart';

import 'package:iniba/main.dart';

void main() {
  testWidgets('Welcome screen shows app name and auth buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const InibaApp());

    expect(find.text('InIBA'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up with IBA email'), findsOneWidget);
  });
}
