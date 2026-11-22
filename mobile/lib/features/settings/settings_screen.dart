import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_controller.dart';

/// Wireframe 1.8 - Settings with Log Out.
/// Open it with: context.push('/settings')
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Edit profile')),
          const Divider(height: 1),
          const ListTile(title: Text('Help & FAQ')),
          const Divider(height: 1),
          const ListTile(title: Text('Send feedback')),
          const Divider(height: 1),
          ListTile(
            title: Text(
              'Log Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            // Clears the JWT; the router redirects to /welcome.
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
