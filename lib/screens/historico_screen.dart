import 'package:flutter/material.dart';
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

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Produto> _produtos = [];
  Produto? _selecionado;
  List<HistoricoCompra> _historico = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    final p = await DatabaseHelper.instance.getProdutos();
    setState(() => _produtos = p);
  }

  Future<void> _carregarHistorico(Produto p) async {
    setState(() { _selecionado = p; _carregando = true; });
    final h = await DatabaseHelper.instance.getHistoricoProduto(p.id!);
    setState(() { _historico = h; _carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Compras')),
      body: _selecionado == null ? _listaProdutos() : _detalhe(),
    );
  }

  Widget _listaProdutos() => Column(children: [
    const Padding(
      padding: EdgeInsets.all(12),
      child: Text('Selecione um produto para ver o histórico de preços e locais:',
          style: TextStyle(color: Colors.grey)),
    ),
    Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _produtos.length,
        itemBuilder: (_, i) {
          final p = _produtos[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: FotoOuEmoji(
                  fotoPath: p.fotoPath, icone: p.categoriaIcone ?? '📦'),
              title: Text(p.nome),
              subtitle: Text(p.marca ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _carregarHistorico(p),
            ),
          );
        },
      ),
    ),
  ]);

  Widget _detalhe() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historico.isEmpty) {
      return Column(children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selecionado = null),
          ),
          title: Text(_selecionado!.nome,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Expanded(
          child: Center(
            child: Text('Nenhuma compra registrada ainda',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      ]);
    }

    // Estatísticas
    final precos = _historico
        .where((h) => h.precoUnitario != null)
        .map((h) => h.precoUnitario!)
        .toList();
    final menorPreco = precos.isNotEmpty
        ? precos.reduce((a, b) => a < b ? a : b)
        : null;
    final maiorPreco = precos.isNotEmpty
        ? precos.reduce((a, b) => a > b ? a : b)
        : null;

    // Ranking de locais
    final mapaLocais = <String, List<double>>{};
    for (final h in _historico) {
      if (h.localNome != null && h.precoUnitario != null) {
        mapaLocais.putIfAbsent(h.localNome!, () => []).add(h.precoUnitario!);
      }
    }
    final rankingLocais = mapaLocais.entries.map((e) {
      final media = e.value.reduce((a, b) => a + b) / e.value.length;
      return MapEntry(e.key, media);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(children: [
      // Header com voltar
      ListTile(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selecionado = null),
        ),
        title: Text(_selecionado!.nome,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_selecionado!.marca ?? ''),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            // Cards de stat
            if (precos.isNotEmpty)
              Row(children: [
                _StatPreco(
                    label: 'último preço',
                    valor: formatarMoeda(_historico.first.precoUnitario ?? 0),
                    sub: 'por ${_selecionado!.unidade}'),
                const SizedBox(width: 8),
                _StatPreco(
                    label: 'menor preço',
                    valor: formatarMoeda(menorPreco!),
                    sub: _historico
                            .firstWhere((h) => h.precoUnitario == menorPreco)
                            .localNome ??
                        '',
                    cor: AppTheme.success),
              ]),
            const SizedBox(height: 8),

            // Ranking locais
            if (rankingLocais.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 6),
                child: Text('COMPARATIVO DE MERCADOS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 0.4)),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: rankingLocais.asMap().entries.map((e) {
                      final idx = e.key;
                      final local = e.value.key;
                      final media = e.value.value;
                      final pct = maiorPreco != null && maiorPreco > 0
                          ? media / maiorPreco
                          : 1.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Expanded(
                              child: Row(children: [
                                Text(local,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                if (idx == 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successBg,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Text('menor preço',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.success)),
                                  ),
                              ]),
                            ),
                            Text(
                              '${formatarMoeda(media)}/${_selecionado!.unidade}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: idx == 0
                                      ? AppTheme.success
                                      : Colors.black87),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                  idx == 0
                                      ? AppTheme.success
                                      : AppTheme.primary),
                              minHeight: 4,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // Timeline
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 6),
              child: Text('LINHA DO TEMPO',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.4)),
            ),
            ..._historico.asMap().entries.map((e) {
              final h = e.value;
              final anterior = e.key + 1 < _historico.length
                  ? _historico[e.key + 1]
                  : null;
              final diff = (h.precoUnitario != null &&
                      anterior?.precoUnitario != null)
                  ? h.precoUnitario! - anterior!.precoUnitario!
                  : null;
              final eMenor = h.precoUnitario != null &&
                  h.precoUnitario == menorPreco;
              final eMaior = h.precoUnitario != null &&
                  h.precoUnitario == maiorPreco && precos.length > 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(formatarData(h.data),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          if (h.localNome != null)
                            Row(children: [
                              const Icon(Icons.store_outlined,
                                  size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(h.localNome!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primary)),
                              if (eMenor)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: AppTheme.successBg,
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                  child: const Text('menor preço',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.success)),
                                ),
                              if (eMaior)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: AppTheme.dangerBg,
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                  child: const Text('mais caro',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.danger)),
                                ),
                            ]),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        if (h.precoTotal != null)
                          Text(formatarMoeda(h.precoTotal!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        if (h.precoUnitario != null)
                          Text(
                            '${formatarQtd(h.quantidadeComprada, _selecionado!.unidade)} · '
                            '${formatarMoeda(h.precoUnitario!)}/${_selecionado!.unidade}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ]),
                    ]),
                    if (diff != null) ...[
                      const Divider(height: 12),
                      Row(children: [
                        Icon(
                          diff > 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color:
                              diff > 0 ? AppTheme.danger : AppTheme.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${diff > 0 ? '+' : ''}${formatarMoeda(diff)}/${_selecionado!.unidade} em relação à compra anterior',
                          style: TextStyle(
                              fontSize: 12,
                              color: diff > 0
                                  ? AppTheme.danger
                                  : AppTheme.success),
                        ),
                      ]),
                    ],
                  ]),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ]);
  }
}

class _StatPreco extends StatelessWidget {
  final String label, valor, sub;
  final Color? cor;
  const _StatPreco(
      {required this.label, required this.valor, required this.sub, this.cor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(valor,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor ?? Colors.black87)),
        Text(sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    ),
  );
}
