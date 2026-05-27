class Produto {
  final int? id;
  final String nome;
  final String? fotoPath;
  final String unidade;
  final double consumoMensal;
  final double estoqueMinimo;
  final int? categoriaId;
  final String? marca;
  final bool ativo;
  final String criadoEm;

  // Campos extras vindos de JOIN
  double? estoqueAtual;
  String? categoriaNome;
  String? categoriaIcone;

  Produto({
    this.id,
    required this.nome,
    this.fotoPath,
    required this.unidade,
    required this.consumoMensal,
    required this.estoqueMinimo,
    this.categoriaId,
    this.marca,
    this.ativo = true,
    required this.criadoEm,
    this.estoqueAtual,
    this.categoriaNome,
    this.categoriaIcone,
  });

  double get quantidadeComprar {
    final atual = estoqueAtual ?? 0;
    final diff = consumoMensal - atual;
    return diff > 0 ? diff : 0;
  }

  String get statusEstoque {
    final atual = estoqueAtual ?? 0;
    if (atual <= 0) return 'critico';
    if (atual < consumoMensal * 0.4) return 'critico';
    if (atual < consumoMensal * 0.7) return 'atencao';
    return 'ok';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'foto_path': fotoPath,
        'unidade': unidade,
        'consumo_mensal': consumoMensal,
        'estoque_minimo': estoqueMinimo,
        'categoria_id': categoriaId,
        'marca': marca,
        'ativo': ativo ? 1 : 0,
        'criado_em': criadoEm,
      };

  factory Produto.fromMap(Map<String, dynamic> m) => Produto(
        id: m['id'],
        nome: m['nome'],
        fotoPath: m['foto_path'],
        unidade: m['unidade'] ?? 'un',
        consumoMensal: (m['consumo_mensal'] ?? 0).toDouble(),
        estoqueMinimo: (m['estoque_minimo'] ?? 0).toDouble(),
        categoriaId: m['categoria_id'],
        marca: m['marca'],
        ativo: (m['ativo'] ?? 1) == 1,
        criadoEm: m['criado_em'] ?? '',
        estoqueAtual: m['estoque_atual'] != null
            ? (m['estoque_atual']).toDouble()
            : null,
        categoriaNome: m['categoria_nome'],
        categoriaIcone: m['categoria_icone'],
      );

  Produto copyWith({
    int? id,
    String? nome,
    String? fotoPath,
    String? unidade,
    double? consumoMensal,
    double? estoqueMinimo,
    int? categoriaId,
    String? marca,
    bool? ativo,
    String? criadoEm,
  }) =>
      Produto(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        fotoPath: fotoPath ?? this.fotoPath,
        unidade: unidade ?? this.unidade,
        consumoMensal: consumoMensal ?? this.consumoMensal,
        estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
        categoriaId: categoriaId ?? this.categoriaId,
        marca: marca ?? this.marca,
        ativo: ativo ?? this.ativo,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}
