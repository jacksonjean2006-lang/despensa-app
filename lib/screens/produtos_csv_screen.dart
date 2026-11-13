import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../theme.dart';
import '../utils/licenca.dart';

// ─── Importar / exportar produtos por planilha (CSV) ─────────────────────────
//
// Fluxo: o usuário monta a lista de produtos no Excel, salva como CSV e
// importa aqui. Regras:
//  - Produto "já existente" = mesmo NOME + mesma MARCA (sem diferenciar
//    maiúsculas/minúsculas nem acentos). Esses são IGNORADOS (nunca
//    sobrescreve nada). Um código de barras já cadastrado também conta
//    como já existente.
//  - Categoria ou unidade que não existe no app vira "Outros" / "un" (criar
//    categoria/unidade nova é recurso da versão completa).
//  - Na versão grátis a importação respeita o limite de produtos
//    (Licenca.limiteProdutos). Pra liberar a importação SÓ com licença,
//    troque _somenteComLicenca pra true.
//  - Antes de gravar, mostra uma prévia e pede confirmação.
const bool _somenteComLicenca = false;

// ─── Leitura do CSV (funções puras, sem Flutter) ─────────────────────────────

/// Minúsculas, sem acentos e sem espaços repetidos. Usado pra comparar nomes,
/// marcas, categorias e títulos de coluna.
String _norm(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final sb = StringBuffer();
  for (final r in s.trim().toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    sb.write(i >= 0 ? para[i] : c);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// O Excel em português salva CSV em Windows-1252 (ANSI) quando a opção é
/// "CSV (separado por vírgulas)" e em UTF-8 quando é "CSV UTF-8". Tenta
/// UTF-8 primeiro e, se não for válido, cai pra Latin-1 (que cobre os
/// acentos do Windows-1252).
String _decodificar(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Lê o CSV em linhas de campos. Aceita ; , ou TAB como separador (detecta
/// pela primeira linha), campos entre aspas, aspas duplas escapadas ("") e
/// quebra de linha dentro de aspas. Linhas em branco são mantidas (pra o
/// número da linha bater com o da planilha).
List<List<String>> _lerCsv(String texto) {
  if (texto.isNotEmpty && texto.codeUnitAt(0) == 0xFEFF) {
    texto = texto.substring(1);
  }

  // Separador: o mais frequente na primeira linha (fora de aspas)
  var pv = 0, vir = 0, tab = 0;
  var aspas = false;
  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (c == '"') {
      aspas = !aspas;
    } else if (!aspas) {
      if (c == '\n') break;
      if (c == ';') pv++;
      if (c == ',') vir++;
      if (c == '\t') tab++;
    }
  }
  var delim = ';';
  if (vir > pv && vir >= tab) delim = ',';
  if (tab > pv && tab > vir) delim = '\t';

  final linhas = <List<String>>[];
  var campo = StringBuffer();
  var linha = <String>[];
  var emAspas = false;

  void fecharCampo() {
    linha.add(campo.toString());
    campo = StringBuffer();
  }

  void fecharLinha() {
    fecharCampo();
    linhas.add(linha);
    linha = <String>[];
  }

  for (var i = 0; i < texto.length; i++) {
    final c = texto[i];
    if (emAspas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          campo.write('"');
          i++;
        } else {
          emAspas = false;
        }
      } else {
        campo.write(c);
      }
    } else if (c == '"') {
      emAspas = true;
    } else if (c == delim) {
      fecharCampo();
    } else if (c == '\r') {
      // ignora (fim de linha do Windows)
    } else if (c == '\n') {
      fecharLinha();
    } else {
      campo.write(c);
    }
  }
  if (campo.isNotEmpty || linha.isNotEmpty) fecharLinha();
  return linhas;
}

/// Número com vírgula ou ponto decimal. Vazio vira 0; inválido ou negativo
/// vira null.
double? _lerNumero(String s) {
  var t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return 0;
  if (t.contains(',') && t.contains('.')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (t.contains(',')) {
    t = t.replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  return v;
}

/// sim/não. Vazio = ativo. Valor desconhecido = null (erro na linha).
bool? _lerAtivo(String s) {
  final t = _norm(s);
  if (t.isEmpty) return true;
  if (const ['sim', 's', '1', 'true', 'ativo', 'x', 'yes', 'y'].contains(t)) {
    return true;
  }
  if (const ['nao', 'n', '0', 'false', 'inativo', 'no'].contains(t)) {
    return false;
  }
  return null;
}

final _regexNotacao = RegExp(r'^\d+([.,]\d+)?[eE][+-]?\d+$');
final _regexPontoZero = RegExp(r'^(\d+)[.,]0+$');

/// Limpa o código de barras. O Excel estraga código longo (vira 7,89E+12 e
/// perde os dígitos) - nesse caso devolve null e avisa.
String? _lerCodigo(String s, void Function(String) avisar) {
  var t = s.trim().replaceAll(' ', '');
  if (t.startsWith("'")) t = t.substring(1);
  if (t.isEmpty) return null;
  if (_regexNotacao.hasMatch(t)) {
    avisar('código de barras em notação científica (o Excel cortou os '
        'dígitos), ficou sem código');
    return null;
  }
  final m = _regexPontoZero.firstMatch(t);
  if (m != null) t = m.group(1)!;
  return t;
}

const _aliases = <String, List<String>>{
  'nome': ['nome', 'produto', 'nomedoproduto', 'descricao'],
  'unidade': ['unidade', 'un', 'medida', 'unidadedemedida'],
  'consumo': ['consumomensal', 'consumo', 'consumopormes'],
  'minimo': ['estoqueminimo', 'minimo', 'pontodepedido'],
  'categoria': ['categoria'],
  'marca': ['marca'],
  'codigo': ['codigodebarras', 'codigobarras', 'codigo', 'ean', 'gtin'],
  'ativo': ['ativo', 'situacao'],
};

/// Escapa um campo pro CSV (separador ;).
String _csv(String s) {
  if (s.contains(';') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Número pro CSV: sem zeros à direita e com vírgula (padrão do Excel em
/// português).
String _numCsv(double v) {
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  var s = v.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

// ─── Modelos da importação ───────────────────────────────────────────────────

class _LinhaProduto {
  final String nome;
  final String unidade;
  final double consumo;
  final double minimo;
  final int? categoriaId;
  final String? marca;
  final String? codigo;
  final bool ativo;
  _LinhaProduto({
    required this.nome,
    required this.unidade,
    required this.consumo,
    required this.minimo,
    required this.categoriaId,
    required this.marca,
    required this.codigo,
    required this.ativo,
  });
}

class _ResultadoLeitura {
  final List<_LinhaProduto> novos = [];
  final List<String> jaExistem = [];
  final List<String> repetidos = [];
  final List<String> erros = [];
  final List<String> avisos = [];
  int foraDoLimite = 0;
  int? limiteLivre; // vagas restantes na versão grátis (null = sem limite)
}

// ─── Tela ────────────────────────────────────────────────────────────────────

class ProdutosCsvScreen extends StatefulWidget {
  const ProdutosCsvScreen({super.key});
  @override
  State<ProdutosCsvScreen> createState() => _ProdutosCsvScreenState();
}

class _ProdutosCsvScreenState extends State<ProdutosCsvScreen> {
  bool _processando = false;

  String _2d(int n) => n.toString().padLeft(2, '0');

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  Future<void> _aviso(String titulo, String msg) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<void> _compartilharCsv(String conteudo, String nomeArquivo,
      String assunto) async {
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/$nomeArquivo');
    // Começa com BOM (U+FEFF) pro Excel reconhecer UTF-8 e abrir os
    // acentos certinho.
    await arquivo.writeAsString('﻿$conteudo');
    await Share.shareXFiles(
      [XFile(arquivo.path, mimeType: 'text/csv')],
      subject: assunto,
    );
  }

  static const _cabecalho =
      'nome;unidade;consumo_mensal;estoque_minimo;categoria;marca;'
      'codigo_de_barras;ativo';

  // ─── Exportar ──────────────────────────────────────────────────────────────
  Future<void> _exportar() async {
    setState(() => _processando = true);
    try {
      final produtos = await DatabaseHelper.instance.getProdutos();
      final sb = StringBuffer('$_cabecalho\r\n');
      for (final p in produtos) {
        sb.write([
          _csv(p.nome),
          _csv(p.unidade),
          _numCsv(p.consumoMensal),
          _numCsv(p.estoqueMinimo),
          _csv(p.categoriaNome ?? ''),
          _csv(p.marca ?? ''),
          _csv(p.codigoBarras ?? ''),
          p.ativo ? 'sim' : 'nao',
        ].join(';'));
        sb.write('\r\n');
      }
      final agora = DateTime.now();
      await _compartilharCsv(
        sb.toString(),
        'produtos_minha_despensa_${agora.year}${_2d(agora.month)}${_2d(agora.day)}.csv',
        'Produtos - Minha Despensa',
      );
    } catch (e) {
      if (mounted) _erro('Erro ao exportar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ─── Modelo em branco ──────────────────────────────────────────────────────
  Future<void> _baixarModelo() async {
    setState(() => _processando = true);
    try {
      final sb = StringBuffer('$_cabecalho\r\n');
      sb.write('Arroz branco 5kg;pct;2;1;Alimentação;Tio João;;sim\r\n');
      sb.write('Detergente neutro;un;3;1;Limpeza;;;sim\r\n');
      await _compartilharCsv(
          sb.toString(), 'modelo_produtos.csv', 'Modelo de produtos');
    } catch (e) {
      if (mounted) _erro('Erro ao gerar o modelo: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ─── Importar ──────────────────────────────────────────────────────────────
  Future<_ResultadoLeitura> _analisar(String texto) async {
    final res = _ResultadoLeitura();
    final linhas = _lerCsv(texto);

    final iCab = linhas.indexWhere((l) => l.any((c) => c.trim().isNotEmpty));
    if (iCab < 0) {
      res.erros.add('O arquivo está vazio.');
      return res;
    }

    // Descobre em qual coluna está cada campo (pelo título, em qualquer ordem)
    final col = <String, int>{};
    final cab = linhas[iCab];
    for (var j = 0; j < cab.length; j++) {
      final h = _norm(cab[j]).replaceAll(RegExp(r'[^a-z0-9]'), '');
      _aliases.forEach((campo, nomes) {
        if (nomes.contains(h) && !col.containsKey(campo)) col[campo] = j;
      });
    }
    if (!col.containsKey('nome')) {
      res.erros.add('Não achei a coluna "nome" na primeira linha. '
          'Use o modelo (botão "Baixar modelo").');
      return res;
    }

    final banco = DatabaseHelper.instance;
    final cats = await banco.getCategorias();
    final unidades = await banco.getUnidades();
    final existentes = await banco.getProdutos();

    final catPorNome = <String, int?>{
      for (final c in cats) _norm(c.nome): c.id,
    };
    final outrosId = catPorNome['outros'];
    final unidadePorSigla = <String, String>{
      for (final u in unidades) u.trim().toLowerCase(): u,
    };

    final chavesApp = <String>{};
    final codigosApp = <String>{};
    for (final p in existentes) {
      chavesApp.add('${_norm(p.nome)}|${_norm(p.marca ?? '')}');
      final cb = (p.codigoBarras ?? '').trim();
      if (cb.isNotEmpty) codigosApp.add(cb);
    }
    final chavesArquivo = <String>{};
    final codigosArquivo = <String>{};

    // Vagas na versão grátis (a licença ativa não tem limite)
    final int? vagas =
        Licenca.ativa ? null : (Licenca.limiteProdutos - existentes.length);
    res.limiteLivre = vagas;

    String celula(List<String> l, String campo) {
      final j = col[campo];
      if (j == null || j >= l.length) return '';
      return l[j].trim();
    }

    for (var k = iCab + 1; k < linhas.length; k++) {
      final l = linhas[k];
      if (l.every((c) => c.trim().isEmpty)) continue;
      final n = k + 1; // número da linha na planilha

      final nome = celula(l, 'nome');
      if (nome.isEmpty) {
        res.erros.add('Linha $n: sem nome');
        continue;
      }
      final rotulo = 'Linha $n ($nome)';

      final consumo = _lerNumero(celula(l, 'consumo'));
      if (consumo == null) {
        res.erros.add('$rotulo: consumo mensal inválido "${celula(l, 'consumo')}"');
        continue;
      }
      final minimo = _lerNumero(celula(l, 'minimo'));
      if (minimo == null) {
        res.erros.add('$rotulo: estoque mínimo inválido "${celula(l, 'minimo')}"');
        continue;
      }
      final ativo = _lerAtivo(celula(l, 'ativo'));
      if (ativo == null) {
        res.erros.add('$rotulo: "ativo" deve ser sim ou nao');
        continue;
      }

      final marca = celula(l, 'marca');
      final codigo =
          _lerCodigo(celula(l, 'codigo'), (m) => res.avisos.add('$rotulo: $m'));

      // Já existe? (mesmo nome + marca, ou mesmo código de barras)
      final chave = '${_norm(nome)}|${_norm(marca)}';
      final descricao = marca.isEmpty ? nome : '$nome ($marca)';
      if (chavesApp.contains(chave) ||
          (codigo != null && codigosApp.contains(codigo))) {
        res.jaExistem.add(descricao);
        continue;
      }
      if (chavesArquivo.contains(chave) ||
          (codigo != null && codigosArquivo.contains(codigo))) {
        res.repetidos.add(descricao);
        continue;
      }

      if (vagas != null && res.novos.length >= vagas) {
        res.foraDoLimite++;
        continue;
      }

      // Categoria: se não existir no app, usa "Outros"
      final catTxt = celula(l, 'categoria');
      int? catId = outrosId;
      if (catTxt.isNotEmpty) {
        final chaveCat = _norm(catTxt);
        if (catPorNome.containsKey(chaveCat)) {
          catId = catPorNome[chaveCat];
        } else {
          res.avisos.add('$rotulo: categoria "$catTxt" não existe, usei "Outros"');
        }
      }

      // Unidade: se não existir no app, usa "un"
      final unTxt = celula(l, 'unidade');
      var un = 'un';
      if (unTxt.isNotEmpty) {
        final achada = unidadePorSigla[unTxt.toLowerCase()];
        if (achada != null) {
          un = achada;
        } else {
          res.avisos.add('$rotulo: unidade "$unTxt" não existe, usei "un"');
        }
      }

      chavesArquivo.add(chave);
      if (codigo != null) codigosArquivo.add(codigo);
      res.novos.add(_LinhaProduto(
        nome: nome,
        unidade: un,
        consumo: consumo,
        minimo: minimo,
        categoriaId: catId,
        marca: marca.isEmpty ? null : marca,
        codigo: codigo,
        ativo: ativo,
      ));
    }
    return res;
  }

  Future<void> _gravar(List<_LinhaProduto> novos) async {
    final d = await DatabaseHelper.instance.db;
    final agora = DateTime.now().toIso8601String();
    // Tudo numa transação: se algo falhar, nenhum produto fica pela metade.
    await d.transaction((txn) async {
      for (final p in novos) {
        await txn.insert('produtos', {
          'nome': p.nome,
          'unidade': p.unidade,
          'consumo_mensal': p.consumo,
          'estoque_minimo': p.minimo,
          'categoria_id': p.categoriaId,
          'marca': p.marca,
          'ativo': p.ativo ? 1 : 0,
          'criado_em': agora,
          'codigo_barras': p.codigo,
        });
      }
    });
  }

  Future<void> _importar() async {
    if (_somenteComLicenca && !Licenca.ativa) {
      await _aviso('Recurso da versão completa',
          'Importar produtos é um recurso da versão completa. Ative sua '
          'licença em Configurações.');
      return;
    }

    final escolha = await FilePicker.platform.pickFiles(type: FileType.any);
    if (escolha == null || escolha.files.single.path == null) return;

    setState(() => _processando = true);
    _ResultadoLeitura? res;
    try {
      final bytes = await File(escolha.files.single.path!).readAsBytes();
      res = await _analisar(_decodificar(bytes));
    } catch (e) {
      if (mounted) _erro('Não consegui ler o arquivo: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
    if (res == null || !mounted) return;

    if (res.limiteLivre != null && res.limiteLivre! <= 0) {
      await _aviso('Limite da versão grátis',
          'A versão grátis permite até ${Licenca.limiteProdutos} produtos e '
          'você já chegou nesse limite. Ative sua licença pra importar mais.');
      return;
    }

    final confirmou = await _mostrarPrevia(res);
    if (confirmou != true || !mounted) return;

    setState(() => _processando = true);
    try {
      await _gravar(res.novos);
      if (mounted) {
        final n = res.novos.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(n == 1
                ? '1 produto importado.'
                : '$n produtos importados.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) _erro('Erro ao gravar. Nenhum produto foi importado: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Widget _linhaResumo(IconData icone, Color cor, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 6),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _listaCurta(List<String> itens, {int max = 5}) {
    if (itens.isEmpty) return const SizedBox.shrink();
    final mostra = itens.take(max).toList();
    final resto = itens.length - mostra.length;
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final t in mostra)
          Text('• $t',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        if (resto > 0)
          Text('… e mais $resto',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }

  Future<bool?> _mostrarPrevia(_ResultadoLeitura r) {
    final temNovos = r.novos.isNotEmpty;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar produtos?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _linhaResumo(
                  Icons.check_circle_outline,
                  temNovos ? AppTheme.success : Colors.grey,
                  '${r.novos.length} ${r.novos.length == 1 ? 'produto novo será cadastrado' : 'produtos novos serão cadastrados'}'),
              _listaCurta(r.novos.map((p) => p.nome).toList()),
              if (r.jaExistem.isNotEmpty) ...[
                _linhaResumo(Icons.block, Colors.grey,
                    '${r.jaExistem.length} já existem (mesmo nome e marca) e serão ignorados'),
                _listaCurta(r.jaExistem),
              ],
              if (r.repetidos.isNotEmpty) ...[
                _linhaResumo(Icons.content_copy, Colors.grey,
                    '${r.repetidos.length} repetidos dentro do arquivo (só o primeiro entra)'),
                _listaCurta(r.repetidos),
              ],
              if (r.foraDoLimite > 0)
                _linhaResumo(Icons.lock_outline, AppTheme.warning,
                    '${r.foraDoLimite} ficaram de fora pelo limite de ${Licenca.limiteProdutos} produtos da versão grátis'),
              if (r.erros.isNotEmpty) ...[
                _linhaResumo(Icons.error_outline, AppTheme.danger,
                    '${r.erros.length} com erro (não serão importados)'),
                _listaCurta(r.erros),
              ],
              if (r.avisos.isNotEmpty) ...[
                _linhaResumo(Icons.info_outline, AppTheme.warning,
                    '${r.avisos.length} ${r.avisos.length == 1 ? 'aviso' : 'avisos'}'),
                _listaCurta(r.avisos),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(temNovos ? 'Cancelar' : 'Fechar')),
          if (temNovos)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: Text('Importar (${r.novos.length})'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / exportar produtos')),
      body: AbsorbPointer(
        absorbing: _processando,
        child: Opacity(
          opacity: _processando ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB5D4F4)),
                ),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monte sua lista de produtos numa planilha (Excel), '
                        'salve como CSV e importe aqui.',
                        style:
                            TextStyle(color: Color(0xFF0C447C), fontSize: 13),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'No Excel: Arquivo > Salvar como > CSV (ou CSV UTF-8). '
                        'Produtos com o mesmo nome e marca de um já cadastrado '
                        'são ignorados. Categoria ou unidade que não existir '
                        'no app vira "Outros" / "un".',
                        style:
                            TextStyle(color: Color(0xFF0C447C), fontSize: 12),
                      ),
                    ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.upload_file_outlined,
                      color: AppTheme.primary),
                  title: const Text('Importar produtos (CSV)'),
                  subtitle: const Text(
                      'Escolha o arquivo; você vê uma prévia antes de gravar',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _importar,
                ),
              ),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download_outlined,
                      color: AppTheme.primary),
                  title: const Text('Baixar modelo'),
                  subtitle: const Text(
                      'CSV com as colunas certas e 2 exemplos (apague antes de importar)',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _baixarModelo,
                ),
              ),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.ios_share_outlined,
                      color: AppTheme.primary),
                  title: const Text('Exportar produtos (CSV)'),
                  subtitle: const Text(
                      'Gera um arquivo com todos os produtos pra abrir no Excel',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _exportar,
                ),
              ),
              if (_processando) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
