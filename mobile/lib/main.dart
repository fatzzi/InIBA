import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';

void main() {
  runApp(const InibaApp());
}

class InibaApp extends StatelessWidget {
  const InibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InIBA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
