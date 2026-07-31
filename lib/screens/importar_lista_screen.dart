import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import '../theme.dart';
import '../utils/lista_compartilhar.dart';
import 'lista_compras_screen.dart';

/// Tela pra importar uma lista de compras enviada por outra pessoa
/// (ex: a esposa gera a lista no app dela e manda por WhatsApp).
///
/// O usuário cola o texto recebido; o app extrai o bloco de dados
/// estruturado, mostra uma prévia dos itens e, pra cada item que não
/// existe no cadastro local, deixa escolher se quer cadastrar o produto
/// agora ou manter só como item avulso desta lista.
class ImportarListaScreen extends StatefulWidget {
  const ImportarListaScreen({super.key});
  @override
  State<ImportarListaScreen> createState() => _ImportarListaScreenState();
}

class _ImportarListaScreenState extends State<ImportarListaScreen> {
  final _textoCtrl = TextEditingController();
  Map<String, dynamic>? _dados;
  List<_ItemImportado> _itens = [];
  bool _processando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Sem isso, colar o texto não atualizava a tela e o botão "Ler lista"
    // continuava desabilitado mesmo com o texto colado.
    _textoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _processarTexto() async {
    setState(() {
      _erro = null;
      _processando = true;
    });

    final dados = ListaCompartilhar.extrairDados(_textoCtrl.text);
    if (dados == null) {
      setState(() {
        _erro = 'Não encontrei uma lista válida nesse texto.\n'
            'Confirme que colou a mensagem inteira, do jeito que foi enviada.';
        _processando = false;
        _dados = null;
        _itens = [];
      });
      return;
    }

    final itensJson = (dados['itens'] as List).cast<Map<String, dynamic>>();
    final itens = <_ItemImportado>[];
    for (final it in itensJson) {
      final nome = it['nome'] as String;
      final existente = await DatabaseHelper.instance.buscarProdutoPorNome(nome);
      itens.add(_ItemImportado(
        nome: nome,
        marca: it['marca'] as String?,
        categoriaNome: it['categoria'] as String?,
        categoriaIcone: it['categoriaIcone'] as String? ?? '📦',
        quantidade: (it['quantidade'] as num).toDouble(),
        unidade: it['unidade'] as String? ?? 'un',
        marcado: it['marcado'] as bool? ?? false,
        substituto: it['substituto'] as bool? ?? false,
        produtoExistente: existente,
        cadastrarNovo: true, // default: cadastrar produtos novos
      ));
    }

    setState(() {
      _dados = dados;
      _itens = itens;
      _processando = false;
    });
  }

  Future<void> _confirmarImportacao() async {
    setState(() => _processando = true);
    final itensParaCriar = <Map<String, dynamic>>[];

    for (final item in _itens) {
      int? produtoId = item.produtoExistente?.id;

      if (produtoId == null && item.cadastrarNovo) {
        Categoria? cat;
        if (item.categoriaNome != null) {
          final cats = await DatabaseHelper.instance.getCategorias();
          cat = cats.where((c) =>
              c.nome.toLowerCase() == item.categoriaNome!.toLowerCase())
              .firstOrNull;
        }
        produtoId = await DatabaseHelper.instance.salvarProduto(Produto(
          nome: item.nome,
          unidade: item.unidade,
          consumoMensal: 0,
          estoqueMinimo: 0,
          categoriaId: cat?.id,
          marca: item.marca,
          criadoEm: DateTime.now().toIso8601String(),
        ));
      }

      itensParaCriar.add({
        'nome': item.nome,
        'produtoId': produtoId,
        'quantidade': item.quantidade,
        'unidade': item.unidade,
        'marcado': false, // sempre chega desmarcado, é uma lista nova aqui
        'substituto': item.substituto,
      });
    }

    final descricaoBase = _dados!['descricao'] as String;
    final listaId = await DatabaseHelper.instance.criarListaImportada(
      '$descricaoBase (importada)',
      itensParaCriar,
    );

    if (!mounted) return;
    setState(() => _processando = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ListaComprasScreen(listaId: listaId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar lista')),
      body: _dados == null ? _telaColar() : _telaPreview(),
    );
  }

  Widget _telaColar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Cole abaixo a mensagem que você recebeu (WhatsApp, e-mail, etc.) '
          'com a lista de compras compartilhada pelo Minha Despensa.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            controller: _textoCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Cole a mensagem aqui...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 8),
          Text(_erro!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _processando || _textoCtrl.text.trim().isEmpty
              ? null
              : _processarTexto,
          icon: const Icon(Icons.search),
          label: Text(_processando ? 'Lendo...' : 'Ler lista'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ]),
    );
  }

  Widget _telaPreview() {
    final novos = _itens.where((i) => i.produtoExistente == null).length;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: AppTheme.primary.withOpacity(0.06),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_dados!['descricao'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '${_itens.length} ite${_itens.length == 1 ? 'm' : 'ns'}'
            '${novos > 0 ? ' · $novos novo${novos > 1 ? 's' : ''} pra você' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _itens.length,
          itemBuilder: (_, i) => _cardItem(_itens[i]),
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _processando ? null : _confirmarImportacao,
            icon: const Icon(Icons.check),
            label: Text(_processando ? 'Importando...' : 'Importar lista'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _cardItem(_ItemImportado item) {
    final jaExiste = item.produtoExistente != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Text(item.categoriaIcone, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${item.quantidade == item.quantidade.roundToDouble() ? item.quantidade.toInt() : item.quantidade} ${item.unidade}'
                '${item.marca != null ? ' · ${item.marca}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              if (jaExiste)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('✅ já no seu cadastro',
                      style: TextStyle(fontSize: 11, color: AppTheme.success)),
                )
              else
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🆕 novo produto',
                        style: TextStyle(fontSize: 11, color: AppTheme.warning)),
                  ),
                  const Spacer(),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Cadastrar', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Switch(
                      value: item.cadastrarNovo,
                      onChanged: (v) => setState(() => item.cadastrarNovo = v),
                      activeColor: AppTheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ]),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ItemImportado {
  final String nome;
  final String? marca;
  final String? categoriaNome;
  final String categoriaIcone;
  final double quantidade;
  final String unidade;
  final bool marcado;
  final bool substituto;
  final Produto? produtoExistente;
  bool cadastrarNovo;

  _ItemImportado({
    required this.nome,
    this.marca,
    this.categoriaNome,
    required this.categoriaIcone,
    required this.quantidade,
    required this.unidade,
    required this.marcado,
    required this.substituto,
    required this.produtoExistente,
    required this.cadastrarNovo,
  });
}
