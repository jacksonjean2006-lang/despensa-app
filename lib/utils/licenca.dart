import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_id/android_id.dart';

/// Sistema de licença do app.
///
/// Como funciona: o Jean gera um código de licença OFFLINE, no computador
/// dele, com a ferramenta em `tool/gerar_licenca.dart` (que usa a chave
/// PRIVADA - essa nunca entra no app nem no GitHub). O app aqui só guarda
/// a chave PÚBLICA, que serve só pra CONFERIR se um código é válido, nunca
/// pra criar um novo. Ou seja: mesmo alguém descompilando o app inteiro,
/// não consegue forjar uma licença válida.
///
/// O código de licença carrega e-mail, telefone e data de emissão de quem
/// comprou. Além de validar a assinatura, a ativação exige que o cliente
/// digite o MESMO e-mail e telefone gravados na licença - assim só quem
/// sabe esses dados consegue ativar (não é uma trava perfeita, mas evita
/// o caso comum de simplesmente repassar o código pra outra pessoa).
class Licenca {
  // Chave pública Ed25519 (base64) - pode ficar exposta no app sem
  // problema, ela só verifica, não assina.
  static const _chavePublicaB64 = 'F1Lfkz/vqUKm6wOT/09wkTzBwCcnv1td+zpbWrnYYMY=';

  static Map<String, dynamic>? _payload;
  static bool _carregado = false;

  static bool get ativa => _payload != null;
  static String? get email => _payload?['email'] as String?;
  static String? get telefone => _payload?['telefone'] as String?;
  static String? get emitidoEm => _payload?['emitido'] as String?;
  static String? get nome => _payload?['nome'] as String?;

  /// Data de validade gravada na licença, se houver (null = licença sem
  /// prazo, nunca vence).
  static DateTime? get validade {
    final raw = _payload?['validade'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// true se a licença tem validade E ela já passou. NÃO desativa nada
  /// sozinho - a licença continua liberando os recursos normalmente,
  /// isso serve só pra mostrar um aviso pedindo renovação.
  static bool get expirada {
    final v = validade;
    if (v == null) return false;
    // Considera o dia inteiro da validade como válido (vence à meia-noite
    // do dia seguinte), pra não expirar de surpresa no meio do dia certo.
    final fimDoDia = DateTime(v.year, v.month, v.day, 23, 59, 59);
    return DateTime.now().isAfter(fimDoDia);
  }

  /// Chama uma vez no início do app (ex: no main ou splash) pra carregar
  /// a licença já ativada anteriormente, se houver.
  static Future<void> carregar() async {
    if (_carregado) return;
    _carregado = true;
    try {
      final arquivo = await _arquivoLicenca();
      if (!await arquivo.exists()) return;
      final codigo = await arquivo.readAsString();
      final payload = await _verificar(codigo.trim());
      _payload = payload;
    } catch (_) {
      _payload = null;
    }
  }

  /// Tenta ativar um código de licença colado pelo usuário, exigindo que
  /// o e-mail/telefone digitados batam com os gravados na licença.
  /// Retorna null se inválido (código errado OU dados não conferem), ou
  /// o payload se válido - e já salva pra persistir entre aberturas.
  static Future<Map<String, dynamic>?> ativar(
    String codigo, {
    required String emailDigitado,
    required String telefoneDigitado,
  }) async {
    final payload = await _verificar(codigo.trim());
    if (payload == null) return null;

    final emailOk = _normalizarEmail(payload['email'] as String? ?? '') ==
        _normalizarEmail(emailDigitado);
    final telefoneOk = _normalizarTelefone(payload['telefone'] as String? ?? '') ==
        _normalizarTelefone(telefoneDigitado);

    // Trava por aparelho: se a licença tiver um idAparelho gravado, só
    // ativa se bater com o ID deste celular. Licenças antigas (geradas
    // antes dessa trava existir) não têm esse campo, então continuam
    // funcionando normalmente em qualquer aparelho.
    final idGravado = (payload['idAparelho'] as String?)?.trim() ?? '';
    final idOk = idGravado.isEmpty || idGravado == await idAparelho();

    if (!emailOk || !telefoneOk || !idOk) return null;

    _payload = payload;
    final arquivo = await _arquivoLicenca();
    await arquivo.writeAsString(codigo.trim());
    return payload;
  }

  static String _normalizarEmail(String s) => s.trim().toLowerCase();
  static String _normalizarTelefone(String s) =>
      s.replaceAll(RegExp(r'[^0-9]'), '');

  /// ID único do aparelho (Settings.Secure.ANDROID_ID). Muda se o cliente
  /// trocar de celular ou fizer reset de fábrica - nesses casos precisa
  /// gerar uma licença nova pra ele.
  static Future<String> idAparelho() async {
    try {
      final id = await const AndroidId().getId();
      return id ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> desativar() async {
    _payload = null;
    final arquivo = await _arquivoLicenca();
    if (await arquivo.exists()) await arquivo.delete();
  }

  static Future<File> _arquivoLicenca() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/licenca.txt');
  }

  /// Formato do código: <payload_json_base64url>.<assinatura_base64url>
  static Future<Map<String, dynamic>?> _verificar(String codigo) async {
    try {
      final partes = codigo.split('.');
      if (partes.length != 2) return null;

      final payloadBytes = base64Url.decode(_comPadding(partes[0]));
      final assinaturaBytes = base64Url.decode(_comPadding(partes[1]));

      final algoritmo = Ed25519();
      final chavePublica = SimplePublicKey(
        base64.decode(_chavePublicaB64),
        type: KeyPairType.ed25519,
      );

      final valido = await algoritmo.verify(
        payloadBytes,
        signature: Signature(assinaturaBytes, publicKey: chavePublica),
      );
      if (!valido) return null;

      final payload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      return payload;
    } catch (_) {
      return null;
    }
  }

  static String _comPadding(String s) {
    final resto = s.length % 4;
    if (resto == 0) return s;
    return s + ('=' * (4 - resto));
  }

  // ─── Limites da versão grátis ────────────────────────────────────────────
  static const limiteProdutos = 30;

  static bool podeAdicionarProduto(int totalAtual) =>
      ativa || totalAtual < limiteProdutos;

  static bool get podeUsarBackup => ativa;

  /// Restaurar (diferente de fazer/exportar) exige a licença EM DIA - se
  /// vencer, para de deixar restaurar, mesmo que a pessoa desinstale e
  /// reinstale o app ou reative o mesmo código de novo (o vencimento é
  /// sempre recalculado comparando a data gravada no código com a data
  /// atual do aparelho, não tem como burlar reinstalando).
  static bool get podeRestaurarBackup => ativa && !expirada;
  static bool get podeCriarCategoriaOuUnidade => ativa;

  /// Mostra um dialog padrão explicando que o recurso é só da versão
  /// completa (ou que a licença venceu). Retorna true se o usuário tocou
  /// no botão de ação (quem chamou decide pra onde navegar).
  static Future<bool> mostrarBloqueio(BuildContext context, String motivo,
      {String botao = 'Ativar licença'}) async {
    final ir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(expirada ? 'Licença vencida' : 'Recurso da versão completa'),
        content: Text(motivo),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Fechar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(botao),
          ),
        ],
      ),
    );
    return ir ?? false;
  }
}
