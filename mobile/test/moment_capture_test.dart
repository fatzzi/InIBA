import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iniba/camera/camera_permission.dart';
import 'package:iniba/core/api_client.dart';
import 'package:iniba/features/moment/moment_capture_screen.dart';
import 'package:iniba/features/moment/moment_card.dart';
import 'package:iniba/features/moment/moment_repository.dart';

// 1x1 transparent PNG, so the previews have something real to show.
final _png = Uint8List.fromList(const [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

XFile photo(String name) => XFile.fromData(_png, name: name, path: name);

/// Records which camera was asked for and returns photos in order.
class FakeCamera {
  FakeCamera([List<XFile?>? shots]) : _shots = shots;

  final List<XFile?>? _shots;
  final List<CameraDevice> asked = [];

  Future<XFile?> call(CameraDevice camera) async {
    asked.add(camera);
    final shots = _shots;
    if (shots != null) return shots.removeAt(0);
    return photo('${camera.name}-${asked.length}.png');
  }
}

class Clock {
  DateTime value = DateTime(2026, 11, 26, 14);
  DateTime call() => value;
  void advance(int seconds) => value = value.add(Duration(seconds: seconds));
}

/// Pushes the capture screen from a host page so the popped result can be checked.
Future<List<MomentPhotos?>> pumpCapture(
  WidgetTester tester, {
  required FakeCamera camera,
  required Clock clock,
  int seconds = 120,
  CameraAccess access = CameraAccess.granted,
}) async {
  final results = <MomentPhotos?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(
              await Navigator.of(context).push<MomentPhotos>(
                MaterialPageRoute(
                  builder: (_) => MomentCaptureScreen(
                    secondsRemaining: seconds,
                    takePhoto: camera.call,
                    requestAccess: () async => access,
                    now: clock.call,
                  ),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

String countdown(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('moment-countdown'))).data!;

void main() {
  group('MomentCaptureScreen', () {
    testWidgets('counts down from the time left', (tester) async {
      final clock = Clock();
      await pumpCapture(tester, camera: FakeCamera(), clock: clock, seconds: 120);

      expect(countdown(tester), '2:00');
      expect(find.text('Take front photo'), findsOneWidget);

      clock.advance(5);
      await tester.pump(const Duration(seconds: 1));
      expect(countdown(tester), '1:55');

      clock.advance(50);
      await tester.pump(const Duration(seconds: 1));
      expect(countdown(tester), '1:05');
    });

    testWidgets('takes front then back, previews both and returns them', (tester) async {
      final camera = FakeCamera();
      final results = await pumpCapture(tester, camera: camera, clock: Clock());

      await tester.tap(find.text('Take front photo'));
      await tester.pumpAndSettle();

      expect(camera.asked, [CameraDevice.front, CameraDevice.rear]);
      expect(find.byKey(const Key('moment-front')), findsOneWidget);
      expect(find.byKey(const Key('moment-back')), findsOneWidget);
      expect(find.text('Retake front'), findsOneWidget);
      expect(find.text('Retake back'), findsOneWidget);

      await tester.tap(find.text('Use these photos'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.single!.front.name, 'front-1.png');
      expect(results.single!.back.name, 'rear-2.png');
    });

    testWidgets('retake replaces only the chosen photo', (tester) async {
      final camera = FakeCamera();
      final results = await pumpCapture(tester, camera: camera, clock: Clock());
      await tester.tap(find.text('Take front photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retake back'));
      await tester.pumpAndSettle();
      expect(camera.asked.last, CameraDevice.rear);

      await tester.tap(find.text('Retake front'));
      await tester.pumpAndSettle();
      expect(camera.asked, [CameraDevice.front, CameraDevice.rear, CameraDevice.rear, CameraDevice.front]);

      await tester.tap(find.text('Use these photos'));
      await tester.pumpAndSettle();
      expect(results.single!.front.name, 'front-4.png');
      expect(results.single!.back.name, 'rear-3.png');
    });

    testWidgets('closing the camera on the back photo keeps the front one', (tester) async {
      final camera = FakeCamera([photo('me.png'), null, photo('view.png')]);
      await pumpCapture(tester, camera: camera, clock: Clock());

      await tester.tap(find.text('Take front photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take back photo'), findsOneWidget);
      expect(find.text('Use these photos'), findsNothing);

      await tester.tap(find.text('Take back photo'));
      await tester.pumpAndSettle();
      expect(camera.asked, [CameraDevice.front, CameraDevice.rear, CameraDevice.rear]);
      expect(find.text('Use these photos'), findsOneWidget);
    });

    testWidgets("shows Time's up when the window closes and blocks capture", (tester) async {
      final clock = Clock();
      final camera = FakeCamera();
      await pumpCapture(tester, camera: camera, clock: clock, seconds: 10);

      clock.advance(10);
      await tester.pump(const Duration(seconds: 1));

      expect(countdown(tester), '0:00');
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.text('Take front photo'), findsNothing);
      expect(camera.asked, isEmpty);

      await tester.tap(find.text('Back to New Post'));
      await tester.pumpAndSettle();
      expect(find.byType(MomentCaptureScreen), findsNothing);
    });

    testWidgets('time running out in the camera stops before the back photo', (tester) async {
      final clock = Clock();
      final camera = FakeCamera();
      // A camera that uses up the time while it's open.
      await tester.pumpWidget(
        MaterialApp(
          home: MomentCaptureScreen(
            secondsRemaining: 30,
            now: clock.call,
            requestAccess: () async => CameraAccess.granted,
            takePhoto: (device) async {
              camera.asked.add(device);
              clock.advance(31);
              return photo('late.png');
            },
          ),
        ),
      );
      await tester.tap(find.text('Take front photo'));
      await tester.pumpAndSettle();

      expect(camera.asked, [CameraDevice.front]);
      expect(find.text("Time's up"), findsOneWidget);
    });

    testWidgets('a refused camera shows the permission message and opens nothing', (tester) async {
      final camera = FakeCamera();
      await pumpCapture(tester, camera: camera, clock: Clock(), access: CameraAccess.denied);

      await tester.tap(find.text('Take front photo'));
      await tester.pumpAndSettle();

      expect(find.text('InIBA needs your camera'), findsOneWidget);
      expect(camera.asked, isEmpty);
    });

    testWidgets('the clock turns red in the last 30 seconds', (tester) async {
      final clock = Clock();
      await pumpCapture(tester, camera: FakeCamera(), clock: clock, seconds: 31);
      final context = tester.element(find.byKey(const Key('moment-countdown')));
      final error = Theme.of(context).colorScheme.error;
      Color? color() => tester.widget<Text>(find.byKey(const Key('moment-countdown'))).style?.color;

      expect(color(), isNot(error));
      clock.advance(1);
      await tester.pump(const Duration(seconds: 1));
      expect(color(), error);
    });
  });

  group('MomentCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      FakeMomentRepository repo, {
      ValueChanged<MomentPhotos>? onCaptured,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [momentRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: MomentCard(
                onCaptured: onCaptured ?? (_) {},
                captureScreenBuilder: (seconds) => Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(MomentPhotos(front: photo('f.png'), back: photo('b.png'))),
                      child: Text('capture $seconds'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('open window: shows time left and Start opens the capture screen', (tester) async {
      MomentPhotos? got;
      final repo = FakeMomentRepository(
        status: MomentStatus(active: true, secondsRemaining: 95, alreadyPosted: false, feedLocked: true),
      );
      await pumpCard(tester, repo, onCaptured: (p) => got = p);

      expect(find.text('Your IBA Moment is open'), findsOneWidget);
      expect(find.textContaining('1:35 left'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('capture 95'), findsOneWidget);

      await tester.tap(find.text('capture 95'));
      await tester.pumpAndSettle();
      expect(got?.front.name, 'f.png');
      expect(repo.calls, 3); // on open, again when Start is tapped, and after coming back
    });

    testWidgets('Start checks again and stays put if the window closed meanwhile', (tester) async {
      final repo = FakeMomentRepository(
        status: MomentStatus(active: true, secondsRemaining: 95, alreadyPosted: false, feedLocked: true),
      );
      await pumpCard(tester, repo);

      repo.status = MomentStatus(active: false, secondsRemaining: 0, alreadyPosted: false, feedLocked: true);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.textContaining('capture'), findsNothing);
      expect(find.text('Your IBA Moment is not open right now'), findsOneWidget);
    });

    testWidgets('closed window: no Start button', (tester) async {
      await pumpCard(
        tester,
        FakeMomentRepository(
          status: MomentStatus(active: false, secondsRemaining: 0, alreadyPosted: false, feedLocked: true),
        ),
      );
      expect(find.text('Your IBA Moment is not open right now'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('already posted today: no Start button', (tester) async {
      await pumpCard(
        tester,
        FakeMomentRepository(
          status: MomentStatus(active: true, secondsRemaining: 60, alreadyPosted: true, feedLocked: false),
        ),
      );
      expect(find.text("You've posted today's IBA Moment"), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('server error shows the message and Retry tries again', (tester) async {
      final repo = FakeMomentRepository(failWith: ApiException(0, 'Could not reach the server.'));
      await pumpCard(tester, repo);
      expect(find.text('Could not reach the server.'), findsOneWidget);

      repo.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Your IBA Moment is open'), findsOneWidget);
    });
  });

  test('MomentStatus reads the API JSON and subtracts time since it arrived', () {
    final fetched = DateTime(2026, 11, 26, 14);
    final s = MomentStatus.fromJson({
      'active': true,
      'secondsRemaining': 100,
      'alreadyPosted': false,
      'feedLocked': true,
    });
    expect(s.canCapture, isTrue);
    final pinned = MomentStatus(
      active: s.active,
      secondsRemaining: s.secondsRemaining,
      alreadyPosted: false,
      feedLocked: true,
      fetchedAt: fetched,
    );
    expect(pinned.secondsLeftAt(fetched.add(const Duration(seconds: 30))), 70);
    expect(pinned.secondsLeftAt(fetched.add(const Duration(minutes: 5))), 0);
  });
}
