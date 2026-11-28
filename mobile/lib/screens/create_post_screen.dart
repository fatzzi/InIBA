import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../camera/camera_permission.dart';
import '../camera/camera_permission_message.dart';
import '../features/moment/moment_capture_screen.dart';
import '../features/moment/moment_card.dart';
import 'photo_preview_screen.dart';

/// Create Post (Content Creation).
/// - SCRUM-73: ask for camera permission, explain what to do if it's denied
/// - SCRUM-74: open the camera, take one photo, preview it (Retake / Use photo)
/// - SCRUM-44: IBA Moment card at the top, leading to the front + back capture with a countdown
/// Uploading the post (POST /posts) comes with the composer (SCRUM-45).
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
  MomentPhotos? _moment;
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
          MomentCard(onCaptured: (photos) => setState(() => _moment = photos)),
          const SizedBox(height: 16),
          if (_moment != null) ...[
            Row(
              children: [
                Expanded(child: _Thumb(label: 'Front', photo: _moment!.front)),
                const SizedBox(width: 12),
                Expanded(child: _Thumb(label: 'Back', photo: _moment!.back)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'IBA Moment ready. Posting it arrives with the post composer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
          ],
          if (_problem != null) ...[
            CameraPermissionMessage(
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
            onPressed: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Text posts are coming soon.'))),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Write a text post'),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.label, required this.photo});

  final String label;
  final XFile photo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 3 / 4, child: PhotoView(photo: photo, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
