import 'package:flutter/services.dart';

/// Pede pro Android fixar um atalho do app na tela inicial (o "Desktop"
/// do celular). Por restrição de segurança do próprio Android (a partir
/// da versão 8), isso sempre abre uma confirmação do sistema - não tem
/// como ser automático/silencioso na instalação.
class AtalhoTelaInicial {
  static const _canal = MethodChannel('despensa/atalho');

  /// Retorna true se o pedido foi enviado ao sistema (o usuário ainda
  /// precisa confirmar no popup que aparece). Retorna false se o
  /// aparelho/launcher não suporta essa função.
  static Future<bool> fixarNaTelaInicial() async {
    try {
      final ok = await _canal.invokeMethod<bool>('fixarNaTelaInicial');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
