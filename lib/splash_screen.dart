import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';
import 'theme.dart';

/// Tela de abertura (splash), mostrada por alguns segundos ao abrir o app,
/// antes de ir para a navegação principal.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/splash/icon.png',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Minha Despensa',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gestor de despensa e lista de compras',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            const Text(
              'Desenvolvido por Jean • jacksonjean2006@gmail.com',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}
