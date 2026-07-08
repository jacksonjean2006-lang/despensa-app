import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'compra_avulsa_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List<Produto>> _carregarProdutos() {
    return DatabaseHelper.instance.getProdutos(apenasAtivos: true);
  }

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final saudacao = hora < 12 ? 'Bom dia!' : hora < 18 ? 'Boa tarde!' : 'Boa noite!';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade400,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(saudacao, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const Text('Minha Despensa', style: TextStyle(fontSize: 18, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            tooltip: 'Compra avulsa',
            onPressed: () async {
              final alterou = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CompraAvulsaScreen()),
              );
              if (alterou == true) (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Produto>>(
        future: _carregarProdutos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Carregando produtos...', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.lightBlue.shade100,
                    valueColor: AlwaysStoppedAnimation(Colors.lightBlue.shade400),
                  ),
                ),
              ],
            );
          }
          final produtos = snapshot.data ?? [];
          final criticos = produtos.where((p) => p.statusEstoque == 'critico').toList();
          final atencao = produtos.where((p) => p.statusEstoque == 'atencao').toList();
          final ok = produtos.where((p) => p.statusEstoque == 'ok').toList();
          final precisamCompra = produtos.where((p) => p.quantidadeComprar > 0).length;

          return RefreshIndicator(
            onRefresh: () async => (context as Element).markNeedsBuild(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Colors.lightBlue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined, color: Colors.lightBlue),
                    title: const Text('Compra avulsa',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.lightBlue)),
                    subtitle: const Text('Registre uma compra sem gerar lista',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.lightBlue),
                    onTap: () async {
                      final alterou = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const CompraAvulsaScreen()),
                      );
                      if (alterou == true) (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                const SizedBox(height: 8),

                Row(children: [
                  _StatCard(label: 'produtos', valor: '${produtos.length}', cor: null),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: 'precisam de compra',
                      valor: '$precisamCompra',
                      cor: precisamCompra > 0 ? AppTheme.danger : AppTheme.success),
                ]),
                const SizedBox(height: 8),

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
                        style: const TextStyle(color: AppTheme.warning, fontSize: 13),
                      ),
                    ]),
                  ),

                if (criticos.isNotEmpty) ...[
                  _sectionLabel('⚠️ Estoque crítico'),
                  ...criticos.map((p) => _ProdutoHomeCard(p)),
                ],
                if (atencao.isNotEmpty) ...[
                  _sectionLabel('🔔 Atenção'),
                  ...atencao.map((p) => _ProdutoHomeCard(p)),
                ],
                if (ok.isNotEmpty) ...[
                  _sectionLabel('✅ Estoque ok'),
                  ...ok.map((p) => _ProdutoHomeCard(p)),
                ],
                if (produtos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Nenhum produto cadastrado ainda',
                          style: TextStyle(color: Colors.grey)),
                      Text('Vá em Produtos para começar',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ),
              ],
            ),
          );
        },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(valor,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cor ?? Colors.black87)),
            ],
          ),
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
        child: Row(
          children: [
            FotoOuEmoji(fotoPath: produto.fotoPath, icone: produto.categoriaIcone ?? '📦'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(produto.statusEstoque),
          ],
        ),
      ),
    );
  }
}
