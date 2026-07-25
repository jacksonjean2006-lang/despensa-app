import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/lista_compras_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minha Despensa',
      theme: ThemeData(primarySwatch: Colors.lightBlue),
      home: const HomeScreen(),
    );
  }
}
ListaComprasScreen(),
// Exemplo de navegação para abrir a lista com id 1
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ListaComprasScreen(listaId: 1),
  ),
);
