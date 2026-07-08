import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/historico_compra.dart';
import '../models/produto.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ─── Tela principal com abas ──────────────────────────────────────────────────
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
    _tabs = TabController(length: 3, vsync: this);
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
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view_rounded, size: 18), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 18),  text: 'Gastos'),
            Tab(icon: Icon(Icons.search_rounded, size: 18),     text: 'Produtos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AbaVisaoGeral(),
          _AbaGastos(),
          _AbaProdutos(),
        ],
      ),
    );
  }
}

// ─── ABA 1: Visão Geral ───────────────────────────────────────────────────────
class _AbaVisaoGeral extends StatefulWidget {
  const _AbaVisaoGeral();
  @override
  State<_AbaVisaoGeral> createState() => _AbaVisaoGeralState();
}

class _AbaVisaoGeralState extends State<_AbaVisaoGeral>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _ultimosPrecos = [];
  bool _carregando = true;
  String _filtro = 'todos'; // todos | alertas

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

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'alertas') {
      return _ultimosPrecos.where((p) {
        final atual    = (p['preco_unitario'] as num?)?.toDouble();
        final anterior = (p['preco_anterior'] as num?)?.toDouble();
        return atual != null && anterior != null && atual > anterior;
      }).toList();
    }
    return _ultimosPrecos;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ultimosPrecos.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('Nenhuma compra registrada ainda',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    final alertas = _ultimosPrecos.where((p) {
      final atual    = (p['preco_unitario'] as num?)?.toDouble();
      final anterior = (p['preco_anterior'] as num?)?.toDouble();
      return atual != null && anterior != null && atual > anterior;
    }).length;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Banner de alertas
          if (alertas > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up, color: AppTheme.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$alertas produto${alertas > 1 ? 's' : ''} mais caro${alertas > 1 ? 's' : ''} que na última compra',
                    style: const TextStyle(
                        color: AppTheme.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],

          // Filtro
          Row(children: [
            _chipFiltro('todos', 'Todos (${_ultimosPrecos.length})'),
            const SizedBox(width: 8),
            if (alertas > 0)
              _chipFiltro('alertas', '⚠ Alertas ($alertas)'),
          ]),
          const SizedBox(height: 10),

          // Lista
          ..._filtrados.map((p) => _CardUltimoPreco(item: p,
              onTap: () => _abrirDetalhe(p))),
        ],
      ),
    );
  }

  Widget _chipFiltro(String valor, String label) => FilterChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: _filtro == valor,
    onSelected: (_) => setState(() => _filtro = valor),
    selectedColor: AppTheme.primaryBg,
    checkmarkColor: AppTheme.primary,
  );

  void _abrirDetalhe(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DetalheHistoricoScreen(
          produtoId:   item['produto_id'] as int,
          produtoNome: item['produto_nome'] as String,
          unidade:     item['unidade'] as String? ?? 'un',
          icone:       item['categoria_icone'] as String? ?? '📦',
        ),
      ),
    );
  }
}

class _CardUltimoPreco extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _CardUltimoPreco({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nome       = item['produto_nome'] as String;
    final unidade    = item['unidade'] as String? ?? 'un';
    final icone      = item['categoria_icone'] as String? ?? '📦';
    final local      = item['local_nome'] as String?;
    final data       = item['data'] as String;
    final atual      = (item['preco_unitario'] as num?)?.toDouble();
    final anterior   = (item['preco_anterior'] as num?)?.toDouble();

    final temAlerta  = atual != null && anterior != null && atual > anterior;
    final temBaixou  = atual != null && anterior != null && atual < anterior;
    final diff       = (atual != null && anterior != null)
        ? atual - anterior : null;
    final diffPct    = (diff != null && anterior! > 0)
        ? (diff / anterior * 100) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text(icone, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${formatarData(data)}${local != null ? ' · $local' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (atual != null)
                Text(
                  '${formatarMoeda(atual)}/$unidade',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: temAlerta ? AppTheme.danger
                        : temBaixou ? AppTheme.success : Colors.black87,
                  ),
                ),
              if (diff != null && diffPct != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: diff > 0 ? AppTheme.danger : AppTheme.success,
                  ),
                  Text(
                    '${diffPct.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: diff > 0 ? AppTheme.danger : AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
            ]),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ─── ABA 2: Gastos por Mês ────────────────────────────────────────────────────
class _AbaGastos extends StatefulWidget {
  const _AbaGastos();
  @override
  State<_AbaGastos> createState() => _AbaGastosState();
}

class _AbaGastosState extends State<_AbaGastos>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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

  String _nomeMes(String anoMes) {
    try {
      final partes = anoMes.split('-');
      final meses  = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                       'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
      return '${meses[int.parse(partes[1])]}/${partes[0].substring(2)}';
    } catch (_) { return anoMes; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_resumo.isEmpty) {
      return const Center(
        child: Text('Nenhum gasto registrado ainda',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // Dados para o gráfico (ordem cronológica)
    final cronologico = _resumo.reversed.toList();
    final valores = cronologico
        .map((m) => (m['total_gasto'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final maxValor = valores.reduce((a, b) => a > b ? a : b);
    final totalGeral = valores.fold(0.0, (s, v) => s + v);
    final mediaMensal = valores.isNotEmpty ? totalGeral / valores.length : 0.0;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Cards de resumo
          Row(children: [
            _StatCard(
              label: 'Total registrado',
              valor: formatarMoeda(totalGeral),
              icone: Icons.account_balance_wallet_outlined,
              cor: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Média mensal',
              valor: formatarMoeda(mediaMensal),
              icone: Icons.trending_flat,
              cor: AppTheme.success,
            ),
          ]),
          const SizedBox(height: 16),

          // Gráfico de barras
          const Text('GASTOS POR MÊS',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxValor * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final mes = _nomeMes(
                              cronologico[group.x]['mes'] as String);
                          return BarTooltipItem(
                            '$mes\n${formatarMoeda(rod.toY)}',
                            const TextStyle(
                                color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= cronologico.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _nomeMes(cronologico[idx]['mes'] as String),
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey),
                              ),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) => Text(
                            'R\$${value.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade100,
                        strokeWidth: 1,
                      ),
                    ),
                    barGroups: List.generate(cronologico.length, (i) {
                      final val = (cronologico[i]['total_gasto'] as num?)
                              ?.toDouble() ?? 0;
                      final isMesAtual = i == cronologico.length - 1;
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: val,
                          color: isMesAtual
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.45),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tabela detalhada
          const Text('DETALHAMENTO MENSAL',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ..._resumo.map((m) {
            final mes       = _nomeMes(m['mes'] as String);
            final gasto     = (m['total_gasto'] as num?)?.toDouble() ?? 0;
            final nProdutos = m['num_produtos'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(mes, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('$nProdutos produto${nProdutos != 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  Text(formatarMoeda(gasto),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primary)),
                ]),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, valor;
  final IconData icone;
  final Color cor;
  const _StatCard(
      {required this.label, required this.valor,
       required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
        ]),
        const SizedBox(height: 6),
        Text(valor,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
      ]),
    ),
  );
}

// ─── ABA 3: Por Produto (busca) ───────────────────────────────────────────────
class _AbaProdutos extends StatefulWidget {
  const _AbaProdutos();
  @override
  State<_AbaProdutos> createState() => _AbaProdutosState();
}

class _AbaProdutosState extends State<_AbaProdutos>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Produto> _produtos = [];
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final p = await DatabaseHelper.instance.getProdutos();
    setState(() => _produtos = p);
  }

  List<Produto> get _filtrados => _produtos
      .where((p) => _busca.isEmpty ||
          p.nome.toLowerCase().contains(_busca.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar produto...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _busca = v),
        ),
      ),
      Expanded(
        child: _filtrados.isEmpty
            ? const Center(child: Text('Nenhum produto encontrado',
                style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filtrados.length,
                itemBuilder: (_, i) {
                  final p = _filtrados[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: FotoOuEmoji(
                          fotoPath: p.fotoPath,
                          icone: p.categoriaIcone ?? '📦'),
                      title: Text(p.nome),
                      subtitle: Text(p.marca ?? ''),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _DetalheHistoricoScreen(
                            produtoId:   p.id!,
                            produtoNome: p.nome,
                            unidade:     p.unidade,
                            icone:       p.categoriaIcone ?? '📦',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ─── Tela de Detalhe com Gráfico ──────────────────────────────────────────────
class _DetalheHistoricoScreen extends StatefulWidget {
  final int produtoId;
  final String produtoNome, unidade, icone;
  const _DetalheHistoricoScreen({
    required this.produtoId,
    required this.produtoNome,
    required this.unidade,
    required this.icone,
  });

  @override
  State<_DetalheHistoricoScreen> createState() =>
      _DetalheHistoricoScreenState();
}

class _DetalheHistoricoScreenState extends State<_DetalheHistoricoScreen> {
  List<HistoricoCompra> _historico = [];
  List<HistoricoCompra> _graficoData = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final h = await DatabaseHelper.instance
        .getHistoricoProduto(widget.produtoId);
    final g = await DatabaseHelper.instance
        .getHistoricoProdutoGrafico(widget.produtoId);
    setState(() {
      _historico   = h;
      _graficoData = g;
      _carregando  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(widget.icone, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.produtoNome,
              style: const TextStyle(fontSize: 16))),
        ]),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _historico.isEmpty
              ? const Center(
                  child: Text('Nenhuma compra registrada',
                      style: TextStyle(color: Colors.grey)))
              : _conteudo(),
    );
  }

  Widget _conteudo() {
    final precos = _historico
        .where((h) => h.precoUnitario != null)
        .map((h) => h.precoUnitario!)
        .toList();
    final menorPreco = precos.isNotEmpty
        ? precos.reduce((a, b) => a < b ? a : b) : null;
    final maiorPreco = precos.isNotEmpty
        ? precos.reduce((a, b) => a > b ? a : b) : null;

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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Cards de stat
        if (precos.isNotEmpty) ...[
          Row(children: [
            _StatDetalhe(
                label: 'último preço',
                valor: formatarMoeda(_historico.first.precoUnitario ?? 0),
                sub: 'por ${widget.unidade}'),
            const SizedBox(width: 8),
            _StatDetalhe(
                label: 'menor preço',
                valor: formatarMoeda(menorPreco!),
                sub: _historico
                    .firstWhere((h) => h.precoUnitario == menorPreco)
                    .localNome ?? '',
                cor: AppTheme.success),
          ]),
          const SizedBox(height: 8),
        ],

        // Gráfico de evolução
        if (_graficoData.length >= 2) ...[
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text('EVOLUÇÃO DE PREÇO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.grey, letterSpacing: 0.5)),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final h = _graficoData[s.x.toInt()];
                          return LineTooltipItem(
                            '${formatarData(h.data)}\n${formatarMoeda(s.y)}/${widget.unidade}',
                            const TextStyle(
                                color: Colors.white, fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: _graficoData.length <= 6
                              ? 1
                              : (_graficoData.length / 4).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _graficoData.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              formatarData(_graficoData[idx].data)
                                  .substring(0, 5),
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) => Text(
                            formatarMoeda(value),
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          _graficoData.length,
                          (i) => FlSpot(i.toDouble(),
                              _graficoData[i].precoUnitario ?? 0),
                        ),
                        isCurved: true,
                        color: AppTheme.primary,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          getDotPainter: (spot, pct, bar, idx) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: AppTheme.primary,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primary.withOpacity(0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Comparativo de mercados
        if (rankingLocais.isNotEmpty) ...[
          const Text('COMPARATIVO DE MERCADOS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: rankingLocais.asMap().entries.map((e) {
                  final idx   = e.key;
                  final local = e.value.key;
                  final media = e.value.value;
                  final pct   = maiorPreco != null && maiorPreco > 0
                      ? media / maiorPreco : 1.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(child: Row(children: [
                          Text(local,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          if (idx == 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.successBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('menor preço',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.success)),
                            ),
                          ],
                        ])),
                        Text(
                          '${formatarMoeda(media)}/${widget.unidade}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: idx == 0
                                ? AppTheme.success : Colors.black87,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                              idx == 0 ? AppTheme.success : AppTheme.primary),
                          minHeight: 4,
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Linha do tempo
        const Text('LINHA DO TEMPO',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ..._historico.asMap().entries.map((e) {
          final h        = e.value;
          final anterior = e.key + 1 < _historico.length
              ? _historico[e.key + 1] : null;
          final diff = (h.precoUnitario != null &&
                  anterior?.precoUnitario != null)
              ? h.precoUnitario! - anterior!.precoUnitario! : null;
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
                  Expanded(child: Column(
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
                                fontSize: 13, color: AppTheme.primary)),
                        if (eMenor) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.successBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('menor preço',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.success)),
                          ),
                        ],
                        if (eMaior) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('mais caro',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.danger)),
                          ),
                        ],
                      ]),
                  ])),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    if (h.precoTotal != null)
                      Text(formatarMoeda(h.precoTotal!),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    if (h.precoUnitario != null)
                      Text(
                        '${formatarQtd(h.quantidadeComprada, widget.unidade)} · '
                        '${formatarMoeda(h.precoUnitario!)}/${widget.unidade}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                  ]),
                ]),
                if (diff != null) ...[
                  const Divider(height: 12),
                  Row(children: [
                    Icon(
                      diff > 0 ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: diff > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${diff > 0 ? '+' : ''}${formatarMoeda(diff)}/${widget.unidade} vs compra anterior',
                      style: TextStyle(
                          fontSize: 12,
                          color: diff > 0
                              ? AppTheme.danger : AppTheme.success),
                    ),
                  ]),
                ],
              ]),
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StatDetalhe extends StatelessWidget {
  final String label, valor, sub;
  final Color? cor;
  const _StatDetalhe(
      {required this.label, required this.valor,
       required this.sub, this.cor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(valor,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: cor ?? Colors.black87)),
        Text(sub,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    ),
  );
}
