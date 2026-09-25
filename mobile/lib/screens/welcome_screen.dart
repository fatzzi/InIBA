import 'package:flutter/material.dart';

import 'home_shell.dart';

/// Landing screen. In the real app, Log In / Sign Up will hit the
/// FastAPI /auth endpoints; for now they just drop into the app shell
/// so the rest of the UI can be reviewed.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 72),
              const SizedBox(height: 16),
              Text(
                'InIBA',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'One place for low-pressure moments\nand campus updates, for IBA students only.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => _enterApp(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Log In'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _enterApp(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sign Up with IBA email'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterApp(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }
}
