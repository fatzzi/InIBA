import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../camera/camera_permission.dart';
import '../../camera/camera_permission_message.dart';
import '../../screens/photo_preview_screen.dart' show PhotoView;

/// The two photos of an IBA Moment. Returned by [MomentCaptureScreen] when the student taps
/// "Use these photos"; posting them is the composer's job (SCRUM-45).
class MomentPhotos {
  const MomentPhotos({required this.front, required this.back});

  final XFile front;
  final XFile back;
}

/// Opens the camera once and returns the photo, or null if the student closed it.
typedef TakePhoto = Future<XFile?> Function(CameraDevice camera);

/// SCRUM-44: IBA Moment capture. A 2-minute countdown, then the front photo and the back photo
/// one after the other, a combined preview, and retake for either photo.
///
/// Phones with one camera work too: the camera opens twice, and the student points it at
/// themselves and then away (or flips it in the camera app).
class MomentCaptureScreen extends StatefulWidget {
  const MomentCaptureScreen({
    super.key,
    required this.secondsRemaining,
    this.takePhoto,
    this.requestAccess = requestCameraAccess,
    this.now = DateTime.now,
  });

  /// Seconds left in today's window when the screen opens.
  final int secondsRemaining;

  /// Injectable for tests; the app uses [ImagePicker].
  final TakePhoto? takePhoto;
  final Future<CameraAccess> Function() requestAccess;
  final DateTime Function() now;

  @override
  State<MomentCaptureScreen> createState() => _MomentCaptureScreenState();
}

class _MomentCaptureScreenState extends State<MomentCaptureScreen> {
  late final DateTime _endsAt = widget.now().add(Duration(seconds: widget.secondsRemaining));
  late final TakePhoto _takePhoto = widget.takePhoto ?? _pickWithImagePicker;
  Timer? _ticker;

  XFile? _front;
  XFile? _back;
  CameraAccess? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The end time is fixed, so the clock stays right even while the camera app is open.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_secondsLeft == 0) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final left = (_endsAt.difference(widget.now()).inMilliseconds / 1000).ceil();
    return left < 0 ? 0 : left;
  }

  bool get _timeUp => _secondsLeft == 0;

  static Future<XFile?> _pickWithImagePicker(CameraDevice camera) => ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: camera,
    imageQuality: 85,
    maxWidth: 2000,
  );

  Future<bool> _ensureCamera() async {
    final access = await widget.requestAccess();
    if (!mounted) return false;
    setState(() => _problem = access == CameraAccess.granted ? null : access);
    return access == CameraAccess.granted;
  }

  /// Takes whichever photos are missing: front first, then back.
  Future<void> _capture({bool retakeFront = false, bool retakeBack = false}) async {
    if (_busy || _timeUp) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureCamera()) return;

      if (_front == null || retakeFront) {
        final shot = await _takePhoto(CameraDevice.front);
        if (!mounted || shot == null) return;
        setState(() => _front = shot);
      }
      if (_timeUp) return;
      if (_back == null || retakeBack) {
        final shot = await _takePhoto(CameraDevice.rear);
        if (!mounted || shot == null) return;
        setState(() => _back = shot);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the camera: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _usePhotos() {
    if (_front == null || _back == null || _timeUp) return;
    Navigator.of(context).pop(MomentPhotos(front: _front!, back: _back!));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasBoth = _front != null && _back != null;

    final Widget buttons;
    if (hasBoth) {
      buttons = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _usePhotos,
            icon: const Icon(Icons.check),
            label: const Text('Use these photos'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _capture(retakeFront: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake front'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _capture(retakeBack: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake back'),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      buttons = FilledButton.icon(
        onPressed: _busy ? null : _capture,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(_front == null ? 'Take front photo' : 'Take back photo'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('IBA Moment')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: _Countdown(secondsLeft: _secondsLeft),
            ),
            if (_timeUp)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [_TimeUpMessage(onClose: () => Navigator.of(context).pop())],
                ),
              )
            else ...[
              // The photos get whatever space is left; the buttons stay on screen without scrolling,
              // because every second counts here.
              Expanded(
                child: hasBoth
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: _MomentPreview(front: _front!, back: _back!),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          if (_problem != null) ...[
                            CameraPermissionMessage(
                              access: _problem!,
                              onTryAgain: _capture,
                              onOpenSettings: openCameraSettings,
                            ),
                            const SizedBox(height: 24),
                          ],
                          _Steps(frontDone: _front != null, backDone: _back != null),
                          const SizedBox(height: 12),
                          Text(
                            'Front camera first, then the back. One camera? Point it at yourself, then at what you see.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
              ),
              Padding(padding: const EdgeInsets.all(24), child: buttons),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big mm:ss clock. Turns red in the last 30 seconds.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = secondsLeft <= 30;
    final label = '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    return Semantics(
      liveRegion: true,
      label: '$secondsLeft seconds left',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Text(
              label,
              key: const Key('moment-countdown'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: urgent ? scheme.error : scheme.onSurface,
              ),
            ),
            Text('left to post your IBA Moment', style: TextStyle(color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.frontDone, required this.backDone});

  final bool frontDone;
  final bool backDone;

  @override
  Widget build(BuildContext context) {
    Widget step(String label, bool done) => ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
    );
    return Card(
      child: Column(
        children: [step('1. Front camera: you', frontDone), step('2. Back camera: what you see', backDone)],
      ),
    );
  }
}

/// Back photo full size with the front photo in the corner.
class _MomentPreview extends StatelessWidget {
  const _MomentPreview({required this.front, required this.back});

  final XFile front;
  final XFile back;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: PhotoView(key: const Key('moment-back'), photo: back, fit: BoxFit.cover),
            ),
            Positioned(
              top: 12,
              left: 12,
              width: 96,
              height: 128,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: Colors.black,
                    child: PhotoView(key: const Key('moment-front'), photo: front, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeUpMessage extends StatelessWidget {
  const _TimeUpMessage({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.timer_off_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text("Time's up", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          "Today's IBA Moment window has closed. You can still share a regular post.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onClose, child: const Text('Back to New Post')),
      ],
    );
  }
}
