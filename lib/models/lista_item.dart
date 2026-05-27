class ListaItem {
  final int? id;
  final int listaId;
  final int? produtoId;
  final String? nomeAvulso;
  double quantidade;
  final String unidade;
  bool marcado;
  final bool substituto;

  // Campos extras
  String? produtoNome;
  String? produtoFoto;
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
    this.produtoNome,
    this.produtoFoto,
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
        produtoNome: m['produto_nome'],
        produtoFoto: m['foto_path'],
        categoriaIcone: m['categoria_icone'],
      );
}
