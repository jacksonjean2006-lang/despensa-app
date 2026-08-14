import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../theme.dart';

/// Tela de recorte de foto - roda inteiramente dentro do próprio Flutter,
/// sem abrir uma tela/Activity nativa separada. Isso evita um problema
/// sério: ao abrir uma tela nativa pesada (como o antigo image_cropper
/// usava), o Android podia matar o app em segundo plano pra liberar
/// memória, fazendo o app "reiniciar" e perder o cadastro em andamento.
class RecortarFotoScreen extends StatefulWidget {
  final Uint8List imagemOriginal;
  const RecortarFotoScreen({super.key, required this.imagemOriginal});

  @override
  State<RecortarFotoScreen> createState() => _RecortarFotoScreenState();
}

class _RecortarFotoScreenState extends State<RecortarFotoScreen> {
  final _controller = CropController();
  bool _processando = false;

  void _confirmar() {
    setState(() => _processando = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ajustar foto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _processando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 28),
            onPressed: _processando ? null : _confirmar,
          ),
        ],
      ),
      body: Crop(
        controller: _controller,
        image: widget.imagemOriginal,
        aspectRatio: 1,
        baseColor: Colors.black,
        maskColor: Colors.black.withOpacity(0.65),
        cornerDotBuilder: (size, edgeAlignment) => const DotControl(
          color: AppTheme.primary,
        ),
        interactive: true,
        onCropped: (result) {
          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.pop(context, croppedImage);
            case CropFailure():
              setState(() => _processando = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Não deu pra recortar essa foto')),
              );
          }
        },
      ),
    );
  }
}
