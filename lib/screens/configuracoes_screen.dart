import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../theme.dart';
import '../utils/atalho_tela_inicial.dart';
import '../utils/licenca.dart';
import 'importar_lista_screen.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});
  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  bool _processando = false;

  Future<void> _fazerBackup() async {
    if (!Licenca.podeUsarBackup) {
      final ir = await Licenca.mostrarBloqueio(context,
          'Backup é um recurso da versão completa. Ative sua licença pra fazer backup dos seus dados.');
      if (ir) _ativarLicenca();
      return;
    }
    setState(() => _processando = true);
    try {
      final backup = await DatabaseHelper.instance.exportarBackupCompleto();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

      final dir = await getTemporaryDirectory();
      final agora = DateTime.now();
      final nomeArquivo =
          'backup_minha_despensa_${agora.year}${_2d(agora.month)}${_2d(agora.day)}.json';
      final arquivo = File('${dir.path}/$nomeArquivo');
      await arquivo.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(arquivo.path, mimeType: 'application/json')],
        subject: 'Backup Minha Despensa',
        text: 'Backup do Minha Despensa gerado em ${_dataHora(agora)}',
      );
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao gerar backup: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  String _2d(int n) => n.toString().padLeft(2, '0');
  String _dataHora(DateTime d) =>
      '${_2d(d.day)}/${_2d(d.month)}/${d.year} ${_2d(d.hour)}:${_2d(d.minute)}';

  Future<void> _restaurarBackup() async {
    if (!Licenca.podeRestaurarBackup) {
      final venceu = Licenca.ativa && Licenca.expirada;
      final mensagem = venceu
          ? 'Sua licença venceu. Renove pra voltar a restaurar backups.'
          : 'Restaurar backup é um recurso da versão completa. Ative sua licença pra usar.';
      final ir = await Licenca.mostrarBloqueio(context, mensagem,
          botao: venceu ? 'Renovar licença' : 'Ativar licença');
      if (ir) {
        // Se já tem licença (só que vencida), leva pro fluxo de renovação;
        // se nunca teve, leva pro fluxo normal de ativar.
        if (venceu) {
          _solicitarLicenca();
        } else {
          _ativarLicenca();
        }
      }
      return;
    }
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (resultado == null || resultado.files.single.path == null) return;

    Map<String, dynamic> backup;
    try {
      final conteudo = await File(resultado.files.single.path!).readAsString();
      backup = jsonDecode(conteudo) as Map<String, dynamic>;
      if (backup['tipo'] != 'backup_minha_despensa') {
        throw Exception('Esse não é um arquivo de backup do Minha Despensa.');
      }
    } catch (e) {
      if (mounted) _mostrarErro('Arquivo inválido: $e');
      return;
    }

    if (!mounted) return;
    final geradoEm = backup['geradoEm'] as String?;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: Text(
          'Isso vai APAGAR todos os dados atuais do app (produtos, listas, '
          'histórico, tudo) e substituir pelos dados do backup'
          '${geradoEm != null ? ' de ${_dataHoraIso(geradoEm)}' : ''}.\n\n'
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Restaurar e substituir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    setState(() => _processando = true);
    try {
      await DatabaseHelper.instance.restaurarBackupCompleto(backup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restaurado com sucesso!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao restaurar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  String _dataHoraIso(String iso) {
    try {
      final d = DateTime.parse(iso);
      return _dataHora(d);
    } catch (_) {
      return iso;
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  Future<void> _ativarLicenca() async {
    final codigoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final dados = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ativar licença completa'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Cole o código de licença e confirme o e-mail e telefone usados na compra.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: codigoCtrl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Código de licença', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Seu e-mail'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telefoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Seu telefone'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (dados != true || codigoCtrl.text.trim().isEmpty) return;

    final payload = await Licenca.ativar(
      codigoCtrl.text,
      emailDigitado: emailCtrl.text,
      telefoneDigitado: telefoneCtrl.text,
    );
    if (!mounted) return;
    if (payload != null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Licença ativada com sucesso!'),
            backgroundColor: AppTheme.success),
      );
    } else {
      _mostrarErro(
          'Código inválido, ou o e-mail/telefone não conferem com essa licença.');
    }
  }

  Future<void> _desativarLicenca() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover licença?'),
        content: const Text('O app volta pra versão limitada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await Licenca.desativar();
      if (mounted) setState(() {});
    }
  }

  Future<void> _fixarNaTelaInicial() async {
    final ok = await AtalhoTelaInicial.fixarNaTelaInicial();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirme no popup do sistema para fixar o ícone')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            'Esse aparelho/lançador não suporta essa função. '
            'Segure o ícone do app na gaveta de aplicativos e arraste até a tela inicial.')),
      );
    }
  }

  /// Abre um formulário (nome, e-mail, telefone) e, ao confirmar, monta um
  /// e-mail (via app de e-mail do celular) endereçado ao desenvolvedor
  /// pedindo a licença completa. O usuário só precisa apertar "Enviar" no
  /// próprio app de e-mail que abrir - não existe envio automático em
  /// segundo plano, pra funcionar de forma confiável sem precisar de
  /// servidor próprio.
  Future<void> _solicitarLicenca() async {
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Adquirir licença completa'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Preencha seus dados. Vamos abrir seu app de e-mail com uma '
                  'solicitação pronta pra você enviar. O desenvolvedor responde '
                  'com os próximos passos e a chave de liberação.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              TextFormField(
                controller: nomeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail *'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Informe seu e-mail';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Telefone com DDD *', hintText: 'ex: (21) 91234-5678'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu telefone' : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Enviar solicitação'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    final nome = nomeCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final telefone = telefoneCtrl.text.trim();
    final idAparelho = await Licenca.idAparelho();

    final saudacao = _saudacaoPorHorario();
    final assunto = 'Solicitação de licença completa - Minha Despensa';
    final corpo = '$saudacao, $nome!\n\n'
        'Gostaria de adquirir a versão completa do app Minha Despensa.\n\n'
        'Nome completo: $nome\n'
        'E-mail: $email\n'
        'Telefone (com DDD): $telefone\n'
        'ID do aparelho: ${idAparelho.isEmpty ? '(não foi possível obter)' : idAparelho}\n';

    final uri = Uri(
      scheme: 'mailto',
      path: 'jacksonjean2006@gmail.com',
      query: _construirQueryEmail({'subject': assunto, 'body': corpo}),
    );

    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!abriu) {
      _mostrarErro('Não achei um app de e-mail instalado nesse celular.');
    }
  }

  /// Saudação de acordo com o horário atual do aparelho.
  String _saudacaoPorHorario() {
    final hora = DateTime.now().hour;
    if (hora >= 5 && hora < 12) return 'Bom dia';
    if (hora >= 12 && hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _construirQueryEmail(Map<String, String> parametros) {
    return parametros.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: AbsorbPointer(
        absorbing: _processando,
        child: Opacity(
          opacity: _processando ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _secao('LISTA DE COMPRAS'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppTheme.primary),
                  title: const Text('Importar lista de compras'),
                  subtitle: const Text(
                      'Cole uma lista que alguém te enviou pelo WhatsApp/e-mail',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ImportarListaScreen())),
                ),
              ),
              const SizedBox(height: 16),
              _secao('BACKUP'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.backup_outlined, color: AppTheme.primary),
                  title: const Text('Fazer backup'),
                  subtitle: Text(
                      Licenca.podeUsarBackup
                          ? 'Gera um arquivo com tudo (produtos, listas, histórico) pra guardar ou enviar'
                          : 'Recurso da versão completa',
                      style: const TextStyle(fontSize: 12)),
                  trailing: Licenca.podeUsarBackup
                      ? const Icon(Icons.chevron_right, color: Colors.grey)
                      : const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                  onTap: _fazerBackup,
                ),
              ),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restore_outlined, color: AppTheme.warning),
                  title: const Text('Restaurar backup'),
                  subtitle: Text(
                      Licenca.podeRestaurarBackup
                          ? 'Substitui TODOS os dados atuais pelos de um arquivo de backup'
                          : (Licenca.ativa && Licenca.expirada
                              ? 'Licença vencida - renove pra restaurar backups'
                              : 'Recurso da versão completa'),
                      style: const TextStyle(fontSize: 12)),
                  trailing: Licenca.podeRestaurarBackup
                      ? const Icon(Icons.chevron_right, color: Colors.grey)
                      : const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                  onTap: _restaurarBackup,
                ),
              ),
              const SizedBox(height: 16),
              _secao('LICENÇA'),
              Card(
                child: ListTile(
                  leading: Icon(
                      Licenca.ativa
                          ? (Licenca.expirada ? Icons.warning_amber_outlined : Icons.verified_outlined)
                          : Icons.key_outlined,
                      color: Licenca.ativa
                          ? (Licenca.expirada ? AppTheme.warning : AppTheme.success)
                          : AppTheme.primary),
                  title: Text(Licenca.ativa
                      ? (Licenca.expirada ? 'Versão completa - licença vencida' : 'Versão completa ativada')
                      : 'Ativar licença completa'),
                  subtitle: Text(
                      Licenca.ativa
                          ? (Licenca.expirada
                              ? 'Venceu em ${Licenca.validade!.day.toString().padLeft(2, '0')}/${Licenca.validade!.month.toString().padLeft(2, '0')}/${Licenca.validade!.year} · entre em contato pra renovar'
                              : 'Licenciado para ${Licenca.nome ?? Licenca.email} · desde ${Licenca.emitidoEm}')
                          : 'Você está na versão limitada',
                      style: TextStyle(
                          fontSize: 12,
                          color: Licenca.ativa && Licenca.expirada ? AppTheme.warning : null)),
                  trailing: Licenca.ativa
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          tooltip: 'Remover licença',
                          onPressed: _desativarLicenca,
                        )
                      : const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: Licenca.ativa ? null : _ativarLicenca,
                ),
              ),
              const SizedBox(height: 16),
              _secao('ATALHO'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_to_home_screen_outlined, color: AppTheme.primary),
                  title: const Text('Adicionar ícone à tela inicial'),
                  subtitle: const Text(
                      'Fixa um atalho do app no Desktop do celular (o Android vai pedir sua confirmação)',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _fixarNaTelaInicial,
                ),
              ),
              if (_processando) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 16),
              _secao('SOBRE'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Minha Despensa',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const Text('Versão 4.6.1',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    const Text('Desenvolvido por Jean',
                        style: TextStyle(fontSize: 13)),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(
                            text: 'jacksonjean2006@gmail.com'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('E-mail copiado')),
                        );
                      },
                      child: Row(children: [
                        const Icon(Icons.email_outlined,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('jacksonjean2006@gmail.com',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.primary,
                                decoration: TextDecoration.underline)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    if (!Licenca.ativa)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _solicitarLicenca,
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Adquirir licença completa'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary)),
                        ),
                      )
                    else if (Licenca.expirada)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _solicitarLicenca,
                          icon: const Icon(Icons.autorenew),
                          label: const Text('Renovar licença (venceu)'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.warning,
                              side: const BorderSide(color: AppTheme.warning)),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.verified_outlined,
                              color: AppTheme.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Licença completa já ativada neste aparelho',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              _secao('SAIR'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.exit_to_app, color: AppTheme.danger),
                  title: const Text('Sair do app'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _confirmarSair,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarSair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do app?'),
        content: const Text('Isso fecha o Minha Despensa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      SystemNavigator.pop();
    }
  }

  Widget _secao(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.4)),
      );
}
