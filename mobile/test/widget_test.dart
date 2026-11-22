import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iniba/main.dart';

void main() {
  testWidgets('Welcome screen shows app name and auth buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: InibaApp()));

    expect(find.text('InIBA'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up with IBA email'), findsOneWidget);
  });

  testWidgets('Log In opens the tabs; the + tab opens New Post; no way back to Welcome', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: InibaApp()));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    for (final tab in ['Feed', 'Search', 'Profile']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byKey(const Key('nav-post')));
    await tester.pumpAndSettle();
    expect(find.text('New Post'), findsOneWidget);
    await tester.tap(find.text('Write a text post'));
    await tester.pump();
    expect(find.text('Text posts are coming soon.'), findsOneWidget);
  });
}
