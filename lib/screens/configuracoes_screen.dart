import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../theme.dart';
import 'importar_lista_screen.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});
  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  bool _processando = false;

  Future<void> _fazerBackup() async {
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
                  subtitle: const Text(
                      'Gera um arquivo com tudo (produtos, listas, histórico) pra guardar ou enviar',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _fazerBackup,
                ),
              ),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restore_outlined, color: AppTheme.warning),
                  title: const Text('Restaurar backup'),
                  subtitle: const Text(
                      'Substitui TODOS os dados atuais pelos de um arquivo de backup',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _restaurarBackup,
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
                    const Text('Versão 1.0.0',
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
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
