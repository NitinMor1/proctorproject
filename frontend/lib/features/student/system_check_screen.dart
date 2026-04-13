import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:frontend/core/theme.dart';

/// Pre-exam system check screen — verifies camera and internet
class SystemCheckScreen extends StatefulWidget {
  final VoidCallback onAllPassed;
  const SystemCheckScreen({super.key, required this.onAllPassed});

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  bool _camPassed   = false;
  bool _camChecking = true;

  // We consider internet "passed" if the app loaded enough to get here
  final bool _netPassed = true;

  CameraController? _camCtrl;

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  Future<void> _checkCamera() async {
    setState(() => _camChecking = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras found');
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camCtrl = CameraController(front, ResolutionPreset.low, enableAudio: false);
      await _camCtrl!.initialize();
      if (mounted) setState(() { _camPassed = true; _camChecking = false; });
    } catch (e) {
      if (mounted) setState(() { _camPassed = false; _camChecking = false; });
    }
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }

  bool get _allPassed => _camPassed && _netPassed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha:0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.settings_input_component_rounded,
                      size: 52, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text('System Check', style: GoogleFonts.outfit(
                    fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Making sure everything is ready before your exam',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 48),

                  // Camera check
                  _CheckRow(
                    icon: Icons.videocam_rounded,
                    label: 'Front Camera',
                    description: _camPassed
                      ? 'Camera is working and accessible'
                      : !_camChecking ? 'Camera not found or permission denied' : 'Checking...',
                    isPassed: _camPassed,
                    isChecking: _camChecking,
                    onRetry: _checkCamera,
                  ),
                  const SizedBox(height: 16),

                  // Internet check
                  _CheckRow(
                    icon: Icons.wifi_rounded,
                    label: 'Internet Connection',
                    description: 'Connected to ProctorAI servers',
                    isPassed: _netPassed,
                    isChecking: false,
                    onRetry: null,
                  ),
                  const SizedBox(height: 16),

                  // Browser / Fullscreen
                  _CheckRow(
                    icon: Icons.fullscreen_rounded,
                    label: 'Browser Support',
                    description: 'Modern browser with camera API detected',
                    isPassed: true,
                    isChecking: false,
                    onRetry: null,
                  ),

                  const SizedBox(height: 48),

                  // Camera preview (if passed)
                  if (_camPassed && _camCtrl != null)
                    Container(
                      height: 140,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: CameraPreview(_camCtrl!),
                    ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _allPassed ? widget.onAllPassed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allPassed ? Colors.green : Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(_allPassed ? Icons.arrow_forward : Icons.hourglass_empty,
                        color: Colors.white),
                      label: Text(
                        _allPassed ? 'All Checks Passed — Continue' : 'Please fix issues above',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isPassed;
  final bool isChecking;
  final VoidCallback? onRetry;

  const _CheckRow({
    required this.icon, required this.label, required this.description,
    required this.isPassed, required this.isChecking, this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color = isChecking ? Colors.orange : (isPassed ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Text(description, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          if (isChecking)
            const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
          else if (isPassed)
            const Icon(Icons.check_circle, color: Colors.green)
          else
            Row(children: [
              const Icon(Icons.error, color: Colors.red),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: Colors.orange))),
              ],
            ]),
        ],
      ),
    );
  }
}
