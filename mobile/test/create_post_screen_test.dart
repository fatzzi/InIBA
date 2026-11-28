import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iniba/features/moment/moment_repository.dart';
import 'package:iniba/screens/create_post_screen.dart';

void main() {
  testWidgets('Post screen offers a photo and a text post', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [momentRepositoryProvider.overrideWithValue(FakeMomentRepository())],
        child: const MaterialApp(home: CreatePostScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Post'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Write a text post'), findsOneWidget);
    // No permission message until the student has actually been asked.
    expect(find.text('InIBA needs your camera'), findsNothing);
    // SCRUM-44: the IBA Moment card sits on top.
    expect(find.text('Your IBA Moment is open'), findsOneWidget);
  });
}
