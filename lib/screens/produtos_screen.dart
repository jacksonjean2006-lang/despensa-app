import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../utils/licenca.dart';
import '../utils/busca_produto_codigo.dart';
import 'leitor_codigo_screen.dart';
import 'recortar_foto_screen.dart';
import 'camera_captura_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:typed_data';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});
  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Produto> _produtos = [];
  List<Categoria> _cats = [];
  int? _catFiltro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final p = await DatabaseHelper.instance.getProdutos();
    final c = await DatabaseHelper.instance.getCategorias();
    if (mounted) setState(() { _produtos = p; _cats = c; });
  }

  List<Produto> get _filtrados => _catFiltro == null
      ? _produtos
      : _produtos.where((p) => p.categoriaId == _catFiltro).toList();

  Future<void> _novoProduto() async {
    if (!Licenca.podeAdicionarProduto(_produtos.length)) {
      await Licenca.mostrarBloqueio(context,
          'A versão grátis permite cadastrar até ${Licenca.limiteProdutos} produtos. '
          'Ative sua licença pra cadastrar sem limites.');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CadastroProdutoScreen(cats: _cats)));
    await _carregar(); // recarrega imediatamente ao voltar
  }

  Future<void> _buscarPorCodigoBarras() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const LeitorCodigoScreen(
              titulo: 'Buscar produto pelo código')),
    );
    if (codigo == null || !mounted) return;

    // Primeiro procura no cadastro local (rápido, funciona offline)
    final resultado = await buscarProdutoPorCodigo(codigo);
    if (!mounted) return;

    if (resultado.encontrouNoCadastro) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CadastroProdutoScreen(cats: _cats, produto: resultado.produtoCadastrado)));
      _carregar();
      return;
    }

    // Não achou no cadastro - já tentou a internet dentro do helper acima
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
    if (cadastrar == true) {
      if (!Licenca.podeAdicionarProduto(_produtos.length)) {
        if (mounted) {
          await Licenca.mostrarBloqueio(context,
              'A versão grátis permite cadastrar até ${Licenca.limiteProdutos} produtos. '
              'Ative sua licença pra cadastrar sem limites.');
        }
        return;
      }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CadastroProdutoScreen(
              cats: _cats, codigoBarrasInicial: codigo, nomeInicial: nomeSugerido)));
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          // Botão buscar por código de barras
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Buscar por código de barras',
            onPressed: _buscarPorCodigoBarras,
          ),
          // Botão gerenciar categorias
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Categorias',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CategoriasScreen(cats: _cats)));
              _carregar();
            },
          ),
          // Botão gerenciar unidades
          IconButton(
            icon: const Icon(Icons.straighten),
            tooltip: 'Unidades',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const UnidadesScreen()));
              _carregar();
            },
          ),
          // Botão novo produto
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo produto',
            onPressed: _novoProduto,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: Column(children: [
          if (!Licenca.ativa)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppTheme.warningBg,
              child: Text(
                '${_produtos.length}/${Licenca.limiteProdutos} produtos da versão grátis',
                style: const TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          // Filtro por categoria
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _chipCat(null, 'Todos'),
                ..._cats.map((c) => _chipCat(c.id, '${c.icone} ${c.nome}')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtrados.isEmpty
                ? ListView(
                    children: const [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Nenhum produto nesta categoria',
                                style: TextStyle(color: Colors.grey)),
                          ]),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) =>
                        _ProdutoCard(_filtrados[i], _cats, _carregar),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _chipCat(int? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _catFiltro == id,
      onSelected: (_) => setState(() => _catFiltro = id),
      selectedColor: AppTheme.primaryBg,
      checkmarkColor: AppTheme.primary,
      visualDensity: VisualDensity.compact,
    ),
  );
}

// ─── CARD DO PRODUTO ──────────────────────────────────────────────────────────
class _ProdutoCard extends StatelessWidget {
  final Produto produto;
  final List<Categoria> cats;
  final VoidCallback onRefresh;
  const _ProdutoCard(this.produto, this.cats, this.onRefresh);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: FotoOuEmoji(
            fotoPath: produto.fotoPath,
            icone: produto.categoriaIcone ?? '📦'),
        title: Text(produto.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${formatarQtd(produto.consumoMensal, produto.unidade)}/mês'
          '${produto.marca != null ? ' · ${produto.marca}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusBadge(produto.statusEstoque),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CadastroProdutoScreen(cats: cats, produto: produto)),
          );
          onRefresh();
        },
      ),
    );
  }
}

// ─── Seleção de ícone (grade de emojis comuns + entrada manual) ──────────────────
const _iconesDisponiveis = [
  '🍎', '🍌', '🍊', '🍇', '🥦', '🥕', '🥔', '🥑', '🥬', '🍄',
  '🍅', '🥩', '🍗', '🥚', '🧀', '🥛', '🍞', '🥖', '🧈', '🍚',
  '🍫', '🍬', '☕', '🍵', '🥤', '🍷', '🍺', '🧃', '🧻', '🧴',
  '🧼', '🧹', '🧽', '🪥', '🧊', '🧂', '🌶️', '🥫', '🍕', '🌭',
  '🍿', '🐾', '💊', '🩹', '🔋', '💡', '🚗', '📦', '🛍️',
];

Future<String?> _escolherIcone(BuildContext context, String atual) async {
  final manualCtrl = TextEditingController(text: atual);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Escolher ícone',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: manualCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ou digite/cole um emoji'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, manualCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Usar'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              controller: scrollCtrl,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7),
              itemCount: _iconesDisponiveis.length,
              itemBuilder: (_, i) {
                final icone = _iconesDisponiveis[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(context, icone),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    margin: const EdgeInsets.all(3),
                    child: Text(icone, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─── GERENCIAR CATEGORIAS ─────────────────────────────────────────────────────
class CategoriasScreen extends StatefulWidget {
  final List<Categoria> cats;
  const CategoriasScreen({super.key, required this.cats});
  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  late List<Categoria> _cats;

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.cats);
  }

  Future<void> _carregar() async {
    final c = await DatabaseHelper.instance.getCategorias();
    if (mounted) setState(() => _cats = c);
  }

  Future<void> _novaCategoria() async {
    if (!Licenca.podeCriarCategoriaOuUnidade) {
      await Licenca.mostrarBloqueio(context,
          'Criar categorias novas é um recurso da versão completa. '
          'Você pode continuar usando as categorias já existentes normalmente.');
      return;
    }
    final nomeCtrl  = TextEditingController();
    String icone = '📦';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova categoria'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final novo = await _escolherIcone(context, icone);
                if (novo != null && novo.isNotEmpty) {
                  setDialogState(() => icone = novo);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(icone, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  const Text('Toque para escolher o ícone',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome *'),
              autofocus: true,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.salvarCategoria(Categoria(
                  nome:  nomeCtrl.text.trim(),
                  icone: icone,
                ));
                if (context.mounted) Navigator.pop(context);
                _carregar();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarCategoria(Categoria cat) async {
    final nomeCtrl  = TextEditingController(text: cat.nome);
    String icone = cat.icone ?? '📦';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar categoria'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final novo = await _escolherIcone(context, icone);
                if (novo != null && novo.isNotEmpty) {
                  setDialogState(() => icone = novo);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text(icone, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  const Text('Toque para escolher o ícone',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome *'),
              autofocus: true,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.salvarCategoria(Categoria(
                  id:    cat.id,
                  nome:  nomeCtrl.text.trim(),
                  icone: icone,
                ));
                if (context.mounted) Navigator.pop(context);
                _carregar();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _novaCategoria,
          ),
        ],
      ),
      body: _cats.isEmpty
          ? const Center(child: Text('Nenhuma categoria'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _cats.length,
              itemBuilder: (_, i) {
                final c = _cats[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Text(c.icone ?? '📦',
                        style: const TextStyle(fontSize: 24)),
                    title: Text(c.nome,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppTheme.primary),
                      onPressed: () => _editarCategoria(c),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaCategoria,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── CADASTRO / EDIÇÃO DE PRODUTO ─────────────────────────────────────────────
// ─── GERENCIAR UNIDADES ─────────────────────────────────────────────────────
class UnidadesScreen extends StatefulWidget {
  const UnidadesScreen({super.key});
  @override
  State<UnidadesScreen> createState() => _UnidadesScreenState();
}

class _UnidadesScreenState extends State<UnidadesScreen> {
  List<Map<String, dynamic>> _unidades = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final u = await DatabaseHelper.instance.getUnidadesComId();
    setState(() { _unidades = u; _carregando = false; });
  }

  Future<void> _novaUnidade() async {
    if (!Licenca.podeCriarCategoriaOuUnidade) {
      await Licenca.mostrarBloqueio(context,
          'Criar unidades de medida novas é um recurso da versão completa. '
          'Você pode continuar usando as unidades já existentes normalmente.');
      return;
    }
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova unidade'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Sigla *', hintText: 'ex: kg, un, cx, dz...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final sigla = ctrl.text.trim();
              if (sigla.isEmpty) return;
              try {
                await DatabaseHelper.instance.salvarUnidade(sigla);
                if (context.mounted) Navigator.pop(context);
                _carregar();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Essa unidade já existe')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirUnidade(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir unidade?'),
        content: Text('Remover "${u['sigla']}" do cadastro de unidades.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deletarUnidade(u['id'] as int);
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unidades'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _novaUnidade),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _unidades.isEmpty
              ? const Center(child: Text('Nenhuma unidade cadastrada'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _unidades.length,
                  itemBuilder: (_, i) {
                    final u = _unidades[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        title: Text(u['sigla'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.danger),
                          onPressed: () => _excluirUnidade(u),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaUnidade,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class CadastroProdutoScreen extends StatefulWidget {
  final List<Categoria> cats;
  final Produto? produto;
  final String? codigoBarrasInicial;
  final String? nomeInicial;
  const CadastroProdutoScreen(
      {super.key, required this.cats, this.produto, this.codigoBarrasInicial, this.nomeInicial});

  @override
  State<CadastroProdutoScreen> createState() =>
      _CadastroProdutoScreenState();
}

class _CadastroProdutoScreenState extends State<CadastroProdutoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nome, _marca, _consumo, _minimo, _codigoBarras;
  String _unidade = 'un';
  int? _catId;
  bool _ativo = true;
  String? _fotoPath;
  bool _salvando = false;

  final _unidades = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];
  List<String> _unidadesDisponiveis = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
    final p = widget.produto;
    _nome    = TextEditingController(text: p?.nome ?? widget.nomeInicial ?? '');
    _marca   = TextEditingController(text: p?.marca ?? '');
    _consumo = TextEditingController(
        text: p != null && p.consumoMensal > 0
            ? p.consumoMensal.toString() : '');
    _minimo  = TextEditingController(
        text: p != null && p.estoqueMinimo > 0
            ? p.estoqueMinimo.toString() : '');
    _codigoBarras = TextEditingController(
        text: p?.codigoBarras ?? widget.codigoBarrasInicial ?? '');
    _unidade  = p?.unidade ?? 'un';
    _catId    = p?.categoriaId;
    _ativo    = p?.ativo ?? true;
    _fotoPath = p?.fotoPath;
  }

  Future<void> _carregarUnidades() async {
    final u = await DatabaseHelper.instance.getUnidades();
    if (mounted) {
      setState(() {
        // garante que a unidade atual do produto sempre aparece na lista,
        // mesmo que tenha sido removida do cadastro de unidades depois
        _unidadesDisponiveis = <String>{
          ..._unidade.isNotEmpty ? [_unidade] : <String>[],
          ...u,
        }.toList();
      });
    }
  }

  @override
  void dispose() {
    _nome.dispose(); _marca.dispose();
    _consumo.dispose(); _minimo.dispose();
    _codigoBarras.dispose();
    super.dispose();
  }

  Future<void> _pickFoto() async {
    // Só permite foto depois do produto já estar salvo (tem um id). Se
    // deixar tirar foto num produto novo ainda não salvo, o fluxo de
    // câmera + recorte está reiniciando o app no meio do caminho e o
    // cadastro se perde inteiro - assim evita isso.
    if (widget.produto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Salve o produto primeiro. Depois abra ele de novo pra adicionar uma foto.')),
      );
      return;
    }

    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (origem == null) return;

    Uint8List bytesOriginais;
    if (origem == ImageSource.camera) {
      // Câmera própria do app (não abre o app de Câmera do sistema) - evita
      // o Android matar o app em segundo plano por falta de memória
      // enquanto o app de Câmera (pesado) está em primeiro plano, que
      // estava causando o app "reiniciar" e perder o cadastro/foto.
      final fotoPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCapturaScreen()),
      );
      if (fotoPath == null || !mounted) return;
      bytesOriginais = await File(fotoPath).readAsBytes();
    } else {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: origem,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (img == null) return;
      bytesOriginais = await File(img.path).readAsBytes();
    }
    if (!mounted) return;

    // Recorte roda dentro do próprio app (sem abrir tela nativa separada) -
    // evita o Android matar o app em segundo plano durante o recorte, o
    // que antes fazia o app "reiniciar" e perder a foto/cadastro.
    final bytesRecortados = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
          builder: (_) => RecortarFotoScreen(imagemOriginal: bytesOriginais)),
    );
    if (bytesRecortados == null || !mounted) return;

    // Copia pra uma pasta permanente do app - a pasta de cache onde a
    // foto original foi salva pode ser limpa pelo Android a qualquer
    // momento, o que faria a foto sumir mesmo com o produto intacto.
    final pastaFotos = await getApplicationDocumentsDirectory();
    final pastaFotosProdutos = Directory('${pastaFotos.path}/fotos_produtos');
    if (!await pastaFotosProdutos.exists()) {
      await pastaFotosProdutos.create(recursive: true);
    }
    final novoNome = '${const Uuid().v4()}.jpg';
    final destino = File('${pastaFotosProdutos.path}/$novoNome');
    await destino.writeAsBytes(bytesRecortados);

    setState(() => _fotoPath = destino.path);
  }

  Future<void> _escanearCodigoBarras() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const LeitorCodigoScreen(
              titulo: 'Escanear código do produto')),
    );
    if (codigo != null) setState(() => _codigoBarras.text = codigo);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Confere de novo o limite (rede de segurança, caso tenha chegado
    // aqui por outro caminho sem passar pela checagem da tela de lista)
    if (widget.produto == null) {
      final atual = await DatabaseHelper.instance.getProdutos();
      if (!Licenca.podeAdicionarProduto(atual.length)) {
        if (mounted) {
          await Licenca.mostrarBloqueio(context,
              'A versão grátis permite cadastrar até ${Licenca.limiteProdutos} produtos. '
              'Ative sua licença pra cadastrar sem limites.');
        }
        return;
      }
    }

    setState(() => _salvando = true);
    final p = Produto(
      id:            widget.produto?.id,
      nome:          _nome.text.trim(),
      fotoPath:      _fotoPath,
      unidade:       _unidade,
      consumoMensal: double.tryParse(_consumo.text) ?? 0,
      estoqueMinimo: double.tryParse(_minimo.text) ?? 0,
      categoriaId:   _catId,
      marca:         _marca.text.trim().isEmpty ? null : _marca.text.trim(),
      ativo:         _ativo,
      criadoEm:      widget.produto?.criadoEm ??
                     DateTime.now().toIso8601String(),
      codigoBarras:  _codigoBarras.text.trim().isEmpty ? null : _codigoBarras.text.trim(),
    );
    await DatabaseHelper.instance.salvarProduto(p);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: const Text(
            'O produto será removido do cadastro.\nO histórico será mantido.\n\nDica: considere desativar em vez de excluir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true && widget.produto?.id != null) {
      await DatabaseHelper.instance.deletarProduto(widget.produto!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.produto != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar produto' : 'Novo produto'),
        actions: editando
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFF09595)),
                  onPressed: _excluir,
                )
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Foto
            GestureDetector(
              onTap: _pickFoto,
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color:        Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: Colors.grey.shade300),
                ),
                child: _fotoPath != null
                    ? Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_fotoPath!),
                              fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ])
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              editando
                                  ? Icons.camera_alt_outlined
                                  : Icons.lock_outline,
                              size: 36, color: Colors.grey),
                          const SizedBox(height: 6),
                          Text(
                              editando
                                  ? 'Tirar foto ou escolher da galeria'
                                  : 'Salve o produto primeiro pra adicionar foto',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextFormField(
                    controller: _nome,
                    decoration: const InputDecoration(
                        labelText: 'Nome do produto *'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _marca,
                    decoration: const InputDecoration(
                        labelText: 'Marca (opcional)'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codigoBarras,
                    decoration: InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                        tooltip: 'Escanear código',
                        onPressed: _escanearCodigoBarras,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _catId,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                    hint: const Text('Selecionar...'),
                    items: widget.cats
                        .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.icone} ${c.nome}')))
                        .toList(),
                    onChanged: (v) => setState(() => _catId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _consumo,
                        decoration: const InputDecoration(
                            labelText: 'Consumo mensal *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe o consumo' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: DropdownButtonFormField<String>(
                        value: _unidade,
                        decoration:
                            const InputDecoration(labelText: 'Unidade'),
                        items: _unidadesDisponiveis
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _unidade = v ?? 'un'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _minimo,
                    decoration: const InputDecoration(
                        labelText: 'Estoque mínimo (ponto de pedido)'),
                    keyboardType: TextInputType.number,
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: const Text('Produto ativo'),
                    subtitle:
                        const Text('Inclui nas listas automáticas'),
                    value:       _ativo,
                    activeColor: AppTheme.primary,
                    onChanged:   (v) => setState(() => _ativo = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon:  const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar produto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize:     const Size.fromHeight(48),
              ),
            ),
            if (editando) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:   () => Navigator.pop(context),
                style:       OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
