import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
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
          // Botão novo produto
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo produto',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CadastroProdutoScreen(cats: _cats)));
              await _carregar(); // recarrega imediatamente ao voltar
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: Column(children: [
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
    final nomeCtrl  = TextEditingController();
    final iconeCtrl = TextEditingController(text: '📦');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova categoria'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: iconeCtrl,
            decoration: const InputDecoration(labelText: 'Emoji/ícone'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome *'),
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
                icone: iconeCtrl.text.trim().isEmpty
                    ? '📦' : iconeCtrl.text.trim(),
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
    );
  }

  Future<void> _editarCategoria(Categoria cat) async {
    final nomeCtrl  = TextEditingController(text: cat.nome);
    final iconeCtrl = TextEditingController(text: cat.icone ?? '📦');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar categoria'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: iconeCtrl,
            decoration: const InputDecoration(labelText: 'Emoji/ícone'),
          ),
          const SizedBox(height: 8),
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
                icone: iconeCtrl.text.trim().isEmpty
                    ? '📦' : iconeCtrl.text.trim(),
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
class CadastroProdutoScreen extends StatefulWidget {
  final List<Categoria> cats;
  final Produto? produto;
  const CadastroProdutoScreen(
      {super.key, required this.cats, this.produto});

  @override
  State<CadastroProdutoScreen> createState() =>
      _CadastroProdutoScreenState();
}

class _CadastroProdutoScreenState extends State<CadastroProdutoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nome, _marca, _consumo, _minimo;
  String _unidade = 'un';
  int? _catId;
  bool _ativo = true;
  String? _fotoPath;
  bool _salvando = false;

  final _unidades = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nome    = TextEditingController(text: p?.nome ?? '');
    _marca   = TextEditingController(text: p?.marca ?? '');
    _consumo = TextEditingController(
        text: p != null && p.consumoMensal > 0
            ? p.consumoMensal.toString() : '');
    _minimo  = TextEditingController(
        text: p != null && p.estoqueMinimo > 0
            ? p.estoqueMinimo.toString() : '');
    _unidade  = p?.unidade ?? 'un';
    _catId    = p?.categoriaId;
    _ativo    = p?.ativo ?? true;
    _fotoPath = p?.fotoPath;
  }

  @override
  void dispose() {
    _nome.dispose(); _marca.dispose();
    _consumo.dispose(); _minimo.dispose();
    super.dispose();
  }

  Future<void> _pickFoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _fotoPath = img.path);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
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
                height: 100,
                decoration: BoxDecoration(
                  color:        Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: Colors.grey.shade300),
                ),
                child: _fotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_fotoPath!),
                            fit: BoxFit.cover))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 32, color: Colors.grey),
                          SizedBox(height: 6),
                          Text('Adicionar foto',
                              style: TextStyle(color: Colors.grey)),
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
                        items: _unidades
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
