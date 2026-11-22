import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'screens/welcome_screen.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: InibaApp()));
}

class InibaApp extends ConsumerWidget {
  const InibaApp({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return MaterialApp.router(
      title: 'InIBA',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
