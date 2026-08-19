import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme.dart';

/// Tela de câmera própria do app - mostra o preview e tira a foto sem abrir
/// o app de Câmera do sistema. Isso evita que o Android mate o app em
/// segundo plano por pressão de memória enquanto o app de Câmera (pesado)
/// está em primeiro plano, o que causava o app "reiniciar" e perder tudo.
class CameraCapturaScreen extends StatefulWidget {
  const CameraCapturaScreen({super.key});

  @override
  State<CameraCapturaScreen> createState() => _CameraCapturaScreenState();
}

class _CameraCapturaScreenState extends State<CameraCapturaScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _inicializacao;
  bool _capturando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _erro = 'Nenhuma câmera encontrada nesse aparelho.');
        return;
      }
      final traseira = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        traseira,
        ResolutionPreset.medium, // suficiente pra foto de produto, mais leve
        enableAudio: false,
      );
      _inicializacao = _controller!.initialize();
      await _inicializacao;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _erro = 'Não foi possível abrir a câmera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _iniciar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _tirarFoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturando) {
      return;
    }
    setState(() => _capturando = true);
    try {
      final foto = await controller.takePicture();
      if (mounted) Navigator.pop(context, foto.path);
    } catch (e) {
      setState(() => _capturando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao tirar foto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Tirar foto'),
      ),
      body: SafeArea(
        child: _erro != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_erro!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center),
                ),
              )
            : FutureBuilder(
                future: _inicializacao,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      _controller == null) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(child: CameraPreview(_controller!)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: GestureDetector(
                          onTap: _tirarFoto,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                  color: AppTheme.primary, width: 4),
                            ),
                            child: _capturando
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary, strokeWidth: 3),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
