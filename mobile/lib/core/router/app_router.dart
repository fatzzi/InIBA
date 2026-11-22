import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_otp_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../screens/home_shell.dart';
import '../../screens/welcome_screen.dart';
import '../../features/profile/profile_screen.dart';

const _publicRoutes = {'/welcome', '/signup', '/login', '/verify'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: auth,
    redirect: (context, state) {
      final a = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isPublic = _publicRoutes.contains(loc);
      if (a.status == AuthStatus.unknown) {
        return null;
      }
      if (a.status == AuthStatus.unauthenticated) {
        return isPublic ? null : '/welcome';
      }
      if (a.needsProfileSetup) {
        return loc == '/profile-setup' ? null : '/profile-setup';
      }
      if (isPublic || loc == '/profile-setup') {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) =>
            VerifyOtpScreen(email: (state.extra as String?) ?? ''),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(path: '/feed', builder: (_, _) => const HomeShell()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    ],
  );
});
