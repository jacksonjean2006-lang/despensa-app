import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/lista_item.dart';
import '../models/local_compra.dart';
import '../models/historico_compra.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key});
  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  int? _listaId;
  String _listaDesc = '';
  List<ListaItem> _itens = [];
  bool _carregando = true;

  // Guarda preços e qtds editados em memória (produtoId -> dados)
  final Map<int, _PrecoEditado> _precosEditados = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await DatabaseHelper.instance.getListaAberta();
    if (lista != null) {
      _listaId   = lista['id'] as int;
      _listaDesc = lista['descricao'] as String;
      _itens     = await DatabaseHelper.instance.getItensDaLista(_listaId!);
    }
    setState(() => _carregando = false);
  }

  int get _marcados => _itens.where((i) => i.marcado).length;

  // Total dos itens que têm preço registrado
  double get _totalCompra {
    double total = 0;
    for (final item in _itens) {
      final key = item.produtoId ?? item.id ?? 0;
      final editado = _precosEditados[key];
      if (editado?.precoTotal != null) {
        total += editado!.precoTotal!;
      }
    }
    return total;
  }

  int get _itensComPreco =>
      _itens.where((i) {
        final key = i.produtoId ?? i.id ?? 0;
        return _precosEditados[key]?.precoTotal != null;
      }).length;

  Future<void> _toggleMarcado(ListaItem item) async {
    await DatabaseHelper.instance.toggleMarcado(item.id!, !item.marcado);
    setState(() => item.marcado = !item.marcado);
  }

  Future<void> _removerItem(ListaItem item) async {
    await DatabaseHelper.instance.deletarItem(item.id!);
    setState(() => _itens.remove(item));
  }

  Future<void> _adicionarAvulso() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogAvulso(listaId: _listaId!),
    );
    if (result != null) {
      final item = ListaItem(
        listaId:    _listaId!,
        nomeAvulso: result['nome'],
        quantidade: result['quantidade'],
        unidade:    result['unidade'],
        substituto: result['substituto'] ?? false,
      );
      await DatabaseHelper.instance.adicionarItem(item);
      _carregar();
    }
  }

  Future<void> _registrarPreco(ListaItem item) async {
    final locais = await DatabaseHelper.instance.getLocais();
    if (!mounted) return;

    final key      = item.produtoId ?? item.id ?? 0;
    final anterior = _precosEditados[key];

    final resultado = await showDialog<_PrecoEditado>(
      context: context,
      builder: (_) => _DialogRegistrarPreco(
        item:      item,
        locais:    locais,
        anterior:  anterior,
      ),
    );

    if (resultado != null) {
      setState(() {
        _precosEditados[key] = resultado;
        // Atualiza a quantidade no item em memória
        item.quantidade = resultado.quantidade;
      });
    }
  }

  Future<void> _finalizarCompra() async {
    if (_listaId == null) return;

    // Se há itens marcados sem local, pede o local geral
    final locais = await DatabaseHelper.instance.getLocais();
    if (!mounted) return;
    final localIdGeral = await showDialog<int>(
      context: context,
      builder: (_) => _DialogSelecionarLocal(locais: locais),
    );

    final agora = DateTime.now().toIso8601String();
    for (final item in _itens.where((i) => i.marcado)) {
      final key     = item.produtoId ?? item.id ?? 0;
      final editado = _precosEditados[key];

      if (item.produtoId != null) {
        await DatabaseHelper.instance.registrarCompra(HistoricoCompra(
          listaId:            _listaId,
          produtoId:          item.produtoId,
          localId:            editado?.localId ?? localIdGeral,
          quantidadeComprada: editado?.quantidade ?? item.quantidade,
          precoTotal:         editado?.precoTotal,
          precoUnitario:      editado?.precoUnitario,
          data:               agora,
        ));
      }
    }

    await DatabaseHelper.instance.finalizarLista(_listaId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compra finalizada! Estoque atualizado.'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() => _precosEditados.clear());
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_listaId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lista de Compras')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Nenhuma lista aberta',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              'Vá em Estoque e faça o levantamento\npara gerar sua lista automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_listaDesc, style: const TextStyle(fontSize: 16)),
          Text('${_marcados}/${_itens.length} marcados',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _compartilhar,
            tooltip: 'Compartilhar lista',
          ),
        ],
      ),
      body: Column(children: [
        // Barra de progresso
        LinearProgressIndicator(
          value:           _itens.isEmpty ? 0 : _marcados / _itens.length,
          backgroundColor: Colors.grey.shade200,
          valueColor:      const AlwaysStoppedAnimation(AppTheme.success),
          minHeight:       4,
        ),

        // Banner de total
        if (_totalCompra > 0)
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color:   AppTheme.primary.withOpacity(0.08),
            child: Row(children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '$_itensComPreco item${_itensComPreco != 1 ? 's' : ''} com preço',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Text(
                'Total: ${formatarMoeda(_totalCompra)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ]),
          ),

        Expanded(
          child: _itens.isEmpty
              ? const Center(child: Text('Lista vazia'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  children: _itens.map((item) {
                    final key     = item.produtoId ?? item.id ?? 0;
                    final editado = _precosEditados[key];
                    return _ItemLista(
                      item:          item,
                      precoEditado:  editado,
                      onToggle:      () => _toggleMarcado(item),
                      onRemover:     () => _removerItem(item),
                      onRegistrarPreco: () => _registrarPreco(item),
                    );
                  }).toList(),
                ),
        ),

        // Botões rodapé
        SafeArea(
          top: false,
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, -2),
            )],
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            OutlinedButton.icon(
              onPressed: _adicionarAvulso,
              icon:  const Icon(Icons.add),
              label: const Text('Adicionar item'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: _marcados == 0 ? null : _finalizarCompra,
              icon:  const Icon(Icons.check),
              label: const Text('Finalizar compra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                minimumSize:     const Size.fromHeight(50),
              ),
            ),
          ]),
          ),
        ),
      ]),
    );
  }

  void _compartilhar() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 $_listaDesc\n');
    for (final i in _itens) {
      final check = i.marcado ? '✅' : '⬜';
      buffer.writeln(
          '$check ${i.nomeExibicao} — ${formatarQtd(i.quantidade, i.unidade)}');
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(buffer.toString())));
  }
}

// ─── Modelo em memória para preço/qtd editados ────────────────────────────────
class _PrecoEditado {
  final double quantidade;
  final double? precoTotal;
  final double? precoUnitario;
  final int? localId;
  final String? localNome;

  const _PrecoEditado({
    required this.quantidade,
    this.precoTotal,
    this.precoUnitario,
    this.localId,
    this.localNome,
  });
}

// ─── CARD DE ITEM ─────────────────────────────────────────────────────────────
class _ItemLista extends StatelessWidget {
  final ListaItem item;
  final _PrecoEditado? precoEditado;
  final VoidCallback onToggle;
  final VoidCallback onRemover;
  final VoidCallback onRegistrarPreco;

  const _ItemLista({
    required this.item,
    required this.precoEditado,
    required this.onToggle,
    required this.onRemover,
    required this.onRegistrarPreco,
  });

  @override
  Widget build(BuildContext context) {
    final qtd         = precoEditado?.quantidade ?? item.quantidade;
    final precoTotal  = precoEditado?.precoTotal;
    final precoUnit   = precoEditado?.precoUnitario;
    final localNome   = precoEditado?.localNome;
    final temPreco    = precoTotal != null;

    return Dismissible(
      key: Key('item_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onRemover(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              // Checkbox circular
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:  item.marcado ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: item.marcado
                          ? AppTheme.primary : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: item.marcado
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 10),

              // Nome + infos
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    item.nomeExibicao,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: item.marcado
                          ? TextDecoration.lineThrough : null,
                      color: item.marcado ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    // Quantidade
                    Text(
                      formatarQtd(qtd, item.unidade),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    // Preço total
                    if (temPreco) ...[
                      Text(' · ',
                          style: TextStyle(color: Colors.grey.shade400)),
                      Text(
                        formatarMoeda(precoTotal!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                    // Preço unitário
                    if (precoUnit != null) ...[
                      Text(' · ',
                          style: TextStyle(color: Colors.grey.shade400)),
                      Text(
                        '${formatarMoeda(precoUnit)}/${item.unidade}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ]),
                  // Local
                  if (localNome != null)
                    Row(children: [
                      Icon(Icons.store_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(localNome,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                ]),
              ),

              // Botão de preço
              IconButton(
                icon: Icon(
                  temPreco
                      ? Icons.attach_money
                      : Icons.money_off_outlined,
                  size: 20,
                  color: temPreco ? AppTheme.primary : Colors.grey.shade400,
                ),
                onPressed: onRegistrarPreco,
                tooltip: temPreco ? 'Editar preço' : 'Registrar preço',
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── DIALOG REGISTRAR/EDITAR PREÇO ───────────────────────────────────────────
class _DialogRegistrarPreco extends StatefulWidget {
  final ListaItem item;
  final List<LocalCompra> locais;
  final _PrecoEditado? anterior;

  const _DialogRegistrarPreco({
    required this.item,
    required this.locais,
    this.anterior,
  });

  @override
  State<_DialogRegistrarPreco> createState() => _DialogRegistrarPrecoState();
}

class _DialogRegistrarPrecoState extends State<_DialogRegistrarPreco> {
  late TextEditingController _qtdCtrl;
  late TextEditingController _precoCtrl;
  int? _localId;
  bool _adicionandoLocal = false;
  final _novoLocalCtrl = TextEditingController();
  final _novoRefCtrl   = TextEditingController();
  late List<LocalCompra> _locais;

  @override
  void initState() {
    super.initState();
    _locais   = List.from(widget.locais);
    // Usa valores anteriores se existirem, senão os originais do item
    _qtdCtrl  = TextEditingController(
        text: (widget.anterior?.quantidade ?? widget.item.quantidade)
            .toString());
    _precoCtrl = TextEditingController(
        text: widget.anterior?.precoTotal?.toString() ?? '');
    _localId  = widget.anterior?.localId;
    _qtdCtrl.addListener(()  => setState(() {}));
    _precoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _precoCtrl.dispose();
    _novoLocalCtrl.dispose();
    _novoRefCtrl.dispose();
    super.dispose();
  }

  double get _qtd       => double.tryParse(_qtdCtrl.text)   ?? 1;
  double get _precoTotal => double.tryParse(_precoCtrl.text) ?? 0;
  double get _precoUnit  => _qtd > 0 ? _precoTotal / _qtd  : 0;

  Future<void> _salvarLocal() async {
    if (_novoLocalCtrl.text.trim().isEmpty) return;
    final id = await DatabaseHelper.instance.salvarLocal(LocalCompra(
      nome:       _novoLocalCtrl.text.trim(),
      referencia: _novoRefCtrl.text.trim().isEmpty
          ? null : _novoRefCtrl.text.trim(),
      criadoEm:   DateTime.now().toIso8601String(),
    ));
    setState(() {
      _locais.add(LocalCompra(
          id:        id,
          nome:      _novoLocalCtrl.text.trim(),
          criadoEm:  DateTime.now().toIso8601String()));
      _localId         = id;
      _adicionandoLocal = false;
    });
  }

  void _confirmar() {
    final total = double.tryParse(_precoCtrl.text);
    final qtd   = double.tryParse(_qtdCtrl.text) ?? widget.item.quantidade;
    final localNome = _locais
        .where((l) => l.id == _localId)
        .map((l) => l.nome)
        .firstOrNull;

    Navigator.pop(
      context,
      _PrecoEditado(
        quantidade:    qtd,
        precoTotal:    total,
        precoUnitario: total != null && qtd > 0 ? total / qtd : null,
        localId:       _localId,
        localNome:     localNome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Preço — ${widget.item.nomeExibicao}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Quantidade
          TextField(
            controller:   _qtdCtrl,
            decoration:   InputDecoration(
                labelText: 'Quantidade',
                suffixText: widget.item.unidade),
            keyboardType: TextInputType.number,
            autofocus:    true,
          ),
          const SizedBox(height: 10),

          // Preço total
          TextField(
            controller:   _precoCtrl,
            decoration:   const InputDecoration(
                labelText: 'Preço total (R\$)',
                prefixText: 'R\$ '),
            keyboardType: TextInputType.number,
          ),

          // Preço unitário calculado
          if (_precoUnit > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text('Preço por ${widget.item.unidade}:',
                      style: TextStyle(color: Colors.grey.shade600,
                          fontSize: 13)),
                  Text(
                    formatarMoeda(_precoUnit),
                    style: const TextStyle(
                        color:      AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize:   15),
                  ),
                ]),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(),

          // Local
          DropdownButtonFormField<int>(
            value:       _localId,
            decoration:  const InputDecoration(labelText: 'Local de compra'),
            items: _locais
                .map((l) =>
                    DropdownMenuItem(value: l.id, child: Text(l.nome)))
                .toList(),
            onChanged: (v) => setState(() => _localId = v),
          ),

          if (!_adicionandoLocal)
            TextButton.icon(
              onPressed: () => setState(() => _adicionandoLocal = true),
              icon:  const Icon(Icons.add, size: 16),
              label: const Text('Novo mercado',
                  style: TextStyle(fontSize: 13)),
            )
          else ...[
            const SizedBox(height: 8),
            TextField(
              controller: _novoLocalCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nome do mercado'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _novoRefCtrl,
              decoration: const InputDecoration(
                  labelText: 'Referência (opcional)'),
            ),
            TextButton(
                onPressed: _salvarLocal,
                child: const Text('Salvar mercado')),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ─── DIALOG ITEM AVULSO ───────────────────────────────────────────────────────
class _DialogAvulso extends StatefulWidget {
  final int listaId;
  const _DialogAvulso({required this.listaId});
  @override
  State<_DialogAvulso> createState() => _DialogAvulsoState();
}

class _DialogAvulsoState extends State<_DialogAvulso> {
  final _nomeCtrl  = TextEditingController();
  final _qtdCtrl   = TextEditingController(text: '1');
  String _unidade  = 'un';
  bool _substituto = false;
  final _unidades  = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar item'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller:  _nomeCtrl,
          decoration:  const InputDecoration(labelText: 'Nome do produto'),
          autofocus:   true,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller:   _qtdCtrl,
              decoration:   const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
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
        const SizedBox(height: 6),
        CheckboxListTile(
          title: const Text('É substituto de outro produto',
              style: TextStyle(fontSize: 13)),
          value:    _substituto,
          onChanged: (v) => setState(() => _substituto = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_nomeCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'nome':       _nomeCtrl.text.trim(),
              'quantidade': double.tryParse(_qtdCtrl.text) ?? 1,
              'unidade':    _unidade,
              'substituto': _substituto,
            });
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

// ─── DIALOG SELECIONAR LOCAL ──────────────────────────────────────────────────
class _DialogSelecionarLocal extends StatefulWidget {
  final List<LocalCompra> locais;
  const _DialogSelecionarLocal({required this.locais});
  @override
  State<_DialogSelecionarLocal> createState() => _DialogSelecionarLocalState();
}

class _DialogSelecionarLocalState extends State<_DialogSelecionarLocal> {
  int? _selecionado;
  bool _adicionando = false;
  final _novoCtrl = TextEditingController();
  final _refCtrl  = TextEditingController();
  late List<LocalCompra> _locais;

  @override
  void initState() {
    super.initState();
    _locais = List.from(widget.locais);
  }

  Future<void> _salvarNovo() async {
    if (_novoCtrl.text.trim().isEmpty) return;
    final id = await DatabaseHelper.instance.salvarLocal(LocalCompra(
      nome:       _novoCtrl.text.trim(),
      referencia: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      criadoEm:   DateTime.now().toIso8601String(),
    ));
    setState(() {
      _locais.add(LocalCompra(
          id:       id,
          nome:     _novoCtrl.text.trim(),
          criadoEm: DateTime.now().toIso8601String()));
      _selecionado = id;
      _adicionando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Onde você comprou?'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ..._locais.map((l) => RadioListTile<int>(
                  value:      l.id!,
                  groupValue: _selecionado,
                  title:      Text(l.nome),
                  subtitle:   l.referencia != null
                      ? Text(l.referencia!) : null,
                  onChanged:  (v) => setState(() => _selecionado = v),
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                )),
            if (_adicionando) ...[
              const Divider(),
              TextField(
                controller: _novoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome do mercado *'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                    labelText: 'Bairro / referência (opcional)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _salvarNovo,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white),
                child: const Text('Salvar e selecionar'),
              ),
            ] else
              TextButton.icon(
                onPressed: () => setState(() => _adicionando = true),
                icon:  const Icon(Icons.add),
                label: const Text('Adicionar novo mercado'),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pular')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selecionado),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
