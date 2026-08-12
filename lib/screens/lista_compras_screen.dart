import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/lista_item.dart';
import '../models/local_compra.dart';
import '../models/historico_compra.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../utils/lista_compartilhar.dart';
import '../utils/licenca.dart';
import '../utils/busca_produto_codigo.dart';
import 'leitor_codigo_screen.dart';
import 'produtos_screen.dart';

class ListaComprasScreen extends StatefulWidget {
  final int? listaId;
  const ListaComprasScreen({super.key, this.listaId});
  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  int? _listaId;
  String _listaDesc = '';
  String? _finalizadoEm;
  double? _descontoSalvo;
  List<ListaItem> _itens = [];
  bool _carregando = true;

  bool get _readOnly => _finalizadoEm != null;

  final TextEditingController _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
    _buscaCtrl.addListener(() {
      setState(() => _busca = _buscaCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = widget.listaId != null
        ? await DatabaseHelper.instance.getListaPorId(widget.listaId!)
        : await DatabaseHelper.instance.getListaAberta();
    if (lista != null) {
      _listaId      = lista['id'] as int;
      _listaDesc    = lista['descricao'] as String;
      _finalizadoEm = lista['finalizado_em'] as String?;
      _descontoSalvo = (lista['desconto'] as num?)?.toDouble();
      _itens        = await DatabaseHelper.instance.getItensDaLista(_listaId!);
    }
    setState(() => _carregando = false);
  }

  int get _marcados => _itens.where((i) => i.marcado).length;

  // Total dos itens que têm preço registrado (lido direto do item, que já
  // está persistido no banco - não depende de estado em memória da tela)
  double get _totalCompra {
    double total = 0;
    for (final item in _itens) {
      if (item.precoTotal != null) total += item.precoTotal!;
    }
    return total;
  }

  int get _itensComPreco => _itens.where((i) => i.precoTotal != null).length;

  // Itens filtrados pela busca, já agrupados por categoria (a query do
  // banco já traz ordenado por categoria, então os grupos saem contíguos)
  List<ListaItem> get _itensFiltrados {
    if (_busca.isEmpty) return _itens;
    return _itens
        .where((i) => i.nomeExibicao.toLowerCase().contains(_busca))
        .toList();
  }

  List<MapEntry<String, List<ListaItem>>> get _gruposPorCategoria {
    final mapa = <String, List<ListaItem>>{};
    for (final item in _itensFiltrados) {
      final cat = item.categoriaNome ?? 'Outros';
      mapa.putIfAbsent(cat, () => []).add(item);
    }
    return mapa.entries.toList();
  }

  Future<void> _toggleMarcado(ListaItem item) async {
    if (_readOnly) return;
    await DatabaseHelper.instance.toggleMarcado(item.id!, !item.marcado);
    setState(() => item.marcado = !item.marcado);
  }

  Future<void> _removerItem(ListaItem item) async {
    if (_readOnly) return;
    await DatabaseHelper.instance.deletarItem(item.id!);
    setState(() => _itens.remove(item));
  }

  Future<void> _escanearItem() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const LeitorCodigoScreen(
              titulo: 'Escanear item da compra')),
    );
    if (codigo == null || !mounted) return;

    // Primeiro procura no cadastro (rápido, funciona offline)
    final resultado = await buscarProdutoPorCodigo(codigo);
    if (!mounted) return;

    if (resultado.encontrouNoCadastro) {
      final produto = resultado.produtoCadastrado!;
      final itemNaLista = _itens.where((i) => i.produtoId == produto.id).firstOrNull;

      if (itemNaLista != null) {
        // Já está nessa lista - abre direto o preço, sem precisar buscar
        // pela descrição
        _registrarPreco(itemNaLista);
        return;
      }

      // Está cadastrado mas não faz parte dessa lista ainda
      final add = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Produto não está nessa lista'),
          content: Text('"${produto.nome}" está cadastrado, mas não faz parte dessa lista. Adicionar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      );
      if (add == true && _listaId != null) {
        await DatabaseHelper.instance.adicionarItem(ListaItem(
          listaId:    _listaId!,
          produtoId:  produto.id,
          quantidade: 1,
          unidade:    produto.unidade,
        ));
        _carregar();
      }
      return;
    }

    // Não achou no cadastro - o helper já tentou a internet
    final nomeSugerido = resultado.nomeSugeridoInternet;
    final cadastrar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Produto não cadastrado'),
        content: Text(nomeSugerido != null
            ? 'Não está no seu cadastro, mas achamos "$nomeSugerido" pela internet. Cadastrar esse produto?'
            : 'Código "$codigo" não encontrado no cadastro nem na internet. Cadastrar mesmo assim?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
    if (cadastrar == true && mounted) {
      final produtosAtuais = await DatabaseHelper.instance.getProdutos();
      if (!Licenca.podeAdicionarProduto(produtosAtuais.length)) {
        if (mounted) {
          await Licenca.mostrarBloqueio(context,
              'A versão grátis permite cadastrar até ${Licenca.limiteProdutos} produtos. '
              'Ative sua licença pra cadastrar sem limites.');
        }
        return;
      }
      final cats = await DatabaseHelper.instance.getCategorias();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CadastroProdutoScreen(
              cats: cats, codigoBarrasInicial: codigo, nomeInicial: nomeSugerido)));
      _carregar();
    }
  }

  Future<void> _renomear() async {
    final ctrl = TextEditingController(text: _listaDesc);
    final novo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear lista'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novo != null && novo.isNotEmpty && _listaId != null) {
      await DatabaseHelper.instance.renomearLista(_listaId!, novo);
      setState(() => _listaDesc = novo);
    }
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

    final resultado = await showDialog<_PrecoEditado>(
      context: context,
      builder: (_) => _DialogRegistrarPreco(
        item:      item,
        locais:    locais,
        anterior: item.precoTotal != null
            ? _PrecoEditado(
                quantidade: item.quantidade,
                precoTotal: item.precoTotal,
                precoUnitario: item.precoUnitario,
                localId: item.localId,
                localNome: item.localNome,
              )
            : null,
      ),
    );

    if (resultado != null && item.id != null) {
      // Salva no banco IMEDIATAMENTE - antes o preço só ficava guardado
      // em uma variável da tela e se perdia quando o app recriava a tela
      // (ex: celular apagando a tela em segundo plano).
      await DatabaseHelper.instance.atualizarPrecoItem(
        item.id!,
        quantidade: resultado.quantidade,
        precoTotal: resultado.precoTotal,
        precoUnitario: resultado.precoUnitario,
        localId: resultado.localId,
      );
      setState(() {
        item.quantidade     = resultado.quantidade;
        item.precoTotal     = resultado.precoTotal;
        item.precoUnitario  = resultado.precoUnitario;
        item.localId        = resultado.localId;
        item.localNome      = resultado.localNome;
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

    // Desconto geral ao finalizar (ex: cupom, promoção do caixa) - reduz
    // proporcionalmente o valor gasto de cada item, sem mexer no preço
    // unitário salvo (que continua refletindo o preço real do produto).
    if (!mounted) return;
    final totalMarcados = _itens
        .where((i) => i.marcado && i.precoTotal != null)
        .fold<double>(0, (s, i) => s + i.precoTotal!);
    double descontoFinal = 0;
    if (totalMarcados > 0) {
      descontoFinal = await showDialog<double>(
            context: context,
            builder: (_) => _DialogDescontoFinal(totalAtual: totalMarcados),
          ) ??
          0;
    }
    final fator = (descontoFinal > 0 && totalMarcados > 0)
        ? (((totalMarcados - descontoFinal) / totalMarcados)
            .clamp(0, 1))
            .toDouble()
        : 1.0;

    final agora = DateTime.now().toIso8601String();
    for (final item in _itens.where((i) => i.marcado)) {
      // Lê o preço direto do item (já persistido no banco desde que foi
      // registrado no dialog) - não depende de nenhum estado em memória.
      // Registra tanto itens cadastrados (produtoId) quanto avulsos
      // (nomeAvulso) - antes só os cadastrados entravam no histórico, o
      // que fazia o total de "Gastos" ficar menor que o real.
      if (item.produtoId != null || item.nomeAvulso != null) {
        await DatabaseHelper.instance.registrarCompra(HistoricoCompra(
          listaId:            _listaId,
          produtoId:          item.produtoId,
          nomeAvulso:         item.produtoId == null ? item.nomeAvulso : null,
          localId:            item.localId ?? localIdGeral,
          quantidadeComprada: item.quantidade,
          precoTotal:         item.precoTotal != null
              ? item.precoTotal! * fator : null,
          precoUnitario:      item.precoUnitario,
          data:               agora,
        ));
      }
    }

    await DatabaseHelper.instance.finalizarLista(_listaId!, desconto: descontoFinal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(descontoFinal > 0
              ? 'Compra finalizada com desconto de ${formatarMoeda(descontoFinal)}!'
              : 'Compra finalizada! Estoque atualizado.'),
          backgroundColor: AppTheme.success,
        ),
      );
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
              'Vá em Início e toque em "Adicionar Lista de\nCompras" pra começar.',
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
          Text(
            _readOnly
                ? 'Finalizada — ${_itens.where((i) => i.marcado).length} itens comprados'
                : '${_marcados}/${_itens.length} marcados',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        actions: [
          if (!_readOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _renomear,
              tooltip: 'Renomear lista',
            ),
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
            child: Column(children: [
              Row(children: [
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
              if (_descontoSalvo != null && _descontoSalvo! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Spacer(),
                    Text(
                      'Desconto aplicado: - ${formatarMoeda(_descontoSalvo!)}  '
                      '·  Pago: ${formatarMoeda(_totalCompra - _descontoSalvo!)}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success),
                    ),
                  ]),
                ),
            ]),
          ),

        // Barra de busca
        if (_itens.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText:   'Buscar item...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _busca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _buscaCtrl.clear(),
                          )
                        : null,
                    isDense:     true,
                    filled:      true,
                    fillColor:   Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:   BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                  tooltip: 'Escanear código de barras',
                  onPressed: _escanearItem,
                ),
              ),
            ]),
          ),

        Expanded(
          child: _itens.isEmpty
              ? const Center(child: Text('Lista vazia'))
              : _itensFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum item encontrado'))
                  : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  children: _gruposPorCategoria.expand((grupo) {
                    final categoria = grupo.key;
                    final itensCategoria = grupo.value;
                    return [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                        child: Row(children: [
                          if (itensCategoria.first.categoriaIcone != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(itensCategoria.first.categoriaIcone!,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          Text(
                            categoria.toUpperCase(),
                            style: TextStyle(
                              fontSize:      11,
                              fontWeight:    FontWeight.bold,
                              letterSpacing: 0.5,
                              color:         Colors.grey.shade500,
                            ),
                          ),
                        ]),
                      ),
                      ...itensCategoria.map((item) {
                        return _ItemLista(
                          item:             item,
                          readOnly:         _readOnly,
                          onToggle:         () => _toggleMarcado(item),
                          onRemover:        () => _removerItem(item),
                          onRegistrarPreco: () => _registrarPreco(item),
                        );
                      }),
                    ];
                  }).toList(),
                ),
        ),

        // Botões rodapé (só quando a lista ainda pode ser editada)
        if (!_readOnly)
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

  void _compartilhar() async {
    // Busca marca/categoria dos produtos cadastrados presentes na lista,
    // pra ir tudo junto no dado estruturado (assim quem importar recebe
    // a lista com os mesmos detalhes, nao so o nome solto).
    final produtos = await DatabaseHelper.instance.getProdutos();
    final infoPorId = <int, Map<String, String?>>{};
    for (final p in produtos) {
      if (p.id != null) {
        infoPorId[p.id!] = {
          'marca': p.marca,
          'categoriaNome': p.categoriaNome,
          'categoriaIcone': p.categoriaIcone,
        };
      }
    }

    final texto = ListaCompartilhar.gerarTexto(
      descricao: _listaDesc,
      itens: _itens,
      infoProdutoPorId: infoPorId,
    );

    await Share.share(texto, subject: _listaDesc);
  }
}

// ─── Modelo em memória para preço/qtd editados ────────────────────────────────
class _PrecoEditado {
  final double quantidade;
  final double? precoTotal;
  final double? precoUnitario;
  final double? desconto;
  final int? localId;
  final String? localNome;

  const _PrecoEditado({
    required this.quantidade,
    this.precoTotal,
    this.precoUnitario,
    this.desconto,
    this.localId,
    this.localNome,
  });
}

// ─── CARD DE ITEM ─────────────────────────────────────────────────────────────
class _ItemLista extends StatelessWidget {
  final ListaItem item;
  final bool readOnly;
  final VoidCallback onToggle;
  final VoidCallback onRemover;
  final VoidCallback onRegistrarPreco;

  const _ItemLista({
    required this.item,
    this.readOnly = false,
    required this.onToggle,
    required this.onRemover,
    required this.onRegistrarPreco,
  });

  @override
  Widget build(BuildContext context) {
    // Lido direto do item - já persistido no banco, não é mais um estado
    // separado que pode se perder quando a tela é recriada.
    final qtd         = item.quantidade;
    final precoTotal  = item.precoTotal;
    final precoUnit   = item.precoUnitario;
    final localNome   = item.localNome;
    final temPreco    = precoTotal != null;

    return Dismissible(
      key: Key('item_${item.id}'),
      direction: readOnly ? DismissDirection.none : DismissDirection.endToStart,
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
                onPressed: readOnly ? null : onRegistrarPreco,
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
  late TextEditingController _descontoCtrl;
  late TextEditingController _qtdMinimaCtrl;
  bool _temPromo = false;
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
        text: widget.anterior?.precoUnitario?.toString() ?? '');
    _descontoCtrl = TextEditingController();
    _qtdMinimaCtrl = TextEditingController();
    _temPromo = widget.anterior?.desconto != null && widget.anterior!.desconto! > 0;
    _localId  = widget.anterior?.localId;
    _qtdCtrl.addListener(()  => setState(() {}));
    _precoCtrl.addListener(() => setState(() {}));
    _descontoCtrl.addListener(() => setState(() {}));
    _qtdMinimaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _precoCtrl.dispose();
    _descontoCtrl.dispose();
    _qtdMinimaCtrl.dispose();
    _novoLocalCtrl.dispose();
    _novoRefCtrl.dispose();
    super.dispose();
  }

  double get _qtd          => double.tryParse(_qtdCtrl.text)   ?? 1;
  double get _precoUnit    => double.tryParse(_precoCtrl.text) ?? 0;
  double get _subtotal     => _qtd > 0 ? _precoUnit * _qtd : 0;
  // Preço com desconto por unidade (o que aparece na etiqueta da promoção,
  // ex: "acima de 3un sai por R$28,50 cada") - o app calcula o desconto
  // sozinho a partir disso. Só vale se a checkbox de promoção estiver
  // marcada e a quantidade comprada bater a mínima exigida.
  double get _precoComDesconto => double.tryParse(_descontoCtrl.text) ?? 0;
  double get _qtdMinima     => double.tryParse(_qtdMinimaCtrl.text) ?? 0;
  bool   get _temDesconto   => _temPromo &&
      _precoComDesconto > 0 &&
      _precoComDesconto < _precoUnit &&
      _qtd >= _qtdMinima;
  double get _desconto     => _temDesconto ? _subtotal - (_precoComDesconto * _qtd) : 0;
  double get _precoTotal   => _temDesconto ? (_precoComDesconto * _qtd) : _subtotal;

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
    final unitario = double.tryParse(_precoCtrl.text);
    final qtd      = double.tryParse(_qtdCtrl.text) ?? widget.item.quantidade;
    final localNome = _locais
        .where((l) => l.id == _localId)
        .map((l) => l.nome)
        .firstOrNull;

    Navigator.pop(
      context,
      _PrecoEditado(
        quantidade:    qtd,
        precoTotal:    unitario != null ? _precoTotal : null,
        precoUnitario: unitario,
        desconto:      _desconto > 0 ? _desconto : null,
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

          // Preço unitário
          TextField(
            controller:   _precoCtrl,
            decoration:   InputDecoration(
                labelText: 'Preço unitário (R\$)',
                prefixText: 'R\$ ',
                suffixText: '/${widget.item.unidade}'),
            keyboardType: TextInputType.number,
          ),

          // Preço total calculado (com desconto se houver)
          if (_precoTotal > 0 || _desconto > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  if (_desconto > 0) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Text('Subtotal:',
                          style: TextStyle(color: Colors.grey.shade600,
                              fontSize: 13)),
                      Text(formatarMoeda(_subtotal),
                          style: TextStyle(color: Colors.grey.shade600,
                              fontSize: 13)),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Text('Desconto:',
                          style: TextStyle(color: Colors.grey.shade600,
                              fontSize: 13)),
                      Text('- ${formatarMoeda(_desconto)}',
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 13)),
                    ]),
                    const Divider(height: 12),
                  ],
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Text('Preço total:',
                        style: TextStyle(color: Colors.grey.shade600,
                            fontSize: 13)),
                    Text(
                      formatarMoeda(_precoTotal),
                      style: const TextStyle(
                          color:      AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize:   15),
                    ),
                  ]),
                ]),
              ),
            ),

          const SizedBox(height: 4),
          // Checkbox: só mostra os campos de promoção por quantidade se
          // o produto realmente tiver esse tipo de desconto
          CheckboxListTile(
            value: _temPromo,
            onChanged: (v) => setState(() {
              _temPromo = v ?? false;
              if (!_temPromo) {
                _descontoCtrl.clear();
                _qtdMinimaCtrl.clear();
              }
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Tem desconto por quantidade',
                style: TextStyle(fontSize: 13.5)),
          ),
          if (_temPromo) ...[
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qtdMinimaCtrl,
                  decoration: InputDecoration(
                      labelText: 'Qtd mínima',
                      suffixText: widget.item.unidade,
                      isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _descontoCtrl,
                  decoration: InputDecoration(
                      labelText: 'Preço com desconto',
                      prefixText: 'R\$ ',
                      suffixText: '/${widget.item.unidade}',
                      isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ex: a partir de ${_qtdMinima > 0 ? formatarQtd(_qtdMinima, widget.item.unidade) : "X"}, cada uma sai por esse valor',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],

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

// ─── DIALOG DESCONTO AO FINALIZAR ──────────────────────────────────────
class _DialogDescontoFinal extends StatefulWidget {
  final double totalAtual;
  const _DialogDescontoFinal({required this.totalAtual});
  @override
  State<_DialogDescontoFinal> createState() => _DialogDescontoFinalState();
}

class _DialogDescontoFinalState extends State<_DialogDescontoFinal> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _desconto => double.tryParse(_ctrl.text) ?? 0;
  double get _totalFinal =>
      (widget.totalAtual - _desconto) < 0 ? 0 : (widget.totalAtual - _desconto);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Desconto na compra'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ganhou algum desconto no caixa? (opcional)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        TextField(
          controller:   _ctrl,
          autofocus:    true,
          decoration:   const InputDecoration(
              labelText: 'Desconto total (R\$)', prefixText: 'R\$ '),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total final:', style: TextStyle(fontWeight: FontWeight.w500)),
          Text(formatarMoeda(_totalFinal),
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text('Sem desconto')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _desconto),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Confirmar'),
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
