import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'critico':
        bg = AppTheme.dangerBg; fg = AppTheme.danger; label = 'crítico';
        break;
      case 'atencao':
        bg = AppTheme.warningBg; fg = AppTheme.warning; label = 'atenção';
        break;
      default:
        bg = AppTheme.successBg; fg = AppTheme.success; label = 'ok';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class FotoOuEmoji extends StatelessWidget {
  final String? fotoPath;
  final String? icone;
  final double size;
  const FotoOuEmoji({super.key, this.fotoPath, this.icone, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(size * 0.23),
      ),
      child: Center(
        child: fotoPath != null && fotoPath!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.23),
                child: Image.asset(fotoPath!,
                    width: size, height: size, fit: BoxFit.cover))
            : Text(icone ?? '📦',
                style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

String formatarQtd(double v, String unidade) {
  if (v == v.truncateToDouble()) {
    return '${v.toInt()} $unidade';
  }
  return '${v.toStringAsFixed(1)} $unidade';
}

String formatarMoeda(double v) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(v);

String formatarData(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return iso;
  }
}
