import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/features/moment/moment_repository.dart';
import 'package:iniba/features/profile/profile_providers.dart';
import 'package:iniba/features/profile/profile_repository.dart';
import 'package:iniba/screens/create_post_screen.dart';
import 'package:iniba/screens/home_shell.dart';

void main() {
  testWidgets('New Post keeps its state when switching tabs and back', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          momentRepositoryProvider.overrideWithValue(FakeMomentRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository(latency: Duration.zero)),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-post')));
    await tester.pumpAndSettle();
    final before = tester.state(find.byType(CreatePostScreen));

    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-post')));
    await tester.pumpAndSettle();

    // Same State object = the taken photo (held in that State) is still there.
    expect(tester.state(find.byType(CreatePostScreen)), same(before));
  });
}
