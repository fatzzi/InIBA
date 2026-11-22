import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iniba/features/auth/presentation/screens/login_screen.dart';
import 'package:iniba/features/auth/presentation/screens/signup_screen.dart';
import 'package:iniba/main.dart';

void main() {
  testWidgets('Welcome screen shows app name and auth buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: InibaApp()));
    await tester.pumpAndSettle();

    expect(find.text('InIBA'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up with IBA email'), findsOneWidget);
  });

  testWidgets('Log In button opens Login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: InibaApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Sign Up button opens SignUp screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: InibaApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign Up with IBA email'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
  });
}