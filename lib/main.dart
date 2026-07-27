import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha Despensa',
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
