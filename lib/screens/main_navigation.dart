import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'produtos_screen.dart';
import 'levantamento_screen.dart';
import 'lista_compras_screen.dart';
import 'historico_screen.dart';
import '../theme.dart';

/// Navegação principal do app: barra inferior com as 5 telas.
/// Sem isso, o app não tinha nenhuma forma de sair da tela Início.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _indiceAtual = 0;

  final _telas = const [
    HomeScreen(),
    ProdutosScreen(),
    LevantamentoScreen(),
    ListaComprasScreen(),
    HistoricoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (i) => setState(() => _indiceAtual = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primary),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primary),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: AppTheme.primary),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: AppTheme.primary),
            label: 'Lista',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primary),
            label: 'Histórico',
          ),
        ],
      ),
    );
  }
}
