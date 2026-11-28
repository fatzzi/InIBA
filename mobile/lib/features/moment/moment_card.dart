import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'moment_capture_screen.dart';
import 'moment_repository.dart';

/// Top of New Post: is today's IBA Moment open, and the way into the capture screen (SCRUM-44).
/// The push notification (SCRUM-43) will lead here too.
class MomentCard extends ConsumerWidget {
  const MomentCard({super.key, required this.onCaptured, this.captureScreenBuilder});

  /// Called with both photos after the student taps "Use these photos".
  final ValueChanged<MomentPhotos> onCaptured;

  /// Injectable for tests; defaults to [MomentCaptureScreen].
  final Widget Function(int secondsRemaining)? captureScreenBuilder;

  Future<void> _start(BuildContext context, WidgetRef ref, MomentStatus status) async {
    final seconds = status.secondsLeftAt(DateTime.now());
    final photos = await Navigator.of(context).push<MomentPhotos>(
      MaterialPageRoute(
        builder: (_) => captureScreenBuilder?.call(seconds) ?? MomentCaptureScreen(secondsRemaining: seconds),
      ),
    );
    if (photos != null) onCaptured(photos);
    ref.invalidate(momentStatusProvider); // the window may have closed meanwhile
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(momentStatusProvider);

    final Widget content = status.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => _Row(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't check your IBA Moment",
        subtitle: e is ApiException ? e.message : 'Something went wrong.',
        action: TextButton(onPressed: () => ref.invalidate(momentStatusProvider), child: const Text('Retry')),
      ),
      data: (s) {
        if (s.alreadyPosted) {
          return const _Row(
            icon: Icons.check_circle_outline,
            title: "You've posted today's IBA Moment",
            subtitle: 'See you tomorrow.',
          );
        }
        if (!s.active) {
          return const _Row(
            icon: Icons.notifications_none,
            title: 'Your IBA Moment is not open right now',
            subtitle: "You'll get a notification when it starts. Then you have 2 minutes.",
          );
        }
        final left = s.secondsLeftAt(DateTime.now());
        return _Row(
          icon: Icons.bolt,
          iconColor: scheme.primary,
          title: 'Your IBA Moment is open',
          subtitle: '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left. Front and back camera.',
          action: FilledButton(onPressed: () => _start(context, ref, s), child: const Text('Start')),
        );
      },
    );

    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: content),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, this.action, this.iconColor});

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    );
  }
}
