import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_controller.dart';

/// Wireframe 1.8 - Settings with Log Out (SCRUM-70).
/// Open it with: context.push('/settings')
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          "You'll need your IBA email and password to log back in on this device.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirm-logout'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log Out',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Clears the JWT; the router then redirects to /welcome.
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggingOut = ref.watch(authProvider.select((a) => a.isLoading));
    final errorColor = Theme.of(context).colorScheme.error;

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
            key: const Key('logout-tile'),
            enabled: !loggingOut,
            title: Text('Log Out', style: TextStyle(color: errorColor)),
            trailing: loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: () => _confirmLogout(context, ref),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
