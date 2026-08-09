import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/categoria.dart';
import '../models/produto.dart';
import '../models/local_compra.dart';
import '../models/lista_item.dart';
import '../models/historico_compra.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get db async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'despensa.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // adiciona coluna nome_avulso para itens de compra avulsa sem cadastro
      final cols = await db.rawQuery("PRAGMA table_info(historico_compras)");
      final jaTem = cols.any((c) => c['name'] == 'nome_avulso');
      if (!jaTem) {
        await db.execute(
            'ALTER TABLE historico_compras ADD COLUMN nome_avulso TEXT');
      }
    }
    if (oldVersion < 3) {
      final tabelas = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='unidades'");
      if (tabelas.isEmpty) {
        await db.execute('''
          CREATE TABLE unidades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sigla TEXT NOT NULL UNIQUE
          )
        ''');
        await _seedUnidades(db);
      }
    }
    if (oldVersion < 4) {
      // Antes o preço/local ficavam só em memória na tela (perdidos ao
      // reconstruir o widget - ex: celular apagando a tela). Agora ficam
      // persistidos direto no item da lista assim que registrados.
      final cols = await db.rawQuery("PRAGMA table_info(lista_itens)");
      final nomes = cols.map((c) => c['name']).toSet();
      if (!nomes.contains('preco_total')) {
        await db.execute('ALTER TABLE lista_itens ADD COLUMN preco_total REAL');
      }
      if (!nomes.contains('preco_unitario')) {
        await db.execute('ALTER TABLE lista_itens ADD COLUMN preco_unitario REAL');
      }
      if (!nomes.contains('local_id')) {
        await db.execute('ALTER TABLE lista_itens ADD COLUMN local_id INTEGER REFERENCES locais_compra(id)');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        icone TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE produtos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        foto_path TEXT,
        unidade TEXT NOT NULL DEFAULT 'un',
        consumo_mensal REAL NOT NULL DEFAULT 0,
        estoque_minimo REAL NOT NULL DEFAULT 0,
        categoria_id INTEGER REFERENCES categorias(id),
        marca TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        criado_em TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE estoque (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id INTEGER NOT NULL REFERENCES produtos(id),
        quantidade REAL NOT NULL DEFAULT 0,
        atualizado_em TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE listas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        criado_em TEXT NOT NULL,
        finalizado_em TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE lista_itens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lista_id INTEGER NOT NULL REFERENCES listas(id),
        produto_id INTEGER REFERENCES produtos(id),
        nome_avulso TEXT,
        quantidade REAL NOT NULL DEFAULT 1,
        unidade TEXT,
        marcado INTEGER NOT NULL DEFAULT 0,
        substituto INTEGER NOT NULL DEFAULT 0,
        preco_total REAL,
        preco_unitario REAL,
        local_id INTEGER REFERENCES locais_compra(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE locais_compra (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        referencia TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        criado_em TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE historico_compras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lista_id INTEGER REFERENCES listas(id),
        produto_id INTEGER REFERENCES produtos(id),
        nome_avulso TEXT,
        local_id INTEGER REFERENCES locais_compra(id),
        quantidade_comprada REAL NOT NULL,
        preco_total REAL,
        preco_unitario REAL,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE unidades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sigla TEXT NOT NULL UNIQUE
      )
    ''');
    await _seed(db);
    await _seedUnidades(db);
  }

  Future<void> _seed(Database db) async {
    final cats = [
      {'nome': 'Alimentação', 'icone': '🍎'},
      {'nome': 'Limpeza', 'icone': '🧹'},
      {'nome': 'Higiene', 'icone': '🪥'},
      {'nome': 'Bebidas', 'icone': '🥤'},
      {'nome': 'Frios e Laticínios', 'icone': '🧀'},
      {'nome': 'Padaria', 'icone': '🍞'},
      {'nome': 'Outros', 'icone': '📦'},
    ];
    for (final c in cats) {
      await db.insert('categorias', c);
    }
  }

  Future<void> _seedUnidades(Database db) async {
    const unidades = ['kg', 'g', 'L', 'ml', 'un', 'cx', 'pct'];
    for (final u in unidades) {
      await db.insert('unidades', {'sigla': u});
    }
  }

  // ─── UNIDADES ────────────────────────────────────────────
  Future<List<String>> getUnidades() async {
    final d = await db;
    final rows = await d.query('unidades', orderBy: 'sigla');
    if (rows.isEmpty) {
      await _seedUnidades(d);
      final novas = await d.query('unidades', orderBy: 'sigla');
      return novas.map((r) => r['sigla'] as String).toList();
    }
    return rows.map((r) => r['sigla'] as String).toList();
  }

  Future<void> salvarUnidade(String sigla) async {
    final d = await db;
    await d.insert('unidades', {'sigla': sigla.trim()});
  }

  Future<void> deletarUnidade(int id) async {
    final d = await db;
    await d.delete('unidades', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUnidadesComId() async {
    final d = await db;
    return d.query('unidades', orderBy: 'sigla');
  }

  // ─── CATEGORIAS ────────────────────────────────────────────
  Future<List<Categoria>> getCategorias() async {
    final d = await db;
    final rows = await d.query('categorias', orderBy: 'nome');
    return rows.map(Categoria.fromMap).toList();
  }

  Future<int> salvarCategoria(Categoria c) async {
    final d = await db;
    if (c.id == null) {
      final map = c.toMap()..remove('id');
      return d.insert('categorias', map);
    } else {
      await d.update('categorias', c.toMap(),
          where: 'id = ?', whereArgs: [c.id]);
      return c.id!;
    }
  }

  // ─── PRODUTOS ──────────────────────────────────────────────
  // Busca um produto pelo nome (case-insensitive, ignora espaços nas pontas).
  // Usado na importação de listas pra tentar vincular automaticamente um
  // item importado a um produto já cadastrado.
  Future<Produto?> buscarProdutoPorNome(String nome) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*,
             COALESCE((
               SELECT quantidade FROM estoque
               WHERE produto_id = p.id
               ORDER BY atualizado_em DESC
               LIMIT 1
             ), 0) AS estoque_atual,
             c.nome AS categoria_nome,
             c.icone AS categoria_icone
      FROM produtos p
      LEFT JOIN categorias c ON c.id = p.categoria_id
      WHERE LOWER(TRIM(p.nome)) = LOWER(TRIM(?))
      LIMIT 1
    ''', [nome]);
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  Future<List<Produto>> getProdutos({bool apenasAtivos = false}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*,
             COALESCE((
               SELECT quantidade FROM estoque
               WHERE produto_id = p.id
               ORDER BY atualizado_em DESC
               LIMIT 1
             ), 0) AS estoque_atual,
             c.nome AS categoria_nome,
             c.icone AS categoria_icone
      FROM produtos p
      LEFT JOIN categorias c ON c.id = p.categoria_id
      ${apenasAtivos ? 'WHERE p.ativo = 1' : ''}
      ORDER BY p.nome
    ''');
    return rows.map(Produto.fromMap).toList();
  }

  Future<int> salvarProduto(Produto p) async {
    final d = await db;
    if (p.id == null) {
      return d.insert('produtos', p.toMap());
    } else {
      await d.update('produtos', p.toMap(),
          where: 'id = ?', whereArgs: [p.id]);
      return p.id!;
    }
  }

  Future<void> deletarProduto(int id) async {
    final d = await db;
    await d.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }

  // ─── ESTOQUE ───────────────────────────────────────────────
  Future<void> atualizarEstoque(int produtoId, double quantidade) async {
    final d = await db;
    final existe = await d.query('estoque',
        where: 'produto_id = ?', whereArgs: [produtoId]);
    final agora = DateTime.now().toIso8601String();
    if (existe.isEmpty) {
      await d.insert('estoque', {
        'produto_id': produtoId,
        'quantidade': quantidade,
        'atualizado_em': agora,
      });
    } else {
      await d.update(
        'estoque',
        {'quantidade': quantidade, 'atualizado_em': agora},
        where: 'produto_id = ?',
        whereArgs: [produtoId],
      );
    }
  }

  // ─── LISTAS ────────────────────────────────────────────────
  // Nome sugerido automaticamente ao criar uma lista (dia, mês e ano)
  static String nomeAutomatico() {
    final agora = DateTime.now();
    const meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho',
                   'Agosto','Setembro','Outubro','Novembro','Dezembro'];
    return 'Lista de ${agora.day} de ${meses[agora.month - 1]} de ${agora.year}';
  }

  Future<int> criarLista(String descricao) async {
    final d = await db;
    return d.insert('listas', {
      'descricao': descricao,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> finalizarLista(int listaId) async {
    final d = await db;
    await d.update(
      'listas',
      {'finalizado_em': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [listaId],
    );
  }

  Future<Map<String, dynamic>?> getListaAberta() async {
    final d = await db;
    final rows = await d.query('listas',
        where: 'finalizado_em IS NULL',
        orderBy: 'criado_em DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  // Todas as listas (abertas e finalizadas), pra tela de Histórico - já com
  // o total gasto (soma do histórico de compras vinculado à lista)
  Future<List<Map<String, dynamic>>> getListas() async {
    final d = await db;
    return d.rawQuery('''
      SELECT l.*,
             (SELECT SUM(preco_total) FROM historico_compras WHERE lista_id = l.id) AS total
      FROM listas l
      ORDER BY l.criado_em DESC
    ''');
  }

  Future<Map<String, dynamic>?> getListaPorId(int id) async {
    final d = await db;
    final rows = await d.query('listas', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> renomearLista(int listaId, String novoNome) async {
    final d = await db;
    await d.update('listas', {'descricao': novoNome},
        where: 'id = ?', whereArgs: [listaId]);
  }

  // Só deve ser chamado pra listas ainda abertas (garantido na tela)
  Future<void> deletarLista(int listaId) async {
    final d = await db;
    await d.delete('lista_itens', where: 'lista_id = ?', whereArgs: [listaId]);
    await d.delete('listas', where: 'id = ?', whereArgs: [listaId]);
  }

  // ─── ITENS DA LISTA ────────────────────────────────────────
  Future<List<ListaItem>> getItensDaLista(int listaId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT li.*,
             p.nome AS produto_nome,
             p.foto_path,
             c.nome AS categoria_nome,
             c.icone AS categoria_icone,
             loc.nome AS local_nome
      FROM lista_itens li
      LEFT JOIN produtos p ON p.id = li.produto_id
      LEFT JOIN categorias c ON c.id = p.categoria_id
      LEFT JOIN locais_compra loc ON loc.id = li.local_id
      WHERE li.lista_id = ?
      ORDER BY COALESCE(c.nome, 'zzz'), p.nome, li.nome_avulso
    ''', [listaId]);
    return rows.map(ListaItem.fromMap).toList();
  }

  Future<int> adicionarItem(ListaItem item) async {
    final d = await db;
    return d.insert('lista_itens', item.toMap());
  }

  Future<void> toggleMarcado(int itemId, bool marcado) async {
    final d = await db;
    await d.update('lista_itens', {'marcado': marcado ? 1 : 0},
        where: 'id = ?', whereArgs: [itemId]);
  }

  // Persiste o preço/quantidade/local assim que o usuário confirma o
  // dialog de preço - NÃO fica só em memória na tela (isso era o motivo
  // dos valores sumirem quando o app perdia o estado da tela, ex: celular
  // apagando a tela ou o Android reciclando a Activity em segundo plano).
  Future<void> atualizarPrecoItem(
    int itemId, {
    required double quantidade,
    double? precoTotal,
    double? precoUnitario,
    int? localId,
  }) async {
    final d = await db;
    await d.update(
      'lista_itens',
      {
        'quantidade': quantidade,
        'preco_total': precoTotal,
        'preco_unitario': precoUnitario,
        'local_id': localId,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deletarItem(int itemId) async {
    final d = await db;
    await d.delete('lista_itens', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> gerarListaAutomatica(int listaId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.id, p.nome, p.unidade, p.consumo_mensal,
             COALESCE((
               SELECT quantidade FROM estoque
               WHERE produto_id = p.id
               ORDER BY atualizado_em DESC
               LIMIT 1
             ), 0) AS estoque_atual
      FROM produtos p
      WHERE p.ativo = 1
        AND (p.consumo_mensal - COALESCE((
               SELECT quantidade FROM estoque
               WHERE produto_id = p.id
               ORDER BY atualizado_em DESC
               LIMIT 1
             ), 0)) > 0
        AND p.id NOT IN (
          SELECT produto_id FROM lista_itens
          WHERE lista_id = ? AND produto_id IS NOT NULL
        )
    ''', [listaId]);
    for (final row in rows) {
      final qtd = (row['consumo_mensal'] as num).toDouble() -
          (row['estoque_atual'] as num).toDouble();
      await d.insert('lista_itens', {
        'lista_id': listaId,
        'produto_id': row['id'],
        'quantidade': qtd,
        'unidade': row['unidade'],
        'marcado': 0,
        'substituto': 0,
      });
    }
  }

  // ─── LOCAIS ────────────────────────────────────────────────
  Future<List<LocalCompra>> getLocais() async {
    final d = await db;
    final rows = await d.query('locais_compra',
        where: 'ativo = 1', orderBy: 'nome');
    return rows.map(LocalCompra.fromMap).toList();
  }

  Future<int> salvarLocal(LocalCompra local) async {
    final d = await db;
    if (local.id == null) {
      return d.insert('locais_compra', local.toMap());
    } else {
      await d.update('locais_compra', local.toMap(),
          where: 'id = ?', whereArgs: [local.id]);
      return local.id!;
    }
  }

  // ─── HISTÓRICO ─────────────────────────────────────────────
  Future<void> registrarCompra(HistoricoCompra h) async {
    final d = await db;
    await d.insert('historico_compras', h.toMap());
    // Atualiza estoque somando o que foi comprado
    if (h.produtoId != null) {
      final rows = await d.query('estoque',
          where: 'produto_id = ?', whereArgs: [h.produtoId]);
      final atual = rows.isEmpty
          ? 0.0
          : (rows.first['quantidade'] as num).toDouble();
      await atualizarEstoque(h.produtoId!, atual + h.quantidadeComprada);
    }
  }

  Future<List<HistoricoCompra>> getHistoricoProduto(int produtoId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.*, l.nome AS local_nome, p.unidade
      FROM historico_compras h
      LEFT JOIN locais_compra l ON l.id = h.local_id
      LEFT JOIN produtos p ON p.id = h.produto_id
      WHERE h.produto_id = ?
      ORDER BY h.data DESC
    ''', [produtoId]);
    return rows.map(HistoricoCompra.fromMap).toList();
  }

  Future<HistoricoCompra?> getUltimaCompra(int produtoId) async {
    final lista = await getHistoricoProduto(produtoId);
    return lista.isEmpty ? null : lista.first;
  }

  // ─── RESUMO MENSAL ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getResumoMensal() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT
        strftime('%Y-%m', data) AS mes,
        COUNT(DISTINCT CASE WHEN lista_id IS NOT NULL THEN lista_id ELSE id END) AS num_compras,
        SUM(preco_total) AS total_gasto,
        COUNT(DISTINCT produto_id) AS num_produtos
      FROM historico_compras
      WHERE preco_total IS NOT NULL
      GROUP BY mes
      ORDER BY mes DESC
      LIMIT 12
    ''');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ─── TODOS OS ÚLTIMOS PREÇOS (cadastrados + avulsos) ──────────────────────────
  Future<List<Map<String, dynamic>>> getResumoMensalPorLocal() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT
        strftime('%Y-%m', h.data) AS mes,
        COALESCE(l.nome, 'Sem mercado informado') AS mercado,
        SUM(h.preco_total) AS total_gasto
      FROM historico_compras h
      LEFT JOIN locais_compra l ON l.id = h.local_id
      WHERE h.preco_total IS NOT NULL
      GROUP BY mes, mercado
      ORDER BY mes DESC, total_gasto DESC
    ''');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Cadastra um produto a partir de um item avulso, e vincula retroativamente
  // qualquer compra/lista_item avulso anterior com esse MESMO nome ao produto
  // novo - assim o histórico de preços não se perde quando ele passa a ser
  // um item cadastrado.
  Future<int> incluirAvulsoNoCadastro(String nome, String unidade) async {
    final d = await db;
    // Evita duplicar: se já existe um produto com esse nome (ex: usuário
    // clicou "incluir" mais de uma vez pro mesmo item avulso), reaproveita
    // em vez de criar outro.
    final existente = await buscarProdutoPorNome(nome);
    final id = existente?.id ??
        await d.insert('produtos', {
          'nome': nome,
          'unidade': unidade,
          'consumo_mensal': 0,
          'estoque_minimo': 0,
          'categoria_id': null,
          'marca': null,
          'ativo': 1,
          'criado_em': DateTime.now().toIso8601String(),
        });
    await d.update('historico_compras', {'produto_id': id, 'nome_avulso': null},
        where: 'produto_id IS NULL AND nome_avulso = ?', whereArgs: [nome]);
    await d.update('lista_itens', {'produto_id': id, 'nome_avulso': null},
        where: 'produto_id IS NULL AND nome_avulso = ?', whereArgs: [nome]);
    return id;
  }

  Future<List<Map<String, dynamic>>> getUltimosPrecos() async {
    final d = await db;
    // Itens cadastrados — última compra de cada produto
    final cadastrados = await d.rawQuery('''
      SELECT
        h.produto_id,
        p.nome AS produto_nome,
        p.unidade,
        c.icone AS categoria_icone,
        h.preco_unitario,
        h.preco_total,
        h.quantidade_comprada,
        h.data,
        l.nome AS local_nome
      FROM historico_compras h
      JOIN produtos p ON p.id = h.produto_id
      LEFT JOIN categorias c ON c.id = p.categoria_id
      LEFT JOIN locais_compra l ON l.id = h.local_id
      WHERE h.preco_unitario IS NOT NULL
        AND h.data = (
          SELECT MAX(h2.data) FROM historico_compras h2
          WHERE h2.produto_id = h.produto_id
            AND h2.preco_unitario IS NOT NULL
        )
      GROUP BY h.produto_id
      ORDER BY p.nome
    ''');

    // Itens avulsos (sem produto_id) — última compra de cada nome_avulso
    final avulsos = await d.rawQuery('''
      SELECT
        NULL AS produto_id,
        h.nome_avulso AS produto_nome,
        'un' AS unidade,
        '🛍️' AS categoria_icone,
        h.preco_unitario,
        h.preco_total,
        h.quantidade_comprada,
        h.data,
        l.nome AS local_nome
      FROM historico_compras h
      LEFT JOIN locais_compra l ON l.id = h.local_id
      WHERE h.produto_id IS NULL
        AND h.preco_unitario IS NOT NULL
        AND h.nome_avulso IS NOT NULL
        AND h.data = (
          SELECT MAX(h2.data) FROM historico_compras h2
          WHERE h2.nome_avulso = h.nome_avulso
            AND h2.produto_id IS NULL
            AND h2.preco_unitario IS NOT NULL
        )
      GROUP BY h.nome_avulso
      ORDER BY h.nome_avulso
    ''');

    final todos = [...cadastrados, ...avulsos];

    // Para cada produto/avulso, busca o preço anterior separadamente
    final result = <Map<String, dynamic>>[];
    for (final row in todos) {
      final produtoId  = row['produto_id'] as int?;
      final nomeAvulso = row['produto_nome'] as String?;
      final dataAtual  = row['data'] as String;

      List<Map<String, Object?>> anterior;
      if (produtoId != null) {
        anterior = await d.rawQuery('''
          SELECT preco_unitario FROM historico_compras
          WHERE produto_id = ?
            AND preco_unitario IS NOT NULL
            AND data < ?
          ORDER BY data DESC
          LIMIT 1
        ''', [produtoId, dataAtual]);
      } else {
        anterior = await d.rawQuery('''
          SELECT preco_unitario FROM historico_compras
          WHERE nome_avulso = ?
            AND produto_id IS NULL
            AND preco_unitario IS NOT NULL
            AND data < ?
          ORDER BY data DESC
          LIMIT 1
        ''', [nomeAvulso, dataAtual]);
      }

      final mapa = Map<String, dynamic>.from(row);
      mapa['preco_anterior'] = anterior.isEmpty
          ? null
          : (anterior.first['preco_unitario'] as num?)?.toDouble();
      result.add(mapa);
    }

    // Ordena pelo nome
    result.sort((a, b) => (a['produto_nome'] as String)
        .compareTo(b['produto_nome'] as String));
    return result;
  }

  // ─── HISTÓRICO PARA GRÁFICO ─────────────────────────────────
  // ─── MANUTENÇÃO ────────────────────────────────────────────
  // Limpa toda a movimentação (estoque, listas, itens de lista e histórico
  // de compras/preços), mas MANTÉM o cadastro: produtos, categorias e locais
  // de compra. Útil pra zerar o "uso" do app sem perder o que já foi cadastrado
  // (diferente de desinstalar, que apaga tudo).
  Future<void> limparMovimentacao() async {
    final d = await db;
    await d.delete('lista_itens');
    await d.delete('listas');
    await d.delete('historico_compras');
    await d.delete('estoque');
  }

  Future<List<HistoricoCompra>> getHistoricoProdutoGrafico(int produtoId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT h.*, l.nome AS local_nome, p.unidade
      FROM historico_compras h
      LEFT JOIN locais_compra l ON l.id = h.local_id
      LEFT JOIN produtos p ON p.id = h.produto_id
      WHERE h.produto_id = ? AND h.preco_unitario IS NOT NULL
      ORDER BY h.data ASC
      LIMIT 20
    ''', [produtoId]);
    return rows.map(HistoricoCompra.fromMap).toList();
  }

  // ─── IMPORTAÇÃO DE LISTA ───────────────────────────────
  // Cria uma lista nova já com os itens vindos de uma lista importada.
  // Cada mapa em [itens] deve ter: nome, quantidade, unidade, marcado,
  // substituto e opcionalmente produtoId (se já foi resolvido/vinculado
  // a um produto do cadastro).
  Future<int> criarListaImportada(
      String descricao, List<Map<String, dynamic>> itens) async {
    final d = await db;
    final listaId = await d.insert('listas', {
      'descricao': descricao,
      'criado_em': DateTime.now().toIso8601String(),
    });
    for (final item in itens) {
      await d.insert('lista_itens', {
        'lista_id': listaId,
        'produto_id': item['produtoId'],
        'nome_avulso': item['produtoId'] == null ? item['nome'] : null,
        'quantidade': item['quantidade'],
        'unidade': item['unidade'],
        'marcado': (item['marcado'] == true) ? 1 : 0,
        'substituto': (item['substituto'] == true) ? 1 : 0,
      });
    }
    return listaId;
  }

  // ─── BACKUP / RESTORE ───────────────────────────────
  // Exporta TODAS as tabelas do app pra um Map simples (tabela -> linhas),
  // pronto pra ser serializado em JSON e salvo/compartilhado como arquivo.
  Future<Map<String, dynamic>> exportarBackupCompleto() async {
    final d = await db;
    const tabelas = [
      'categorias',
      'unidades',
      'produtos',
      'estoque',
      'listas',
      'lista_itens',
      'locais_compra',
      'historico_compras',
    ];
    final dados = <String, dynamic>{};
    for (final t in tabelas) {
      dados[t] = await d.query(t);
    }
    return {
      'tipo': 'backup_minha_despensa',
      'versao': 1,
      'geradoEm': DateTime.now().toIso8601String(),
      'dados': dados,
    };
  }

  // Restaura um backup gerado por exportarBackupCompleto.
  // ATENÇÃO: apaga TODOS os dados atuais antes de restaurar (substituição
  // completa) — a tela que chama isso precisa confirmar com o usuário antes.
  Future<void> restaurarBackupCompleto(Map<String, dynamic> backup) async {
    final d = await db;
    final dados = backup['dados'] as Map<String, dynamic>;
    // Ordem que respeita as FKs: apaga na ordem inversa da criacao,
    // insere na mesma ordem da exportacao (pais antes de filhos).
    const ordemApagar = [
      'historico_compras',
      'lista_itens',
      'listas',
      'locais_compra',
      'estoque',
      'produtos',
      'unidades',
      'categorias',
    ];
    await d.transaction((txn) async {
      for (final t in ordemApagar) {
        await txn.delete(t);
      }
      const ordemInserir = [
        'categorias',
        'unidades',
        'produtos',
        'estoque',
        'listas',
        'lista_itens',
        'locais_compra',
        'historico_compras',
      ];
      for (final t in ordemInserir) {
        final linhas = (dados[t] as List?) ?? [];
        for (final linha in linhas) {
          await txn.insert(t, Map<String, dynamic>.from(linha));
        }
      }
    });
  }
}
