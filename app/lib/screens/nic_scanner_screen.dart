import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NicScannerScreen extends StatefulWidget {
  const NicScannerScreen({super.key});

  @override
  State<NicScannerScreen> createState() => _NicScannerScreenState();
}

class _NicScannerScreenState extends State<NicScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camCtrl;
  final TextRecognizer _recognizer = TextRecognizer();

  bool _isProcessing = false;
  bool _nicDetected = false;
  bool _capturing = false;
  String? _detectedNic;
  int _frameCount = 0;
  int _stableCount = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Pakistani NIC: 13 digits, optionally with dashes (XXXXX-XXXXXXX-X)
  static final RegExp _nicPattern =
      RegExp(r'\b\d{5}[-\s]?\d{7}[-\s]?\d\b|\b\d{13}\b');

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _camCtrl = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _camCtrl!.initialize();
    if (!mounted) return;
    setState(() {});
    _camCtrl!.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) async {
    _frameCount++;
    // Process every 20th frame to avoid overload
    if (_frameCount % 20 != 0 || _isProcessing || _capturing) return;
    _isProcessing = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final result = await _recognizer.processImage(inputImage);
      final rawText = result.text.replaceAll('\n', ' ');
      final match = _nicPattern.firstMatch(rawText);

      if (match != null) {
        final raw = match.group(0)!.replaceAll(RegExp(r'[-\s]'), '');
        if (raw.length == 13) {
          final formatted =
              '${raw.substring(0, 5)}-${raw.substring(5, 12)}-${raw[12]}';
          _stableCount++;

          if (mounted) {
            setState(() {
              _nicDetected = true;
              _detectedNic = formatted;
            });
          }

          // Auto-capture after 2 stable detections (~1.5s)
          if (_stableCount >= 2 && !_capturing) {
              await _autoCapture(formatted);
            }
        }
      } else {
        _stableCount = 0;
        if (mounted && _nicDetected) setState(() => _nicDetected = false);
      }
    } catch (_) {}

    _isProcessing = false;
  }

  Future<void> _autoCapture(String nicNumber) async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      await _camCtrl?.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 200));
      final xFile = await _camCtrl?.takePicture();
      if (xFile != null && mounted) {
        Navigator.pop(context, {
          'nic': nicNumber,
          'image': File(xFile.path),
        });
      }
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final WriteBuffer buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      final bytes = buffer.done().buffer.asUint8List();
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation90deg,
          format: InputImageFormat.yuv_420_888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _camCtrl?.stopImageStream();
    _camCtrl?.dispose();
    _recognizer.close();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady =
        _camCtrl != null && _camCtrl!.value.isInitialized && !_capturing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (isReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camCtrl!.value.previewSize!.height,
                  height: _camCtrl!.value.previewSize!.width,
                  child: CameraPreview(_camCtrl!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Dark overlay with NIC frame cutout
          if (isReady)
            CustomPaint(
              painter: _NicOverlayPainter(detected: _nicDetected),
              child: const SizedBox.expand(),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'NIC Card Scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Capturing indicator
          if (_capturing)
            Container(
              color: Colors.white24,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Capturing...',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          // Bottom status
          if (!_capturing)
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _nicDetected
                        ? _buildDetectedBadge()
                        : _buildScanHint(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectedBadge() {
    return Container(
      key: const ValueKey('detected'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            'NIC mila: $_detectedNic',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanHint() {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        key: const ValueKey('hint'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          children: [
            Text(
              'NIC card ko frame ke andar rakho',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Number detect hote hi photo khud le ga',
              style: TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NicOverlayPainter extends CustomPainter {
  final bool detected;
  const _NicOverlayPainter({required this.detected});

  @override
  void paint(Canvas canvas, Size size) {
    // NIC card ratio (85.6mm × 53.98mm = ~1.586:1)
    final frameW = size.width * 0.88;
    final frameH = frameW / 1.586;
    final frameX = (size.width - frameW) / 2;
    final frameY = (size.height - frameH) / 2 - 20;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(frameX, frameY, frameW, frameH),
      const Radius.circular(10),
    );

    // Dark backdrop with cutout
    final backdrop = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, backdrop);

    // Frame border
    final borderColor = detected ? Colors.greenAccent : Colors.white;
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner highlights
    final corner = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cLen = 22.0;

    // Top-left
    canvas.drawLine(Offset(frameX, frameY + cLen), Offset(frameX, frameY), corner);
    canvas.drawLine(Offset(frameX, frameY), Offset(frameX + cLen, frameY), corner);
    // Top-right
    canvas.drawLine(Offset(frameX + frameW - cLen, frameY), Offset(frameX + frameW, frameY), corner);
    canvas.drawLine(Offset(frameX + frameW, frameY), Offset(frameX + frameW, frameY + cLen), corner);
    // Bottom-left
    canvas.drawLine(Offset(frameX, frameY + frameH - cLen), Offset(frameX, frameY + frameH), corner);
    canvas.drawLine(Offset(frameX, frameY + frameH), Offset(frameX + cLen, frameY + frameH), corner);
    // Bottom-right
    canvas.drawLine(Offset(frameX + frameW - cLen, frameY + frameH), Offset(frameX + frameW, frameY + frameH), corner);
    canvas.drawLine(Offset(frameX + frameW, frameY + frameH), Offset(frameX + frameW, frameY + frameH - cLen), corner);
  }

  @override
  bool shouldRepaint(_NicOverlayPainter old) => old.detected != detected;
}
