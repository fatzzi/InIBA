import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/core/api_client.dart';
import 'package:iniba/features/profile/profile_providers.dart';
import 'package:iniba/features/profile/profile_repository.dart';
import 'package:iniba/features/profile/profile_screen.dart';

const me = 1;

Future<FakeProfileRepository> pumpProfile(
  WidgetTester tester, {
  int? studentId,
  FakeProfileRepository? repo,
}) async {
  final fake = repo ?? FakeProfileRepository(latency: Duration.zero);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentStudentIdProvider.overrideWithValue(me),
        profileRepositoryProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(home: ProfileScreen(studentId: studentId)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('own profile shows name, pills, mood, bio, streak, tags and Edit', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Fatima K.'), findsOneWidget);
    for (final pill in ['2027', 'Business', 'Debating Society', '#nightowl', '#chai']) {
      expect(find.widgetWithText(Pill, pill), findsOneWidget, reason: pill);
    }
    expect(find.text('Mood: ☕ need coffee'), findsOneWidget);
    expect(find.text('spreadsheet enthusiast, tea over coffee.'), findsOneWidget);
    expect(find.text('7 day streak'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget); // app bar title for own profile
  });

  testWidgets('passing your own id still counts as your profile', (tester) async {
    await pumpProfile(tester, studentId: me);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets("another student's profile has no edit control and no email", (tester) async {
    await pumpProfile(tester, studentId: 2);

    expect(find.text('Sara A.'), findsNWidgets(2)); // app bar + header
    expect(find.text('Mood: 😵 midterms'), findsOneWidget);
    expect(find.text('12 day streak'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('Edit profile opens the edit screen', (tester) async {
    await pumpProfile(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('student with no posts shows an empty state', (tester) async {
    await pumpProfile(tester, studentId: 3);
    expect(find.text('Hamza K.'), findsNWidgets(2));
    expect(find.text('No posts yet'), findsOneWidget);
    expect(find.byKey(const Key('mood-pill')), findsNothing);
  });

  testWidgets('error state shows the message and Retry reloads', (tester) async {
    final repo = FakeProfileRepository(latency: Duration.zero, failWith: ApiException(500, 'Server is down'));
    await pumpProfile(tester, repo: repo);

    expect(find.text('Server is down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Fatima K.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('unknown student shows a 404 message', (tester) async {
    await pumpProfile(tester, studentId: 99);
    expect(find.text('Student not found'), findsOneWidget);
  });

  testWidgets('loading state shows a spinner', (tester) async {
    final repo = FakeProfileRepository(latency: const Duration(milliseconds: 100));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('grid shows thumbnails and loads the next pages on scroll', (tester) async {
    final repo = await pumpProfile(tester); // fake has 45 posts for student 1, 20 per page

    expect(find.byKey(const Key('post-1045')), findsOneWidget); // newest post first
    expect(repo.fetchPostsCalls, 0);

    await tester.scrollUntilVisible(find.byKey(const Key('post-1001')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post-1001')), findsOneWidget); // the oldest, on page 3
    expect(repo.fetchPostsCalls, 2);
  });

  testWidgets('a failed next page shows retry and keeps loaded posts', (tester) async {
    final repo = await pumpProfile(tester);
    repo.failWith = ApiException(503, 'Try again later.');

    await tester.scrollUntilVisible(find.textContaining('Tap to retry'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('post-1026')), findsOneWidget); // last post of page 1 still there
    expect(repo.fetchPostsCalls, 1); // no retry loop

    repo.failWith = null;
    await tester.tap(find.textContaining('Tap to retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap to retry'), findsNothing);
    expect(repo.fetchPostsCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('tapping a post shows the coming-soon message', (tester) async {
    await pumpProfile(tester);
    await tester.tap(find.byKey(const Key('post-1045')));
    await tester.pump();
    expect(find.text('Full post view is coming soon.'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the profile', (tester) async {
    final repo = await pumpProfile(tester);
    expect(repo.fetchProfileCalls, 1);
    await tester.fling(find.text('Fatima K.'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.fetchProfileCalls, 2);
    expect(find.text('Fatima K.'), findsOneWidget);
  });
}
