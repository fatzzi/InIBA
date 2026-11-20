import 'package:flutter/material.dart';

/// Placeholder for the Create Post use case (dual-camera "IBA Moment" or
/// a short text post). Camera capture flow will be wired up once the
/// backend /posts endpoint exists.
class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Post')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'No "IBA Moment" prompt yet today.\nCheck back later, or write a text post.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Text posts are coming soon.'))),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write a text post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
