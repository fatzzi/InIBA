import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wireframe 1.1 - Welcome (no valid JWT).
/// Layout: image placeholder, "InIBA" title, tagline, then
/// Sign Up (filled), Log In (outlined) and the email hint at the bottom.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top area: image + title + tagline
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image placeholder. Swap for Image.asset(...) when the
                    // team has the real artwork.
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image_outlined,
                        size: 56,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'InIBA',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your campus, unfiltered. IBA students only.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              // Bottom area: buttons + hint
              FilledButton(
                onPressed: () => context.push('/signup'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sign Up with IBA email'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/login'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Log In'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your @khi.iba.edu.pk email',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
