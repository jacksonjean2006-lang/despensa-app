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
  // Um contador por aba: ao incrementar, muda a Key do widget e força o
  // Flutter a recriá-lo do zero (rodando initState/_carregar de novo).
  // Sem isso, as abas ficavam "congeladas" com os dados de quando o app abriu.
  final List<int> _refreshKeys = [0, 0, 0, 0, 0];

  List<Widget> get _telas => [
    HomeScreen(key: ValueKey('home_${_refreshKeys[0]}')),
    ProdutosScreen(key: ValueKey('produtos_${_refreshKeys[1]}')),
    LevantamentoScreen(key: ValueKey('estoque_${_refreshKeys[2]}')),
    ListaComprasScreen(key: ValueKey('lista_${_refreshKeys[3]}')),
    HistoricoScreen(key: ValueKey('historico_${_refreshKeys[4]}')),
  ];

  void _selecionarAba(int i) {
    setState(() {
      _refreshKeys[i]++;
      _indiceAtual = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_indiceAtual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: _selecionarAba,
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
