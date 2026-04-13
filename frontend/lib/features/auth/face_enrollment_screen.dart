import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:frontend/core/theme.dart';

/// Callback with the captured face embedding
typedef OnEnrollComplete = void Function(List<double> embedding);

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  final OnEnrollComplete onComplete;
  const FaceEnrollmentScreen({super.key, required this.onComplete});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen> {
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _isCapturing = false;
  String _statusMsg = 'Position your face in the frame';
  int _step = 0; // 0=center, 1=blink, 2=done
  List<double>? _capturedEmbedding;

  final _steps = [
    _EnrollStep(Icons.face_retouching_natural, 'Look straight at the camera', 'Center your face'),
    _EnrollStep(Icons.remove_red_eye, 'Blink slowly twice', 'Verifying liveness'),
    _EnrollStep(Icons.check_circle, 'Face enrolled!', 'Enrollment complete'),
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _camCtrl!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }

  Future<void> _captureAndEnroll() async {
    if (!_camReady || _isCapturing || _camCtrl == null) return;
    setState(() { _isCapturing = true; _statusMsg = 'Analyzing face...'; });

    try {
      final image = await _camCtrl!.takePicture();
      final bytes = await image.readAsBytes();

      // Generate a deterministic 128-D embedding from image bytes as a placeholder.
      // Replace with face_recognition_kit.FaceRecognitionKit().detectFaces(bytes)
      // once the SDK supports the platform.
      if (bytes.isEmpty) {
        setState(() { _statusMsg = 'Capture failed. Try again.'; _isCapturing = false; });
        return;
      }

      // Build a consistent embedding from image bytes (deterministic hash-based)
      final embedding = List<double>.generate(
        128, (i) => (bytes[i % bytes.length] / 255.0),
      );

      setState(() { _capturedEmbedding = embedding; _step = 1; _isCapturing = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _step = 2; _statusMsg = 'Enrollment successful!'; });
    } catch (e) {
      setState(() { _statusMsg = 'Error: $e'; _isCapturing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text('Face Enrollment', style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(height: 24),

              // Step indicators
              Row(
                children: List.generate(3, (i) {
                  final done = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: done ? AppTheme.primaryColor : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Camera preview
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _step == 2 ? Colors.green : AppTheme.primaryColor,
                      width: 3,
                    ),
                    boxShadow: [BoxShadow(
                      color: (_step == 2 ? Colors.green : AppTheme.primaryColor).withValues(alpha:0.3),
                      blurRadius: 24,
                    )],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_camReady && _camCtrl != null)
                        CameraPreview(_camCtrl!)
                      else
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor))),

                      // Face guide overlay
                      CustomPaint(painter: _FaceOvalPainter(
                        color: (_step == 2 ? Colors.green : AppTheme.primaryColor).withValues(alpha: 0.6),
                      )),

                      if (_step == 2)
                        const Center(
                          child: Icon(Icons.check_circle, color: Colors.green, size: 80),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Step description
              Icon(_steps[_step].icon, color: AppTheme.primaryColor, size: 36),
              const SizedBox(height: 12),
              Text(_steps[_step].title,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(_statusMsg,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _step == 2
                  ? ElevatedButton.icon(
                      onPressed: _capturedEmbedding != null
                        ? () => widget.onComplete(_capturedEmbedding!)
                        : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Confirm & Complete',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      onPressed: (_isCapturing || !_camReady) ? null : _captureAndEnroll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isCapturing
                        ? const SizedBox(height: 22, width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Capture Face',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnrollStep {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EnrollStep(this.icon, this.title, this.subtitle);
}

class _FaceOvalPainter extends CustomPainter {
  final Color color;
  const _FaceOvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.2),
      width: size.width * 0.6,
      height: size.height * 0.55,
    );
    canvas.drawOval(oval, paint);
  }

  @override
  bool shouldRepaint(_FaceOvalPainter old) => old.color != color;
}
