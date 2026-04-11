import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:face_recognition_kit/face_recognition_kit.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme.dart';
import '../../core/services/proctor_service.dart';

final proctorProvider = ChangeNotifierProvider((ref) => ProctorService());

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration.zero, () {
      ref.read(proctorProvider).startMonitoring();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ref.read(proctorProvider).reportViolation(
        ViolationType.tabSwitch,
        details: "User attempted to switch tab/app"
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proctor = ref.watch(proctorProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Main Exam content
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, proctor),
                const SizedBox(height: 32),
                Expanded(child: _buildQuestionArea(context)),
                _buildFooter(context),
              ],
            ),
          ),

          // Proctoring Overlay (Floating Camera)
          Positioned(
            top: 20,
            right: 20,
            child: _buildCameraPreview(proctor),
          ),

          // Real-time Warning Overlay
          if (proctor.integrityScore < 80)
             Positioned(
               bottom: 100,
               left: 0,
               right: 0,
               child: _buildWarningBanner(proctor),
             ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProctorService proctor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Introduction to AI - Final Exam', 
              style: Theme.of(context).textTheme.headlineSmall),
            Text('Time Remaining: 45:02', 
              style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getScoreColor(proctor.integrityScore).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getScoreColor(proctor.integrityScore)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: _getScoreColor(proctor.integrityScore), size: 18),
              const SizedBox(width: 8),
              Text('Integrity Score: ${proctor.integrityScore}%', 
                style: TextStyle(color: _getScoreColor(proctor.integrityScore), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildQuestionArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question 4 of 20', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text('Explain the difference between supervised and unsupervised learning.',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          _buildOption(context, 'A', 'Supervised learning uses labeled data.'),
          _buildOption(context, 'B', 'Unsupervised learning uses labeled data.'),
          _buildOption(context, 'C', 'Both use unlabeled data.'),
          _buildOption(context, 'D', 'Neither uses data.'),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(label, style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
            ),
            const SizedBox(width: 16),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(onPressed: () {}, child: const Text('Previous')),
        ElevatedButton(
          onPressed: () {}, 
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
          child: const Text('Next Question')
        ),
      ],
    );
  }

  Widget _buildCameraPreview(ProctorService proctor) {
    return Container(
      width: 160,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
             // Real implementation would use FaceScannerView here
             const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 40)),
             Positioned(
               bottom: 8,
               left: 8,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: Colors.green.withOpacity(0.8),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(ProctorService proctor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Text('WARNING: Suspicious behavior detected!', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
