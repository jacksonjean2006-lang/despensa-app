import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../models/local_compra.dart';
import '../models/historico_compra.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ─── Modelo local de item da compra avulsa ────────────────────────────────────
class _ItemAvulso {
  final int? produtoId;
  final String nome;
  final String unidade;
  final String? categoriaIcone;
  double quantidade;
  double? precoTotal;
  double? precoUnitario;

  _ItemAvulso({
    this.produtoId,
    required this.nome,
    required this.unidade,
    this.categoriaIcone,
    this.quantidade = 1,
    this.precoTotal,
    this.precoUnitario,
  });
}

// ─── Tela principal ───────────────────────────────────────────────────────────
class CompraAvulsaScreen extends StatefulWidget {
  const CompraAvulsaScreen({super.key});

  @override
  State<CompraAvulsaScreen> createState() => _CompraAvulsaScreenState();
}

class _CompraAvulsaScreenState extends State<CompraAvulsaScreen> {
  final List<_ItemAvulso> _itens = [];
  DateTime _dataCompra = DateTime.now();
  LocalCompra? _localSelecionado;
  List<LocalCompra> _locais = [];
  List<Produto> _produtos = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final locais   = await DatabaseHelper.instance.getLocais();
    final produtos = await DatabaseHelper.instance.getProdutos(apenasAtivos: true);
    setState(() {
      _locais   = locais;
      _produtos = produtos;
    });
  }

  double get _totalGeral => _itens.fold(0, (s, i) => s + (i.precoTotal ?? 0));

  // ─── Selecionar data ───────────────────────────────────────
  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataCompra,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dataCompra = picked);
  }

  // ─── Selecionar/criar local ────────────────────────────────
  Future<void> _selecionarLocal() async {
    final resultado = await showDialog<LocalCompra>(
      context: context,
      builder: (_) => _DialogLocal(
        locais: _locais,
        selecionado: _localSelecionado,
      ),
    );
    if (resultado != null) {
      setState(() => _localSelecionado = resultado);
      // atualiza lista de locais se foi criado um novo
      final locais = await DatabaseHelper.instance.getLocais();
      setState(() => _locais = locais);
    }
  }

  // ─── Adicionar produto do catálogo ─────────────────────────
  Future<void> _adicionarDoCatalogo() async {
    final produto = await showDialog<Produto>(
      context: context,
      builder: (_) => _DialogSelecionarProduto(
        produtos: _produtos,
        jaAdicionados: _itens.map((i) => i.produtoId).whereType<int>().toList(),
      ),
    );
    if (produto == null) return;

    final item = _ItemAvulso(
      produtoId:      produto.id,
      nome:           produto.nome,
      unidade:        produto.unidade,
      categoriaIcone: produto.categoriaIcone,
      quantidade:     1,
    );
    setState(() => _itens.add(item));
    _editarItem(item);
  }

  // ─── Adicionar item avulso (não cadastrado) ────────────────
  Future<void> _adicionarAvulso() async {
    final resultado = await showDialog<_ItemAvulso>(
      context: context,
      builder: (_) => const _DialogItemAvulso(),
    );
    if (resultado != null) setState(() => _itens.add(resultado));
  }

  // ─── Editar qtd/preço de um item ──────────────────────────
  Future<void> _editarItem(_ItemAvulso item) async {
    final resultado = await showDialog<_ItemAvulso>(
      context: context,
      builder: (_) => _DialogEditarItem(item: item),
    );
    if (resultado != null) {
      setState(() {
        item.quantidade    = resultado.quantidade;
        item.precoTotal    = resultado.precoTotal;
        item.precoUnitario = resultado.precoUnitario;
      });
    }
  }

  // ─── Finalizar compra ──────────────────────────────────────
  Future<void> _finalizar() async {
    if (_itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um item')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final dataStr = _dataCompra.toIso8601String();
      for (final item in _itens) {
        await DatabaseHelper.instance.registrarCompra(HistoricoCompra(
          produtoId:        item.produtoId,
          localId:          _localSelecionado?.id,
          quantidadeComprada: item.quantidade,
          precoTotal:       item.precoTotal,
          precoUnitario:    item.precoUnitario,
          data:             dataStr,
        ));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_itens.length} item${_itens.length > 1 ? 's' : ''} registrado${_itens.length > 1 ? 's' : ''}!'
            '${_itens.any((i) => i.produtoId != null) ? ' Estoque atualizado.' : ''}',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true); // true = houve alteração
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compra Avulsa'),
        actions: [
          if (_itens.isNotEmpty)
            TextButton.icon(
              onPressed: _salvando ? null : _finalizar,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Finalizar',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(children: [
        // ─── Cabeçalho: data + local ─────────────────────────
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            // Data
            Expanded(
              child: InkWell(
                onTap: _selecionarData,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Data da compra',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(formatarData(_dataCompra.toIso8601String()),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Local
            Expanded(
              child: InkWell(
                onTap: _selecionarLocal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _localSelecionado != null
                          ? AppTheme.primary
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _localSelecionado != null
                        ? AppTheme.primary.withOpacity(0.05)
                        : null,
                  ),
                  child: Row(children: [
                    Icon(Icons.store_outlined,
                        size: 18,
                        color: _localSelecionado != null
                            ? AppTheme.primary
                            : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Local',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          _localSelecionado?.nome ?? 'Selecionar...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _localSelecionado != null
                                ? AppTheme.primary
                                : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        const Divider(height: 1),

        // ─── Lista de itens ──────────────────────────────────
        Expanded(
          child: _itens.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Nenhum item adicionado',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 6),
                      Text('Use os botões abaixo para adicionar',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  itemCount: _itens.length,
                  itemBuilder: (_, i) {
                    final item = _itens[i];
                    return Dismissible(
                      key: ValueKey('avulso_$i\_${item.nome}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) =>
                          setState(() => _itens.removeAt(i)),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: item.categoriaIcone != null
                              ? Text(item.categoriaIcone!,
                                  style: const TextStyle(fontSize: 24))
                              : const Icon(Icons.shopping_bag_outlined,
                                  color: AppTheme.primary),
                          title: Text(item.nome,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            formatarQtd(item.quantidade, item.unidade) +
                                (item.precoTotal != null
                                    ? ' · ${formatarMoeda(item.precoTotal!)}'
                                    : ''),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            if (item.precoUnitario != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${formatarMoeda(item.precoUnitario!)}/${item.unidade}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editarItem(item),
                              color: Colors.grey,
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // ─── Rodapé: total + botões ──────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              )
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(children: [
            if (_itens.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('${_itens.length} item${_itens.length > 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey.shade600)),
                  Text(
                    'Total: ${_totalGeral > 0 ? formatarMoeda(_totalGeral) : '—'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _adicionarDoCatalogo,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Do catálogo'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _adicionarAvulso,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Item avulso'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                ),
              ),
            ]),
            if (_itens.isNotEmpty) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _salvando ? null : _finalizar,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Finalizar compra'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─── Dialog: selecionar produto do catálogo ───────────────────────────────────
class _DialogSelecionarProduto extends StatefulWidget {
  final List<Produto> produtos;
  final List<int> jaAdicionados;
  const _DialogSelecionarProduto(
      {required this.produtos, required this.jaAdicionados});

  @override
  State<_DialogSelecionarProduto> createState() =>
      _DialogSelecionarProdutoState();
}

class _DialogSelecionarProdutoState
    extends State<_DialogSelecionarProduto> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.produtos
        .where((p) =>
            !widget.jaAdicionados.contains(p.id) &&
            p.nome.toLowerCase().contains(_busca.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Selecionar produto'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text('Nenhum produto encontrado',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final p = filtrados[i];
                      return ListTile(
                        leading: FotoOuEmoji(
                            fotoPath: p.fotoPath,
                            icone: p.categoriaIcone ?? '📦'),
                        title: Text(p.nome),
                        subtitle: Text(
                            '${formatarQtd(p.estoqueAtual ?? 0, p.unidade)} em estoque'),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: AppTheme.primary),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}

// ─── Dialog: item avulso (não cadastrado) ────────────────────────────────────
class _DialogItemAvulso extends StatefulWidget {
  const _DialogItemAvulso();

  @override
  State<_DialogItemAvulso> createState() => _DialogItemAvulsoState();
}

class _DialogItemAvulsoState extends State<_DialogItemAvulso> {
  final _nomeCtrl  = TextEditingController();
  final _qtdCtrl   = TextEditingController(text: '1');
  final _precoCtrl = TextEditingController();
  String _unidade  = 'un';
  final _unidades  = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];

  double get _precoUnit {
    final total = double.tryParse(_precoCtrl.text) ?? 0;
    final qtd   = double.tryParse(_qtdCtrl.text) ?? 1;
    return qtd > 0 ? total / qtd : 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item avulso'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome do produto *'),
          autofocus: true,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _qtdCtrl,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _unidade,
            items: _unidades
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _unidade = v ?? 'un'),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _precoCtrl,
          decoration: const InputDecoration(
              labelText: 'Preço total (opcional)', prefixText: 'R\$ '),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        if (_precoUnit > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${formatarMoeda(_precoUnit)} por $_unidade',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_nomeCtrl.text.trim().isEmpty) return;
            final qtd   = double.tryParse(_qtdCtrl.text) ?? 1;
            final total = double.tryParse(_precoCtrl.text);
            Navigator.pop(
              context,
              _ItemAvulso(
                nome:          _nomeCtrl.text.trim(),
                unidade:       _unidade,
                quantidade:    qtd,
                precoTotal:    total,
                precoUnitario: total != null && qtd > 0 ? total / qtd : null,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

// ─── Dialog: editar item (qtd + preço) ───────────────────────────────────────
class _DialogEditarItem extends StatefulWidget {
  final _ItemAvulso item;
  const _DialogEditarItem({required this.item});

  @override
  State<_DialogEditarItem> createState() => _DialogEditarItemState();
}

class _DialogEditarItemState extends State<_DialogEditarItem> {
  late TextEditingController _qtdCtrl;
  late TextEditingController _precoCtrl;

  @override
  void initState() {
    super.initState();
    _qtdCtrl   = TextEditingController(
        text: widget.item.quantidade.toString());
    _precoCtrl = TextEditingController(
        text: widget.item.precoTotal?.toString() ?? '');
    _qtdCtrl.addListener(() => setState(() {}));
    _precoCtrl.addListener(() => setState(() {}));
  }

  double get _precoUnit {
    final total = double.tryParse(_precoCtrl.text) ?? 0;
    final qtd   = double.tryParse(_qtdCtrl.text) ?? 1;
    return qtd > 0 ? total / qtd : 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.nome),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _qtdCtrl,
          decoration: InputDecoration(
              labelText: 'Quantidade',
              suffixText: widget.item.unidade),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _precoCtrl,
          decoration: const InputDecoration(
              labelText: 'Preço total (opcional)',
              prefixText: 'R\$ '),
          keyboardType: TextInputType.number,
        ),
        if (_precoUnit > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${formatarMoeda(_precoUnit)} por ${widget.item.unidade}',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final qtd   = double.tryParse(_qtdCtrl.text) ?? 1;
            final total = double.tryParse(_precoCtrl.text);
            Navigator.pop(
              context,
              _ItemAvulso(
                produtoId:     widget.item.produtoId,
                nome:          widget.item.nome,
                unidade:       widget.item.unidade,
                categoriaIcone: widget.item.categoriaIcone,
                quantidade:    qtd,
                precoTotal:    total,
                precoUnitario: total != null && qtd > 0 ? total / qtd : null,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ─── Dialog: selecionar/criar local ──────────────────────────────────────────
class _DialogLocal extends StatefulWidget {
  final List<LocalCompra> locais;
  final LocalCompra? selecionado;
  const _DialogLocal({required this.locais, this.selecionado});

  @override
  State<_DialogLocal> createState() => _DialogLocalState();
}

class _DialogLocalState extends State<_DialogLocal> {
  late List<LocalCompra> _locais;
  LocalCompra? _selecionado;
  bool _adicionando = false;
  final _nomeCtrl = TextEditingController();
  final _refCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _locais     = List.from(widget.locais);
    _selecionado = widget.selecionado;
  }

  Future<void> _salvarNovo() async {
    if (_nomeCtrl.text.trim().isEmpty) return;
    final id = await DatabaseHelper.instance.salvarLocal(LocalCompra(
      nome:      _nomeCtrl.text.trim(),
      referencia: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      criadoEm:  DateTime.now().toIso8601String(),
    ));
    final novo = LocalCompra(
        id:        id,
        nome:      _nomeCtrl.text.trim(),
        referencia: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        criadoEm:  DateTime.now().toIso8601String());
    setState(() {
      _locais.add(novo);
      _selecionado = novo;
      _adicionando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Local da compra'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ..._locais.map((l) => RadioListTile<int>(
                  value: l.id!,
                  groupValue: _selecionado?.id,
                  title: Text(l.nome),
                  subtitle:
                      l.referencia != null ? Text(l.referencia!) : null,
                  onChanged: (v) => setState(() =>
                      _selecionado = _locais.firstWhere((x) => x.id == v)),
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                )),
            const Divider(),
            if (_adicionando) ...[
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome do mercado *'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                    labelText: 'Referência (opcional)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _salvarNovo,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white),
                child: const Text('Salvar'),
              ),
            ] else
              TextButton.icon(
                onPressed: () => setState(() => _adicionando = true),
                icon: const Icon(Icons.add),
                label: const Text('Novo mercado'),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _selecionado != null
              ? () => Navigator.pop(context, _selecionado)
              : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
