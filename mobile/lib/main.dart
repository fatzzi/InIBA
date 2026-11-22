import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const ProviderScope(child: InibaApp()));
}

class InibaApp extends StatelessWidget {
  const InibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InIBA',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const WelcomeScreen(),
    );
  }
}
