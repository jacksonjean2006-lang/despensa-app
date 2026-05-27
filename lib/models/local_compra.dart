class LocalCompra {
  final int? id;
  final String nome;
  final String? referencia;
  final bool ativo;
  final String criadoEm;

  LocalCompra({
    this.id,
    required this.nome,
    this.referencia,
    this.ativo = true,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'referencia': referencia,
        'ativo': ativo ? 1 : 0,
        'criado_em': criadoEm,
      };

  factory LocalCompra.fromMap(Map<String, dynamic> m) => LocalCompra(
        id: m['id'],
        nome: m['nome'],
        referencia: m['referencia'],
        ativo: (m['ativo'] ?? 1) == 1,
        criadoEm: m['criado_em'] ?? '',
      );
}
