import 'package:flutter/material.dart';

import 'camera_permission.dart';

/// SCRUM-73: the "helpful message" when the camera isn't allowed.
class CameraPermissionMessage extends StatelessWidget {
  const CameraPermissionMessage({
    super.key,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onErrorContainer),
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
