import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../camera/camera_permission.dart';
import 'photo_preview_screen.dart';

/// Create Post (Content Creation). Sprint 1 scope:
/// - SCRUM-73: ask for camera permission, explain what to do if it's denied
/// - SCRUM-74: open the camera, take one photo, preview it (Retake / Use photo)
/// Uploading the post (POST /posts) and the dual-camera IBA Moment (SCRUM-44)
/// come in later sprints.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.picker});

  /// Injectable for tests; the real app uses the default ImagePicker.
  final ImagePicker? picker;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  /// Last permission problem, shown as a message card. Null = no problem.
  CameraAccess? _problem;
  XFile? _photo;
  bool _busy = false;

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final access = await requestCameraAccess();
      if (!mounted) return;
      if (access != CameraAccess.granted) {
        setState(() => _problem = access);
        return;
      }
      setState(() => _problem = null);

      // Loop so "Retake" opens the camera again straight from the preview.
      while (mounted) {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (shot == null || !mounted) return; // closed the camera without a photo

        final choice = await Navigator.of(context).push<PreviewChoice>(
          MaterialPageRoute(builder: (_) => PhotoPreviewScreen(photo: shot)),
        );
        if (choice == PreviewChoice.retake) continue;
        if (choice == PreviewChoice.use && mounted) setState(() => _photo = shot);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the camera: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_problem != null) ...[
            _PermissionMessage(
              access: _problem!,
              onTryAgain: _takePhoto,
              onOpenSettings: openCameraSettings,
            ),
            const SizedBox(height: 24),
          ],
          if (_photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: PhotoView(photo: _photo!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photo ready. Posting it arrives with the posts API.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 24),
            Icon(Icons.camera_alt_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text(
              'Take a photo for your post, or write a text post.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _takePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_photo == null ? 'Take a photo' : 'Take another photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Write a text post'),
          ),
        ],
      ),
    );
  }
}

/// SCRUM-73: the "helpful message" when the camera isn't allowed.
class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.access,
    required this.onTryAgain,
    required this.onOpenSettings,
  });

  final CameraAccess access;
  final VoidCallback onTryAgain;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, body) = switch (access) {
      CameraAccess.blocked => (
          'Camera is turned off for InIBA',
          'You chose not to be asked again. Open Settings, tap Permissions and allow Camera.',
        ),
      CameraAccess.unsupported => (
          'Camera not available here',
          'Taking photos works on the Android or iPhone app. Run it on a phone or emulator.',
        ),
      _ => (
          'InIBA needs your camera',
          'The camera is used to take your IBA Moment and photo posts. '
              'Nothing is captured until you press the shutter.',
        ),
    };

    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.no_photography_outlined, color: colors.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: colors.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: colors.onErrorContainer)),
            if (access != CameraAccess.unsupported) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: access == CameraAccess.blocked
                    ? FilledButton(onPressed: onOpenSettings, child: const Text('Open Settings'))
                    : FilledButton(onPressed: onTryAgain, child: const Text('Try again')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
