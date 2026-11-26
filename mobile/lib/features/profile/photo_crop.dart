import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Profile photos must be at least this many pixels on each side (API doc 3.3).
const kMinPhotoSide = 400;

/// Cropped photos are scaled down to at most this many pixels per side before upload.
const kMaxPhotoSide = 1080;

/// Picks a photo from the gallery. Overridden in tests.
final photoPickerProvider = Provider<Future<Uint8List?> Function()>((_) => () async {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      return file?.readAsBytes();
    });

/// Opens the crop screen for picked bytes and returns the cropped JPEG (or null). Overridden in tests.
final photoCropperProvider = Provider<Future<Uint8List?> Function(BuildContext, Uint8List)>(
  (_) => (context, bytes) => Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => CropPhotoScreen(source: bytes), fullscreenDialog: true),
      ),
);

// ---------------------------------------------------------------- pure helpers (unit tested)

/// A square region of the source image, in image pixels.
@immutable
class CropSquare {
  const CropSquare(this.left, this.top, this.size);

  final int left;
  final int top;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is CropSquare && other.left == left && other.top == top && other.size == size;

  @override
  int get hashCode => Object.hash(left, top, size);

  @override
  String toString() => 'CropSquare($left, $top, $size)';
}

/// The photo after EXIF rotation, decoded once so the crop maths and the final crop use the same pixels.
class PreparedPhoto {
  const PreparedPhoto(this.jpeg, this.width, this.height);

  final Uint8List jpeg;
  final int width;
  final int height;

  int get shortSide => math.min(width, height);
  bool get bigEnough => shortSide >= kMinPhotoSide;

  /// How far the student may zoom in: never so far that the crop drops below [kMinPhotoSide].
  double get maxZoom => math.max(1.0, shortSide / kMinPhotoSide);
}

/// Decode, apply EXIF orientation, and cap very large photos (short side 2048) to keep cropping quick.
/// Returns null if the bytes are not an image we can read.
PreparedPhoto? preparePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final short = math.min(image.width, image.height);
  if (short > 2048) {
    final k = 2048 / short;
    image = img.copyResize(image, width: (image.width * k).round(), height: (image.height * k).round());
  }
  return PreparedPhoto(Uint8List.fromList(img.encodeJpg(image, quality: 92)), image.width, image.height);
}

/// Which square of an [imageW] x [imageH] photo is visible in a [viewport]-sized square, when the photo is
/// first scaled to cover the square and then moved by the viewer's [transform] (zoom + pan).
CropSquare visibleSquare({
  required int imageW,
  required int imageH,
  required double viewport,
  required Matrix4 transform,
}) {
  final cover = viewport / math.min(imageW, imageH); // screen px per image px at zoom 1
  final zoom = transform.getMaxScaleOnAxis();
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero); // in the child's (unzoomed) coordinates
  final short = math.min(imageW, imageH);
  final size = (viewport / zoom / cover).round().clamp(1, short);
  final left = (topLeft.dx / cover).round().clamp(0, imageW - size);
  final top = (topLeft.dy / cover).round().clamp(0, imageH - size);
  return CropSquare(left, top, size);
}

/// Crop the prepared JPEG to [square], cap it at [kMaxPhotoSide], and encode as JPEG.
Uint8List cropToJpeg(Uint8List preparedJpeg, CropSquare square) {
  final source = img.decodeJpg(preparedJpeg)!;
  var out = img.copyCrop(source, x: square.left, y: square.top, width: square.size, height: square.size);
  if (out.width > kMaxPhotoSide) {
    out = img.copyResize(out, width: kMaxPhotoSide, height: kMaxPhotoSide);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 88));
}

Uint8List _cropJob((Uint8List, CropSquare) job) => cropToJpeg(job.$1, job.$2);

// ---------------------------------------------------------------- crop screen (wireframe 3-4)

/// Fixed 1:1 crop: drag to reposition, pinch to zoom. Pops with the cropped JPEG, or null on Cancel.
class CropPhotoScreen extends StatefulWidget {
  const CropPhotoScreen({super.key, required this.source});

  final Uint8List source;

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  final _controller = TransformationController();
  PreparedPhoto? _photo;
  String? _error;
  bool _busy = true;
  double _viewport = 0;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final photo = await compute(preparePhoto, widget.source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _photo = photo;
      if (photo == null) {
        _error = "That file isn't a photo we can read.";
      } else if (!photo.bigEnough) {
        _error = 'Image must be at least $kMinPhotoSide×$kMinPhotoSide px.';
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final photo = _photo;
    if (photo == null || !photo.bigEnough || _viewport == 0) return;
    setState(() => _busy = true);
    final square = visibleSquare(
      imageW: photo.width,
      imageH: photo.height,
      viewport: _viewport,
      transform: _controller.value,
    );
    final jpeg = await compute(_cropJob, (photo.jpeg, square));
    if (mounted) Navigator.of(context).pop(jpeg);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final canFinish = !_busy && photo != null && photo.bigEnough;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111111),
          leadingWidth: 88,
          leading: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          title: const Text('Crop photo'),
          centerTitle: true,
          actions: [TextButton(onPressed: canFinish ? _done : null, child: const Text('Done'))],
        ),
        body: LayoutBuilder(builder: (context, box) {
          // The square is as big as fits: screen width minus margins, or height minus the text below it.
          final side = math.max(0.0, math.min(box.maxWidth - 48, box.maxHeight - 120));
          _viewport = side;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: side, child: _cropArea(photo, side)),
                const SizedBox(height: 16),
                const Text('Drag to reposition, pinch to zoom'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('crop-error'), style: const TextStyle(color: Color(0xFFFF8A80))),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _cropArea(PreparedPhoto? photo, double side) {
    if (_busy && photo == null) return const Center(child: CircularProgressIndicator());
    if (photo == null) return const ColoredBox(color: Color(0xFF444444));
    final cover = side / photo.shortSide;
    if (!_centered) {
      // Start with the middle of the photo inside the square.
      _centered = true;
      _controller.value = Matrix4.translationValues(
        -(photo.width * cover - side) / 2,
        -(photo.height * cover - side) / 2,
        0,
      );
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: 1,
            maxScale: photo.maxZoom,
            child: Image.memory(
              photo.jpeg,
              width: photo.width * cover,
              height: photo.height * cover,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
              ),
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
