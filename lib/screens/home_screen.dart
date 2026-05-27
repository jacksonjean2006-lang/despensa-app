import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Produto> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final p = await DatabaseHelper.instance.getProdutos(apenasAtivos: true);
    setState(() { _produtos = p; _carregando = false; });
  }

  List<Produto> get _criticos =>
      _produtos.where((p) => p.statusEstoque == 'critico').toList();
  List<Produto> get _atencao =>
      _produtos.where((p) => p.statusEstoque == 'atencao').toList();
  List<Produto> get _ok =>
      _produtos.where((p) => p.statusEstoque == 'ok').toList();

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hora = DateTime.now().hour;
    final saudacao = hora < 12 ? 'Bom dia!' : hora < 18 ? 'Boa tarde!' : 'Boa noite!';
    final precisamCompra = _produtos.where((p) => p.quantidadeComprar > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(saudacao, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Text('Minha Despensa', style: TextStyle(fontSize: 18)),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Estatísticas
            Row(children: [
              _StatCard(
                  label: 'produtos', valor: '${_produtos.length}', cor: null),
              const SizedBox(width: 8),
              _StatCard(
                  label: 'precisam de compra',
                  valor: '$precisamCompra',
                  cor: precisamCompra > 0 ? AppTheme.danger : AppTheme.success),
            ]),
            const SizedBox(height: 8),

            // Alerta
            if (precisamCompra > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFAC775)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$precisamCompra produto${precisamCompra > 1 ? 's' : ''} abaixo do consumo mensal',
                    style: const TextStyle(
                        color: AppTheme.warning, fontSize: 13),
                  ),
                ]),
              ),

            if (_criticos.isNotEmpty) ...[
              _sectionLabel('⚠️ Estoque crítico'),
              ..._criticos.map((p) => _ProdutoHomeCard(p)),
            ],

            if (_atencao.isNotEmpty) ...[
              _sectionLabel('🔔 Atenção'),
              ..._atencao.map((p) => _ProdutoHomeCard(p)),
            ],

            if (_ok.isNotEmpty) ...[
              _sectionLabel('✅ Estoque ok'),
              ..._ok.map((p) => _ProdutoHomeCard(p)),
            ],

            if (_produtos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Nenhum produto cadastrado ainda',
                      style: TextStyle(color: Colors.grey)),
                  Text('Vá em Produtos para começar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.4)),
  );
}

class _StatCard extends StatelessWidget {
  final String label, valor;
  final Color? cor;
  const _StatCard({required this.label, required this.valor, this.cor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(valor,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cor ?? Colors.black87)),
      ]),
    ),
  );
}

class _ProdutoHomeCard extends StatelessWidget {
  final Produto produto;
  const _ProdutoHomeCard(this.produto);

  @override
  Widget build(BuildContext context) {
    final pct = produto.consumoMensal > 0
        ? ((produto.estoqueAtual ?? 0) / produto.consumoMensal).clamp(0.0, 1.0)
        : 0.0;
    final corBarra = produto.statusEstoque == 'critico'
        ? AppTheme.danger
        : produto.statusEstoque == 'atencao'
            ? const Color(0xFFEF9F27)
            : AppTheme.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          FotoOuEmoji(
              fotoPath: produto.fotoPath,
              icone: produto.categoriaIcone ?? '📦'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(produto.nome,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'estoque: ${formatarQtd(produto.estoqueAtual ?? 0, produto.unidade)}'
                ' · meta: ${formatarQtd(produto.consumoMensal, produto.unidade)}/mês',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(corBarra),
                  minHeight: 4,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(produto.statusEstoque),
        ]),
      ),
    );
  }
}
