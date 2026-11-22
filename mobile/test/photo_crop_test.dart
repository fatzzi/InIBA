import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iniba/features/profile/photo_crop.dart';

Uint8List jpeg(int w, int h) => Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h)));

void main() {
  group('visibleSquare', () {
    test('centred landscape photo at zoom 1 gives the middle square', () {
      // 1200x800 photo in a 400px viewport: cover scale 0.5, shown as 600x400, centred by -100px.
      final t = Matrix4.translationValues(-100, 0, 0);
      expect(visibleSquare(imageW: 1200, imageH: 800, viewport: 400, transform: t), const CropSquare(200, 0, 800));
    });

    test('zoom 2 halves the square and panning moves it', () {
      // Zoom 2 around the origin, then pan so the viewport starts at child (300, 100).
      final t = Matrix4.identity()
        ..translateByDouble(-600, -200, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      // child (300,100) -> image (600,200); size = 400 / 2 / 0.5 = 400
      expect(visibleSquare(imageW: 1200, imageH: 800, viewport: 400, transform: t), const CropSquare(600, 200, 400));
    });

    test('result is clamped inside the photo', () {
      final t = Matrix4.translationValues(50, 50, 0); // panned past the top-left edge
      expect(visibleSquare(imageW: 800, imageH: 800, viewport: 400, transform: t), const CropSquare(0, 0, 800));
    });
  });

  group('preparePhoto', () {
    test('reads size and the 400px rule', () {
      final big = preparePhoto(jpeg(1200, 800))!;
      expect((big.width, big.height), (1200, 800));
      expect(big.bigEnough, isTrue);
      expect(big.maxZoom, 2.0); // 800 / 400

      final small = preparePhoto(jpeg(399, 600))!;
      expect(small.bigEnough, isFalse);
      expect(small.maxZoom, 1.0);
    });

    test('caps huge photos at a 2048px short side', () {
      final huge = preparePhoto(jpeg(4096, 3072))!;
      expect(huge.shortSide, 2048);
      expect(huge.width, 2731);
    });

    test('rejects bytes that are not an image', () {
      expect(preparePhoto(Uint8List.fromList(List.filled(64, 7))), isNull);
    });
  });

  group('cropToJpeg', () {
    test('produces a square JPEG of the requested size', () {
      final prepared = preparePhoto(jpeg(1200, 800))!;
      final out = img.decodeJpg(cropToJpeg(prepared.jpeg, const CropSquare(200, 0, 800)))!;
      expect((out.width, out.height), (800, 800));
    });

    test('scales down to 1080 at most', () {
      final prepared = preparePhoto(jpeg(2000, 1500))!;
      final out = img.decodeJpg(cropToJpeg(prepared.jpeg, const CropSquare(0, 0, 1500)))!;
      expect((out.width, out.height), (1080, 1080));
    });
  });

  testWidgets('crop screen rejects a photo under 400x400', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: CropPhotoScreen(source: jpeg(300, 300))));
      for (var i = 0; i < 50 && find.byKey(const Key('crop-error')).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(find.text('Image must be at least 400×400 px.'), findsOneWidget);
    final done = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Done'));
    expect(done.onPressed, isNull);
  });

  testWidgets('crop screen returns a square JPEG on Done', (tester) async {
    Uint8List? result;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<Uint8List>(MaterialPageRoute(builder: (_) => CropPhotoScreen(source: jpeg(900, 600)))),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      Future<void> settle(bool Function() until) async {
        for (var i = 0; i < 100 && !until(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 100)); // also lets route animations finish
        }
      }

      await settle(() =>
          find.widgetWithText(TextButton, 'Done').evaluate().isNotEmpty &&
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Done')).onPressed != null);
      await tester.pump(const Duration(seconds: 1)); // route fully on screen before tapping
      await tester.tap(find.text('Done'));
      await settle(() => result != null);
    });
    expect(result, isNotNull);
    final out = img.decodeJpg(result!)!;
    expect(out.width, out.height);
    expect(out.width, 600);
  });
}
