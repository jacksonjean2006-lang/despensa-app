import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/lista_item.dart';

class ListaComprasScreen extends StatefulWidget {
  final int listaId;
  const ListaComprasScreen({Key? key, required this.listaId}) : super(key: key);

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}
class _ListaComprasScreenState extends State<ListaComprasScreen> {
  late Future<List<ListaItem>> _futureItens;

  @override
  void initState() {
    super.initState();
    _futureItens = DatabaseHelper.instance.getItensDaLista(widget.listaId);
  }

  void _atualizarLista() {
    setState(() {
      _futureItens = DatabaseHelper.instance.getItensDaLista(widget.listaId);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lista de Compras")),
      body: FutureBuilder<List<ListaItem>>(
        future: _futureItens,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          final itens = snapshot.data ?? [];
          if (itens.isEmpty) {
            return const Center(child: Text("Nenhum item na lista"));
          }
          return ListView.builder(
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              return CheckboxListTile(
                title: Text(item.nomeExibicao),
                subtitle: Text("${item.quantidade} ${item.unidade}"),
                value: item.marcado,
                onChanged: (val) async {
                  await DatabaseHelper.instance.toggleMarcado(item.id!, val ?? false);
                  _atualizarLista();
                },
              );
            },
          );
        },
      ),
    );
  }
}
