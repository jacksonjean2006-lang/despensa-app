class Categoria {
  final int? id;
  final String nome;
  final String icone;

  Categoria({this.id, required this.nome, required this.icone});

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'icone': icone};

  factory Categoria.fromMap(Map<String, dynamic> m) =>
      Categoria(id: m['id'], nome: m['nome'], icone: m['icone'] ?? '📦');
}
