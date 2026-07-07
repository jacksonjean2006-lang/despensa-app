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

class _HistoricoScreenState extends State<HistoricoScreen> with SingleTickerProviderStateMixin {
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
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Gastos'),
            Tab(icon: Icon(Icons.search_rounded, size: 18), text: 'Produtos'),
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

// ─── ABA 1: Listas Anteriores ────────────────────────────────────────────────
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

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
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
      ),
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

// ─── ABA 2: Visão Geral (Últimos Preços) ─────────────────────────────────────
class _AbaVisaoGeral extends StatefulWidget {
  const _AbaVisaoGeral();
  @override
  State<_AbaVisaoGeral> createState() => _AbaVisaoGeralState();
}

class _AbaVisaoGeralState extends State<_AbaVisaoGeral> {
  List<Map<String, dynamic>> _ultimosPrecos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final data = await DatabaseHelper.instance.getUltimosPrecos();
    setState(() { _ultimosPrecos = data; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_ultimosPrecos.isEmpty) return const Center(child: Text('Nenhuma compra registrada'));

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _ultimosPrecos.length,
        itemBuilder: (context, index) {
          final item = _ultimosPrecos[index];
          final atual = (item['preco_unitario'] as num?)?.toDouble();
          final anterior = (item['preco_anterior'] as num?)?.toDouble();
          final subiu = atual != null && anterior != null && atual > anterior;

          return Card(
            child: ListTile(
              leading: Text(item['categoria_icone'] ?? '🛍️', style: const TextStyle(fontSize: 24)),
              title: Text(item['produto_nome'] ?? 'Item'),
              subtitle: Text('${formatarData(item['data'])} · ${item['local_nome'] ?? 'Local não inf.'}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(atual != null ? formatarMoeda(atual) : '--', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: subiu ? AppTheme.danger : Colors.black87)),
                  if (subiu) const Icon(Icons.trending_up, color: AppTheme.danger, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── ABA 3: Gastos (Resumo Mensal) ───────────────────────────────────────────
class _AbaGastos extends StatefulWidget {
  const _AbaGastos();
  @override
  State<_AbaGastos> createState() => _AbaGastosState();
}

class _AbaGastosState extends State<_AbaGastos> {
  List<Map<String, dynamic>> _resumo = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final data = await DatabaseHelper.instance.getResumoMensal();
    setState(() { _resumo = data; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_resumo.isEmpty) return const Center(child: Text('Sem dados de gastos'));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _resumo.length,
      itemBuilder: (context, index) {
        final r = _resumo[index];
        return Card(
          child: ListTile(
            title: Text(r['mes']),
            subtitle: Text('${r['num_compras']} compras · ${r['num_produtos']} produtos'),
            trailing: Text(formatarMoeda(r['total_gasto'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
        );
      },
    );
  }
}

// ─── ABA 4: Produtos (Busca) ────────────────────────────────────────────────
class _AbaProdutos extends StatefulWidget {
  const _AbaProdutos();
  @override
  State<_AbaProdutos> createState() => _AbaProdutosState();
}

class _AbaProdutosState extends State<_AbaProdutos> {
  List<Produto> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final data = await DatabaseHelper.instance.getProdutos();
    setState(() { _produtos = data; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _produtos.length,
      itemBuilder: (context, index) {
        final p = _produtos[index];
        return Card(
          child: ListTile(
            leading: FotoOuEmoji(fotoPath: p.fotoPath, icone: p.categoriaIcone),
            title: Text(p.nome),
            subtitle: Text('Estoque: ${p.estoqueAtual} ${p.unidade}'),
            onTap: () {
              // Navegar para detalhe do produto se necessário
            },
          ),
        );
      },
    );
  }
}
