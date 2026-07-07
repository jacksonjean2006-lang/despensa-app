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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = await db.rawQuery("PRAGMA table_info(historico_compras)");
      final jaTem = cols.any((c) => c['name'] == 'nome_avulso');
      if (!jaTem) {
        await db.execute('ALTER TABLE historico_compras ADD COLUMN nome_avulso TEXT');
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
        produto_id INTEGER NOT NULL UNIQUE REFERENCES produtos(id),
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
        substituto INTEGER NOT NULL DEFAULT 0
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
    await _seed(db);
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
      await d.update('categorias', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
      return c.id!;
    }
  }

  // ─── PRODUTOS ──────────────────────────────────────────────
  Future<List<Produto>> getProdutos({bool apenasAtivos = false}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*,
             e.quantidade AS estoque_atual,
             c.nome AS categoria_nome,
             c.icone AS categoria_icone
      FROM produtos p
      LEFT JOIN estoque e ON e.produto_id = p.id
      LEFT JOIN categorias c ON c.id = p.categoria_id
      ${apenasAtivos ? 'WHERE p.ativo = 1' : ''}
      ORDER BY p.nome
    ''');
    return rows.map(Produto.fromMap).toList();
  }

  Future<int> salvarProduto(Produto p) async {
    final