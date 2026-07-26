import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/produto.dart';
import '../models/lista_item.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'lista_compras_screen.dart';

/// Seleção manual de produtos para montar/completar a lista de compras,
/// alternativa ao Levantamento (que gera automático a partir do estoque).
class SelecionarItensScreen extends StatefulWidget {
  const SelecionarItensScreen({super.key});
  @override
  State<SelecionarItensScreen> createState() => _SelecionarItensScreenState();
}

class _SelecionarItensScreenState extends State<SelecionarItensScreen> {
  List<Produto> _produtos = [];
  final Set<int> _selecionados = {};
  bool _carregando = true;
  bool _salvando = false;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final p = await DatabaseHelper.instance.getProdutos(apenasAtivos: true);
    setState(() {
      _produtos = p;
      _carregando = false;
    });
  }

  List<Produto> get _filtrados => _produtos
      .where((p) =>
          _busca.isEmpty || p.nome.toLowerCase().contains(_busca.toLowerCase()))
      .toList();

  Future<void> _confirmar() async {
    if (_selecionados.isEmpty) return;
    setState(() => _salvando = true);

    var lista = await DatabaseHelper.instance.getListaAberta();
    int listaId;
    if (lista == null) {
      listaId =
          await DatabaseHelper.instance.criarLista(DatabaseHelper.nomeAutomatico());
    } else {
      listaId = lista['id'] as int;
    }

    final jaNaLista = (await DatabaseHelper.instance.getItensDaLista(listaId))
        .map((i) => i.produtoId)
        .toSet();

    for (final id in _selecionados) {
      if (jaNaLista.contains(id)) continue;
      final produto = _produtos.firstWhere((p) => p.id == id);
      await DatabaseHelper.instance.adicionarItem(ListaItem(
        listaId: listaId,
        produtoId: id,
        quantidade: produto.consumoMensal > 0 ? produto.consumoMensal : 1,
        unidade: produto.unidade,
      ));
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ListaComprasScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar itens')),
      body: Column(children: [
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
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _produtos.isEmpty
                  ? const Center(
                      child: Text('Nenhum produto cadastrado',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      itemCount: _filtrados.length,
                      itemBuilder: (_, i) {
                        final p = _filtrados[i];
                        final marcado = _selecionados.contains(p.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: CheckboxListTile(
                            value: marcado,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selecionados.add(p.id!);
                              } else {
                                _selecionados.remove(p.id!);
                              }
                            }),
                            secondary: FotoOuEmoji(
                                fotoPath: p.fotoPath,
                                icone: p.categoriaIcone ?? '📦'),
                            title: Text(p.nome),
                            subtitle: Text(
                                '${formatarQtd(p.consumoMensal, p.unidade)}/mês'),
                            activeColor: AppTheme.primary,
                          ),
                        );
                      },
                    ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _selecionados.isEmpty || _salvando ? null : _confirmar,
            icon: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_salvando
                ? 'Salvando...'
                : 'Adicionar ${_selecionados.length} ${_selecionados.length == 1 ? "item" : "itens"} à lista'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
    );
  }
}
