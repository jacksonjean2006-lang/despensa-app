import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/local_compra.dart';
import '../theme.dart';

class MercadosScreen extends StatefulWidget {
  const MercadosScreen({super.key});
  @override
  State<MercadosScreen> createState() => _MercadosScreenState();
}

class _MercadosScreenState extends State<MercadosScreen> {
  List<LocalCompra> _locais = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    _locais = await DatabaseHelper.instance.getLocaisTodos();
    setState(() => _carregando = false);
  }

  Future<void> _adicionar() => _abrirFormulario();

  Future<void> _editar(LocalCompra l) => _abrirFormulario(existente: l);

  Future<void> _abrirFormulario({LocalCompra? existente}) async {
    final nomeCtrl = TextEditingController(text: existente?.nome ?? '');
    final refCtrl  = TextEditingController(text: existente?.referencia ?? '');
    final formKey  = GlobalKey<FormState>();

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existente == null ? 'Novo mercado' : 'Editar mercado'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nomeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome do mercado *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: refCtrl,
              decoration: const InputDecoration(
                  labelText: 'Bairro / referência (opcional)'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (salvou != true) return;

    await DatabaseHelper.instance.salvarLocal(LocalCompra(
      id: existente?.id,
      nome: nomeCtrl.text.trim(),
      referencia: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      ativo: existente?.ativo ?? true,
      criadoEm: existente?.criadoEm ?? DateTime.now().toIso8601String(),
    ));
    if (mounted) _carregar();
  }

  Future<void> _excluir(LocalCompra l) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Excluir "${l.nome}"?'),
        content: const Text(
            'Se esse mercado já tem preços ou compras registradas, ele só '
            'vai ser ocultado das listas de seleção (o histórico continua '
            'mostrando o nome normalmente). Se nunca foi usado, é excluído '
            'de vez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    final apagouDeVerdade = await DatabaseHelper.instance.excluirLocal(l.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(apagouDeVerdade
          ? 'Mercado excluído.'
          : 'Mercado tinha histórico ligado a ele, então só foi desativado.'),
    ));
    _carregar();
  }

  Future<void> _reativar(LocalCompra l) async {
    await DatabaseHelper.instance.reativarLocal(l.id!);
    if (mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mercados')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _locais.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Nenhum mercado cadastrado',
                        style: TextStyle(color: Colors.grey)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: _locais.length,
                  itemBuilder: (_, i) {
                    final l = _locais[i];
                    final inativo = !l.ativo;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: inativo ? Colors.grey.shade100 : null,
                      child: ListTile(
                        leading: Icon(Icons.storefront_outlined,
                            color: inativo ? Colors.grey : AppTheme.primary),
                        title: Row(children: [
                          Flexible(
                            child: Text(l.nome,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: inativo ? Colors.grey.shade600 : null)),
                          ),
                          if (inativo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('inativo',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey.shade700)),
                            ),
                          ],
                        ]),
                        subtitle: l.referencia != null ? Text(l.referencia!) : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'editar') _editar(l);
                            if (v == 'excluir') _excluir(l);
                            if (v == 'reativar') _reativar(l);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'editar',
                                child: Text('Editar')),
                            if (inativo)
                              const PopupMenuItem(
                                  value: 'reativar',
                                  child: Text('Reativar'))
                            else
                              const PopupMenuItem(
                                  value: 'excluir',
                                  child: Text('Excluir')),
                          ],
                        ),
                        onTap: () => _editar(l),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionar,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
