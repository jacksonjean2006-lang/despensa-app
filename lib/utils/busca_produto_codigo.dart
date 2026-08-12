import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../models/produto.dart';

/// Resultado da busca de um produto por código de barras/QR.
class ResultadoBuscaCodigo {
  final Produto? produtoCadastrado;
  final String? nomeSugeridoInternet;
  const ResultadoBuscaCodigo({this.produtoCadastrado, this.nomeSugeridoInternet});

  bool get encontrouNoCadastro => produtoCadastrado != null;
}

/// Busca um produto por código de barras/QR: primeiro no cadastro local
/// (rápido, funciona offline), e só se não achar tenta a internet (Open
/// Food Facts, base pública e gratuita) pra sugerir um nome pronto na
/// hora de cadastrar.
Future<ResultadoBuscaCodigo> buscarProdutoPorCodigo(String codigo) async {
  final local = await DatabaseHelper.instance.buscarProdutoPorCodigoBarras(codigo);
  if (local != null) {
    return ResultadoBuscaCodigo(produtoCadastrado: local);
  }

  final nome = await _buscarNomeNaInternet(codigo);
  return ResultadoBuscaCodigo(nomeSugeridoInternet: nome);
}

Future<String?> _buscarNomeNaInternet(String codigo) async {
  try {
    final resp = await http
        .get(Uri.parse('https://world.openfoodfacts.org/api/v2/product/$codigo.json'))
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;

    final dados = jsonDecode(resp.body) as Map<String, dynamic>;
    if (dados['status'] != 1) return null;

    final produto = dados['product'] as Map<String, dynamic>?;
    final nome = (produto?['product_name'] as String?)?.trim();
    final marca = (produto?['brands'] as String?)?.trim();
    if (nome == null || nome.isEmpty) return null;

    return marca != null && marca.isNotEmpty ? '$nome ($marca)' : nome;
  } catch (_) {
    // sem internet, timeout, ou API fora - segue sem sugest\u00e3o
    return null;
  }
}
