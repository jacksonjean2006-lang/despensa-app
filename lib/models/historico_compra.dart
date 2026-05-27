class HistoricoCompra {
  final int? id;
  final int? listaId;
  final int? produtoId;
  final int? localId;
  final double quantidadeComprada;
  final double? precoTotal;
  final double? precoUnitario;
  final String data;

  // Extras
  String? produtoNome;
  String? localNome;
  String? unidade;

  HistoricoCompra({
    this.id,
    this.listaId,
    this.produtoId,
    this.localId,
    required this.quantidadeComprada,
    this.precoTotal,
    this.precoUnitario,
    required this.data,
    this.produtoNome,
    this.localNome,
    this.unidade,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lista_id': listaId,
        'produto_id': produtoId,
        'local_id': localId,
        'quantidade_comprada': quantidadeComprada,
        'preco_total': precoTotal,
        'preco_unitario': precoUnitario,
        'data': data,
      };

  factory HistoricoCompra.fromMap(Map<String, dynamic> m) => HistoricoCompra(
        id: m['id'],
        listaId: m['lista_id'],
        produtoId: m['produto_id'],
        localId: m['local_id'],
        quantidadeComprada: (m['quantidade_comprada'] ?? 0).toDouble(),
        precoTotal: m['preco_total'] != null
            ? (m['preco_total']).toDouble()
            : null,
        precoUnitario: m['preco_unitario'] != null
            ? (m['preco_unitario']).toDouble()
            : null,
        data: m['data'] ?? '',
        produtoNome: m['produto_nome'],
        localNome: m['local_nome'],
        unidade: m['unidade'],
      );
}
