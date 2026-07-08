import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LevantamentoScreen extends StatefulWidget {
  const LevantamentoScreen({super.key});
  @override
  State<LevantamentoScreen> createState() => _LevantamentoScreenState();
}

class _LevantamentoScreenState extends State<LevantamentoScreen> {
  List<Produto> _produtos = [];
  final Map<int, TextEditingController> _ctrls = {};
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DatabaseHelper.instance.getProdutos(apenasAtivos: true);
    setState(() {
      _produtos = lista;
      for (final p in lista) {
        _ctrls[p.id!] = TextEditingController(
          text: (p.estoqueAtual ?? 0) > 0
              ? (p.estoqueAtual!).toStringAsFixed(
                  p.estoqueAtual! == p.estoqueAtual!.truncateToDouble() ? 0 : 1)
              : '',
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _gerarLista() async {
    setState(() => _salvando = true);
    // Salva todos os estoques informados
    for (final p in _produtos) {
      final v = double.tryParse(_ctrls[p.id!]?.text ?? '') ?? 0;
      await DatabaseHelper.instance.atualizarEstoque(p.id!, v);
    }
    // Verifica se já existe lista aberta
    var lista = await DatabaseHelper.instance.getListaAberta();
    int listaId;
    if (lista == null) {
      final mes = _mesAtual();
      listaId = await DatabaseHelper.instance.criarLista('Compras de $mes');
      await DatabaseHelper.instance.gerarListaAutomatica(listaId);
    } else {
      listaId = lista['id'] as int;
    }
    setState(() => _salvando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lista gerada com sucesso!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  String _mesAtual() {
    final meses = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final d = DateTime.now();
    return '${meses[d.month]}/${d.year}';
  }

  Map<String, List<Produto>> get _porCategoria {
    final map = <String, List<Produto>>{};
    for (final p in _produtos) {
      final cat = p.categoriaNome ?? 'Outros';
      map.putIfAbsent(cat, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Levantamento de Estoque')),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F1FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB5D4F4)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Color(0xFF185FA5), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Percorra a despensa e informe quanto tem de cada produto agora.',
                style: TextStyle(color: Color(0xFF0C447C), fontSize: 13),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _produtos.isEmpty
              ? const Center(child: Text('Nenhum produto cadastrado'))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final entry in _porCategoria.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(entry.key.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5)),
                      ),
                      ...entry.value.map((p) => _ItemLevantamento(
                          produto: p, ctrl: _ctrls[p.id!]!)),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _salvando ? null : _gerarLista,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(_salvando ? 'Gerando...' : 'Gerar Lista de Compras'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ItemLevantamento extends StatefulWidget {
  final Produto produto;
  final TextEditingController ctrl;
  const _ItemLevantamento({required this.produto, required this.ctrl});
  @override
  State<_ItemLevantamento> createState() => _ItemLevantamentoState();
}

class _ItemLevantamentoState extends State<_ItemLevantamento> {
  double get _atual => double.tryParse(widget.ctrl.text) ?? 0;
  double get _comprar {
    final d = widget.produto.consumoMensal - _atual;
    return d > 0 ? d : 0;
  }

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            FotoOuEmoji(
                fotoPath: widget.produto.fotoPath,
                icone: widget.produto.categoriaIcone,
                size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.produto.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'consumo: ${formatarQtd(widget.produto.consumoMensal, widget.produto.unidade)}/mês',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: widget.ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: widget.produto.unidade,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _comprar > 0
                  ? Text(
                      'comprar: ${formatarQtd(_comprar, widget.produto.unidade)}',
                      style: TextStyle(
                          fontSize: 13,
                          color: _comprar >= widget.produto.consumoMensal * 0.6
                              ? AppTheme.danger
                              : AppTheme.warning),
                      textAlign: TextAlign.right,
                    )
                  : const Text('estoque ok ✓',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.success),
                      textAlign: TextAlign.right),
            ),
          ]),
        ]),
      ),
    );
  }
}
