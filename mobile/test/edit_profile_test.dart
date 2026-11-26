import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/core/api_client.dart';
import 'package:iniba/features/profile/photo_crop.dart';
import 'package:iniba/features/profile/profile_providers.dart';
import 'package:iniba/features/profile/profile_repository.dart';
import 'package:iniba/features/profile/profile_screen.dart';

// A real 1x1 PNG so Image.memory can decode it in tests.
final pngPixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<FakeProfileRepository> openEditor(
  WidgetTester tester, {
  FakeProfileRepository? repo,
  Uint8List? cropped,
}) async {
  final fake = repo ?? FakeProfileRepository(latency: Duration.zero);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentStudentIdProvider.overrideWithValue(1),
        profileRepositoryProvider.overrideWithValue(fake),
        photoPickerProvider.overrideWithValue(() async => Uint8List.fromList([1, 2, 3])),
        photoCropperProvider.overrideWithValue((_, _) async => cropped),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Edit profile'));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> chooseMood(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('mood-chip')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(label).last);
  await tester.pump();
  await tester.tap(find.text('Set mood'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edit screen starts with the current bio, mood and societies', (tester) async {
    await openEditor(tester);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'spreadsheet enthusiast, tea over coffee.'), findsOneWidget);
    expect(find.text('☕ need coffee'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Debating Society'), findsOneWidget);
  });

  testWidgets('saving updates the profile at once and sends the edit', (tester) async {
    // Slow server: the profile must change before the save finishes.
    final repo = await openEditor(tester, repo: FakeProfileRepository(latency: const Duration(seconds: 2)));
    // Initial fetch used the latency too; openEditor settled it.

    await tester.enterText(find.byKey(const Key('bio-field')), 'library regular');
    await chooseMood(tester, 'studying');
    await tester.tap(find.byTooltip('Remove Debating Society'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-society')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IEEE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump(); // pop starts
    await tester.pump(const Duration(seconds: 1)); // route animation done, server (2 s) still busy

    expect(find.text('library regular'), findsOneWidget);
    expect(find.text('Mood: 📚 studying'), findsOneWidget);
    final details = tester.widget<Text>(find.byKey(const Key('profile-details'))).data!;
    expect(details, contains('IEEE'));
    expect(details, isNot(contains('Debating Society')));
    expect(find.byKey(const Key('saving-indicator')), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const Key('saving-indicator')), findsNothing);
    expect(find.text('Profile saved.'), findsOneWidget);
    expect(find.text('library regular'), findsOneWidget);

    final edit = repo.edits.single;
    expect(edit.bio, 'library regular');
    expect(edit.moodSticker, 'studying');
    expect(edit.societies, ['IEEE']);
    expect(edit.photoJpeg, isNull);
  });

  testWidgets('a failed save rolls back and explains why', (tester) async {
    final repo = await openEditor(tester);
    repo.failWith = ApiException(400, 'Unknown society: IEEE');

    await tester.enterText(find.byKey(const Key('bio-field')), 'this will not stick');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('this will not stick'), findsNothing);
    expect(find.text('spreadsheet enthusiast, tea over coffee.'), findsOneWidget);
    expect(find.textContaining("Couldn't save: Unknown society: IEEE"), findsOneWidget);
    expect(find.byKey(const Key('saving-indicator')), findsNothing);
  });

  testWidgets('clearing the mood removes the mood pill', (tester) async {
    final repo = await openEditor(tester);
    await tester.tap(find.byKey(const Key('mood-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear mood'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a mood'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mood-pill')), findsNothing);
    expect(repo.edits.single.moodSticker, isNull);
  });

  testWidgets('a new photo shows at once and is uploaded', (tester) async {
    final repo = await openEditor(tester, cropped: pngPixel);
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-local')), findsOneWidget); // preview in the editor

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-local')), findsOneWidget); // on the profile
    expect(repo.edits.single.photoJpeg, pngPixel);
  });

  testWidgets('cancelling the crop keeps the old photo', (tester) async {
    final repo = await openEditor(tester, cropped: null);
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('avatar-local')), findsNothing);
    await tester.tap(find.text('Save')); // nothing changed: just closes
    await tester.pumpAndSettle();
    expect(repo.edits, isEmpty);
  });

  testWidgets('Cancel with changes asks before discarding', (tester) async {
    final repo = await openEditor(tester);
    await tester.enterText(find.byKey(const Key('bio-field')), 'half-typed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Change photo'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Change photo'), findsNothing);
    expect(find.text('spreadsheet enthusiast, tea over coffee.'), findsOneWidget);
    expect(repo.edits, isEmpty);
  });

  testWidgets('bio stops at 150 characters', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('bio-field')), 'x' * 200);
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('bio-field')));
    expect(field.controller!.text.length, 150);
  });

  testWidgets("other students' profiles still have no Edit button", (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentStudentIdProvider.overrideWithValue(1),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository(latency: Duration.zero)),
      ],
      child: const MaterialApp(home: ProfileScreen(studentId: 2)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
  });
}
