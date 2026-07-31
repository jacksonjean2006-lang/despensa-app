import 'dart:convert';
import '../models/lista_item.dart';

/// Formata e interpreta o texto compartilhado de uma lista de compras.
///
/// O texto tem duas partes:
///  1. Um resumo legível (o que a pessoa vê no WhatsApp/e-mail)
///  2. Um bloco de dados estruturado (JSON em base64, entre marcadores)
///     que o próprio app usa pra reconstruir a lista EXATAMENTE igual,
///     incluindo quantidade, unidade, categoria e marca de cada item.
class ListaCompartilhar {
  static const _marcadorInicio = '::DESPENSA_LISTA::';
  static const _marcadorFim = '::FIM_DESPENSA_LISTA::';

  /// Monta o texto completo pra compartilhar via WhatsApp, e-mail, etc.
  static String gerarTexto({
    required String descricao,
    required List<ListaItem> itens,
    required Map<int, Map<String, String?>> infoProdutoPorId,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🛒 $descricao');
    buffer.writeln('📦 ${itens.length} ite${itens.length == 1 ? 'm' : 'ns'}');
    buffer.writeln();
    for (final i in itens) {
      final check = i.marcado ? '✅' : '⬜';
      final qtdTxt = _formatarQtd(i.quantidade);
      buffer.writeln('$check ${i.nomeExibicao} — $qtdTxt ${i.unidade}');
    }
    buffer.writeln();
    buffer.writeln('――――――――――――――――――');
    buffer.writeln('📱 Enviado pelo app Minha Despensa');
    buffer.writeln(
        'Pra importar: copie esta mensagem inteira e cole em');
    buffer.writeln('Minha Despensa > Importar lista');
    buffer.writeln();

    final itensJson = itens.map((i) {
      final info = i.produtoId != null ? infoProdutoPorId[i.produtoId] : null;
      return {
        'nome': i.nomeExibicao,
        'marca': info?['marca'],
        'categoria': info?['categoriaNome'],
        'categoriaIcone': info?['categoriaIcone'] ?? i.categoriaIcone,
        'quantidade': i.quantidade,
        'unidade': i.unidade,
        'marcado': i.marcado,
        'substituto': i.substituto,
      };
    }).toList();

    final payload = {
      'tipo': 'lista_compras',
      'versao': 1,
      'descricao': descricao,
      'itens': itensJson,
    };

    final jsonStr = jsonEncode(payload);
    final base64Str = base64Encode(utf8.encode(jsonStr));
    buffer.write('$_marcadorInicio$base64Str$_marcadorFim');

    return buffer.toString();
  }

  static String _formatarQtd(double qtd) {
    if (qtd == qtd.roundToDouble()) return qtd.toStringAsFixed(0);
    return qtd.toStringAsFixed(2);
  }

  /// Tenta extrair os dados estruturados de um texto colado pelo usuário.
  /// Retorna null se o texto não contiver um bloco de dados válido.
  static Map<String, dynamic>? extrairDados(String textoColado) {
    final inicio = textoColado.indexOf(_marcadorInicio);
    final fim = textoColado.indexOf(_marcadorFim);
    if (inicio == -1 || fim == -1 || fim <= inicio) return null;

    final base64Str =
        textoColado.substring(inicio + _marcadorInicio.length, fim).trim();
    try {
      final jsonStr = utf8.decode(base64Decode(base64Str));
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['tipo'] != 'lista_compras') return null;
      return data;
    } catch (_) {
      return null;
    }
  }
}
