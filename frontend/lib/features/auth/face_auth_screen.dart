import 'package:flutter/material.dart';
import 'package:face_recognition_kit/face_recognition_kit.dart';
import '../../core/theme.dart';
import '../exam/exam_screen.dart';

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  bool _isProcessing = false;

  void _onFaceRecognized(FaceProfile profile, List<int> image) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    // Simulate API call and success
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ExamScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Align your face within the frame to verify your identity before starting the exam.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _isProcessing 
                  ? const Center(child: CircularProgressIndicator())
                  : FaceScannerView(
                      detector: FaceDetectorInterface(), // Standard logic from SDK
                      recognizer: FaceRecognizerInterface(),
                      onFaceRecognized: (profile, image) => _onFaceRecognized(profile, image),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildInstructions(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _instructionItem(Icons.lightbulb_outline, 'Good Lighting'),
        const SizedBox(width: 24),
        _instructionItem(Icons.face_retouching_natural, 'Clear View'),
        const SizedBox(width: 24),
        _instructionItem(Icons.stay_current_portrait, 'Head On'),
      ],
    );
  }

  Widget _instructionItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 24),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}
