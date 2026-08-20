// ignore_for_file: avoid_print
//
// FERRAMENTA DO JEAN - roda só no seu computador, nunca vai pro celular
// do cliente e nunca é publicada.
//
// USO:
//   dart run tool/gerar_licenca.dart cliente@email.com "(21) 99999-9999" [validade] [idAparelho]
//
// O "idAparelho" é opcional, mas RECOMENDADO: sem ele a licença ativa em
// qualquer celular que souber o e-mail/telefone. Com ele, só ativa nesse
// aparelho específico. O cliente te manda esse ID (vem junto no e-mail
// de solicitação, campo "ID do aparelho").
//
// Exemplo sem trava por aparelho (licença "solta"):
//   dart run tool/gerar_licenca.dart cliente@email.com "(21) 99999-9999"
//
// Exemplo travado no aparelho do cliente:
//   dart run tool/gerar_licenca.dart cliente@email.com "(21) 99999-9999" "" a1b2c3d4e5f6
//
// Gera um código de licença assinado com a chave PRIVADA (arquivo
// tool/chave_privada.txt, que fica só no seu PC - NUNCA sobe pro GitHub,
// confere se está no .gitignore). Manda o código gerado pro cliente por
// WhatsApp/e-mail; ele cola em Configurações > Ativar licença completa.

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Uso: dart run tool/gerar_licenca.dart <email> <telefone> [validade AAAA-MM-DD]');
    exit(1);
  }

  final email = args[0];
  final telefone = args[1];
  final validadeRaw = args.length > 2 ? args[2].trim() : '';
  final validade = validadeRaw.isEmpty ? null : validadeRaw;
  final idAparelhoRaw = args.length > 3 ? args[3].trim() : '';
  final idAparelho = idAparelhoRaw.isEmpty ? null : idAparelhoRaw;

  final chavePrivadaArquivo = File('tool/chave_privada.txt');
  if (!await chavePrivadaArquivo.exists()) {
    print('ERRO: tool/chave_privada.txt não encontrado.');
    print('Cole ali a chave privada que o Claude te passou (uma linha, base64).');
    exit(1);
  }
  final chavePrivadaB64 = (await chavePrivadaArquivo.readAsString()).trim();

  final payload = <String, dynamic>{
    'email': email,
    'telefone': telefone,
    'emitido': DateTime.now().toIso8601String().split('T').first,
    if (validade != null) 'validade': validade,
    if (idAparelho != null) 'idAparelho': idAparelho,
  };

  final payloadBytes = utf8.encode(jsonEncode(payload));

  final algoritmo = Ed25519();
  final chavePar = await algoritmo.newKeyPairFromSeed(base64.decode(chavePrivadaB64));
  final assinatura = await algoritmo.sign(payloadBytes, keyPair: chavePar);

  final codigo =
      '${base64Url.encode(payloadBytes).replaceAll('=', '')}.${base64Url.encode(assinatura.bytes).replaceAll('=', '')}';

  print('');
  print('=== LICENÇA GERADA ===');
  print('E-mail:    $email');
  print('Telefone:  $telefone');
  print('Emitido:   ${payload['emitido']}');
  if (validade != null) print('Validade:  $validade');
  print('Aparelho:  ${idAparelho ?? '(sem trava - ativa em qualquer aparelho)'}');
  print('');
  print('CÓDIGO (manda esse texto pro cliente):');
  print(codigo);
  print('');
}
