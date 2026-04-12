import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../exam/exam_screen.dart';

class FaceAuthScreen extends StatefulWidget {
  final Map<String, dynamic>? examData;
  const FaceAuthScreen({super.key, this.examData});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }

      // Prefer front camera
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString().contains('Permission')
            ? 'Camera permission denied. Please allow camera access in your browser and refresh.'
            : 'Camera could not start. Make sure no other app is using it.');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile file = await _controller!.takePicture();
      final Uint8List rawBytes = await file.readAsBytes();
      
      // Compress the image to a small thumbnail to keep the upload size small
      final Uint8List compressedBytes = await _compressImage(rawBytes, maxSize: 300);
      final String base64Image = base64Encode(compressedBytes);

      if (mounted) _showConfirmDialog(compressedBytes, base64Image);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Failed to capture photo. Please try again.';
        });
      }
    }
  }

  /// Resize and compress image bytes to a small JPEG thumbnail
  Future<Uint8List> _compressImage(Uint8List bytes, {int maxSize = 300}) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxSize,
        targetHeight: maxSize,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Image compression failed, using original: $e');
    }
    // Fallback: return original bytes if compression fails
    return bytes;
  }

  void _showConfirmDialog(Uint8List imageBytes, String base64Image) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Identity Captured!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor, width: 3),
                boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 16)],
              ),
              child: ClipOval(child: Image.memory(imageBytes, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your photo has been captured.\nReady to start the exam?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isCapturing = false);
            },
            child: const Text('Retake'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Exam'),
            onPressed: () {
              Navigator.pop(ctx);
              // Dispose camera before going to exam so exam can init its own
              _controller?.dispose();
              _controller = null;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ExamScreen(
                    examData: widget.examData,
                    capturedFaceImageBase64: base64Image,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _skipVerification() {
    _controller?.dispose();
    _controller = null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamScreen(examData: widget.examData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text('Align your face within the frame',
                  style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Your photo will be captured and attached to your exam submission.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Camera viewport
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                  boxShadow: [BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 20, spreadRadius: 5)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _buildCameraView(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Capture button
          if (_isInitialized && _errorMessage == null)
            GestureDetector(
              onTap: _isCapturing ? null : _capturePhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing ? AppTheme.textSecondary : AppTheme.primaryColor,
                  boxShadow: [BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16, spreadRadius: 4)],
                ),
                child: _isCapturing
                  ? const Center(child: SizedBox(width: 28, height: 28,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
              ),
            ),

          const SizedBox(height: 16),
          _buildInstructions(),
          const SizedBox(height: 12),

          TextButton.icon(
            icon: const Icon(Icons.skip_next, color: AppTheme.textSecondary, size: 16),
            label: const Text('Skip (Dev mode)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            onPressed: _skipVerification,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_errorMessage != null) {
      return Container(
        color: AppTheme.darkCard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () { setState(() { _errorMessage = null; _isInitialized = false; }); _initCamera(); },
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _skipVerification, child: const Text('Continue Without Camera')),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Starting camera...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ));
    }

    return CameraPreview(_controller!);
  }

  Widget _buildInstructions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tip(Icons.lightbulb_outline, 'Good Lighting'),
        const SizedBox(width: 28),
        _tip(Icons.face_retouching_natural, 'Clear View'),
        const SizedBox(width: 28),
        _tip(Icons.camera_alt, 'Press button below'),
      ],
    );
  }

  Widget _tip(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 22),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
