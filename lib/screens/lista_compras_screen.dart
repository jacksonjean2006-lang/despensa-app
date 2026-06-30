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
    } else {
      _listaId = null;
      _itens = [];
    }
    setState(() => _carregando = false);
  }

  int get _marcados => _itens.where((i) => i.marcado).length;

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
        item.quantidade = resultado.quantidade;
      });
    }
  }

  Future<void> _finalizarCompra() async {
    if (_listaId == null) return;

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

      // REGISTRA TUDO NO HISTÓRICO (Produtos e Avulsos)
      await DatabaseHelper.instance.registrarCompra(HistoricoCompra(
        listaId:            _listaId,
        produtoId:          item.produtoId,
        nomeAvulso:         item.nomeAvulso,
        localId:            editado?.localId ?? localIdGeral,
        quantidadeComprada: editado?.quantidade ?? item.quantidade,
        precoTotal:         editado?.precoTotal,
        precoUnitario:      editado?.precoUnitario,
        data:               agora,
      ));
    }

    await DatabaseHelper.instance.finalizarLista(_listaId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compra finalizada! Histórico salvo e estoque atualizado.'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() {
        _precosEditados.clear();
        _listaId = null;
      });
      _carregar();
    }
  }

  void _compartilhar() {
    // Lógica de compartilhar como texto (WhatsApp)
    String texto = "*🛒 $_listaDesc*\n\n";
    for (var item in _itens) {
      String status = item.marcado ? "✅" : "⬜";
      String nome = item.produtoNome ?? item.nomeAvulso ?? "Item";
      texto += "$status $nome (${formatarQtd(item.quantidade, item.unidade)})\n";
    }
    // Aqui usaria o package share_plus no Flutter real
    print(texto);
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
        LinearProgressIndicator(
          value:           _itens.isEmpty ? 0 : _marcados / _itens.length,
          backgroundColor: Colors.grey.shade200,
          valueColor:      const AlwaysStoppedAnimation(AppTheme.success),
          minHeight:       4,
        ),
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
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            onPressed: _adicionarAvulso,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            heroTag: 'add_avulso',
            child: const Icon(Icons.add_shopping_cart),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _marcados > 0 ? _finalizarCompra : null,
            backgroundColor: _marcados > 0 ? AppTheme.success : Colors.grey,
            icon: const Icon(Icons.check),
            label: const Text('Finalizar Compra'),
            heroTag: 'finish_list',
          ),
        ],
      ),
    );
  }
}

// Classes auxiliares e Dialogs permanecem as mesmas do arquivo original...
// (Mantendo a estrutura para não quebrar o código existente)
class _PrecoEditado {
  final double quantidade;
  final double? precoTotal;
  final double? precoUnitario;
  final int? localId;
  _PrecoEditado({required this.quantidade, this.precoTotal, this.precoUnitario, this.localId});
}

class _ItemLista extends StatelessWidget {
  final ListaItem item;
  final _PrecoEditado? precoEditado;
  final VoidCallback onToggle, onRemover, onRegistrarPreco;
  const _ItemLista({required this.item, this.precoEditado, required this.onToggle, required this.onRemover, required this.onRegistrarPreco});

  @override
  Widget build(BuildContext context) {
    final nome = item.produtoNome ?? item.nomeAvulso ?? 'Item';
    final preco = precoEditado?.precoTotal;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(value: item.marcado, onChanged: (_) => onToggle()),
        title: Text(nome, style: TextStyle(decoration: item.marcado ? TextDecoration.lineThrough : null)),
        subtitle: Text('${formatarQtd(item.quantidade, item.unidade)}${preco != null ? ' · ${formatarMoeda(preco)}' : ''}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(Icons.sell_outlined, color: preco != null ? AppTheme.success : Colors.grey), onPressed: onRegistrarPreco),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onRemover),
        ]),
      ),
    );
  }
}
// (Omitindo o restante dos dialogs para brevidade, mas eles devem ser mantidos no arquivo final)
