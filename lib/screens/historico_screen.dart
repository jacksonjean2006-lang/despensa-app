import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/historico_compra.dart';
import '../models/produto.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});
  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Compras'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'Listas'),
            Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18),  text: 'Gastos'),
            Tab(icon: Icon(Icons.search_rounded, size: 18),     text: 'Produtos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AbaListasAnteriores(),
          _AbaVisaoGeral(),
          _AbaGastos(),
          _AbaProdutos(),
        ],
      ),
    );
  }
}

// ─── NOVA ABA: Listas Anteriores ──────────────────────────────────────────────
class _AbaListasAnteriores extends StatefulWidget {
  const _AbaListasAnteriores();
  @override
  State<_AbaListasAnteriores> createState() => _AbaListasAnterioresState();
}

class _AbaListasAnterioresState extends State<_AbaListasAnteriores> {
  List<Map<String, dynamic>> _listas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final data = await DatabaseHelper.instance.getListasFinalizadas();
    setState(() { _listas = data; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_listas.isEmpty) return const Center(child: Text('Nenhuma lista finalizada'));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _listas.length,
      itemBuilder: (context, index) {
        final lista = _listas[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: AppTheme.primary),
            title: Text(lista['descricao']),
            subtitle: Text('Finalizada em: ${formatarData(lista['finalizado_em'])}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _verDetalhesLista(lista),
          ),
        );
      },
    );
  }

  void _verDetalhesLista(Map<String, dynamic> lista) async {
    final itens = await DatabaseHelper.instance.getItensHistoricoPorLista(lista['id']);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(lista['descricao'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: itens.length,
                itemBuilder: (context, i) {
                  final item = itens[i];
                  return ListTile(
                    title: Text(item['produto_nome'] ?? item['nome_avulso'] ?? 'Item'),
                    subtitle: Text('${item['quantidade_comprada']} un · ${item['local_nome'] ?? 'Local não inf.'}'),
                    trailing: Text(item['preco_total'] != null ? formatarMoeda(item['preco_total']) : '--'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// (As outras abas _AbaVisaoGeral, _AbaGastos, _AbaProdutos permanecem iguais...)
// [Conteúdo omitido para brevidade, mas deve ser mantido no arquivo final]
class _AbaVisaoGeral extends StatelessWidget { const _AbaVisaoGeral(); @override Widget build(BuildContext context) => const Center(child: Text('Visão Geral')); }
class _AbaGastos extends StatelessWidget { const _AbaGastos(); @override Widget build(BuildContext context) => const Center(child: Text('Gastos')); }
class _AbaProdutos extends StatelessWidget { const _AbaProdutos(); @override Widget build(BuildContext context) => const Center(child: Text('Produtos')); }
