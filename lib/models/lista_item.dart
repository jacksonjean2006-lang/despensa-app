class ListaItem {
  final int? id;
  final int listaId;
  final int? produtoId;
  final String? nomeAvulso;
  double quantidade;
  final String unidade;
  bool marcado;
  final bool substituto;

  // Preço/local registrados - persistidos no banco assim que o usuário
  // confirma o dialog de preço (não ficam só em memória na tela).
  double? precoTotal;
  double? precoUnitario;
  int? localId;
  String? localNome;

  // Campos extras
  String? produtoNome;
  String? produtoFoto;
  String? categoriaNome;
  String? categoriaIcone;

  ListaItem({
    this.id,
    required this.listaId,
    this.produtoId,
    this.nomeAvulso,
    required this.quantidade,
    required this.unidade,
    this.marcado = false,
    this.substituto = false,
    this.precoTotal,
    this.precoUnitario,
    this.localId,
    this.localNome,
    this.produtoNome,
    this.produtoFoto,
    this.categoriaNome,
    this.categoriaIcone,
  });

  String get nomeExibicao => produtoNome ?? nomeAvulso ?? 'Produto';

  Map<String, dynamic> toMap() => {
        'id': id,
        'lista_id': listaId,
        'produto_id': produtoId,
        'nome_avulso': nomeAvulso,
        'quantidade': quantidade,
        'unidade': unidade,
        'marcado': marcado ? 1 : 0,
        'substituto': substituto ? 1 : 0,
        'preco_total': precoTotal,
        'preco_unitario': precoUnitario,
        'local_id': localId,
      };

  factory ListaItem.fromMap(Map<String, dynamic> m) => ListaItem(
        id: m['id'],
        listaId: m['lista_id'],
        produtoId: m['produto_id'],
        nomeAvulso: m['nome_avulso'],
        quantidade: (m['quantidade'] ?? 1).toDouble(),
        unidade: m['unidade'] ?? 'un',
        marcado: (m['marcado'] ?? 0) == 1,
        substituto: (m['substituto'] ?? 0) == 1,
        precoTotal: m['preco_total'] != null ? (m['preco_total'] as num).toDouble() : null,
        precoUnitario: m['preco_unitario'] != null ? (m['preco_unitario'] as num).toDouble() : null,
        localId: m['local_id'],
        localNome: m['local_nome'],
        produtoNome: m['produto_nome'],
        produtoFoto: m['foto_path'],
        categoriaNome: m['categoria_nome'],
        categoriaIcone: m['categoria_icone'],
      );
}
