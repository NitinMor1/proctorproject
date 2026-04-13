import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/services/proctor_service.dart';
import '../../core/theme.dart';

final proctorProvider = ChangeNotifierProvider((ref) => ProctorService());

class ExamScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? examData;
  final String? capturedFaceImageBase64;

  const ExamScreen({super.key, this.examData, this.capturedFaceImageBase64});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> with WidgetsBindingObserver {
  int _currentQuestion = 0;
  late Map<int, int> _answers;
  late int _secondsRemaining;
  Timer? _timer;
  Timer? _proctoringTimer;
  bool _isSubmitting = false;
  bool _submitted = false;
  int? _finalScore;
  String? _sessionId;

  CameraController? _camController;
  bool _camReady = false;

  // Data Getters with safe fallback
  List<dynamic> get _questions => widget.examData?['questions'] ?? [];
  String get _title      => widget.examData?['title'] ?? 'Examination';
  String get _examId     => widget.examData?['_id'] ?? '';
  
  @override
  void initState() {
    super.initState();
    _answers = {};
    _secondsRemaining = (widget.examData?['durationMinutes'] ?? 60) * 60;
    WidgetsBinding.instance.addObserver(this);
    
    // Debug print to console to help identify data issues
    debugPrint('ExamScreen Initialized with ${_questions.length} questions');
    
    _initSession();
    _startTimer();
    _initProctoringCamera();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initSession() async {
    try {
      final auth = ref.read(authStateProvider);
      final api  = ref.read(apiServiceProvider) as ApiService;
      if (auth.userId == null || _examId.isEmpty) return;
      
      final res = await api.post('/sessions/start', data: {
        'student': auth.userId,
        'examId': _examId,
      });
      
      final sid = res.data['_id'];
      if (mounted) setState(() => _sessionId = sid);
      
      ref.read(proctorProvider).startMonitoring(
        sessionId: sid,
        api: api,
        studentId: auth.userId!,
      );
      _startProctoringSync();
    } catch (e) {
      debugPrint('Session init error: $e');
    }
  }

  void _startProctoringSync() {
    _proctoringTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_sessionId == null) return;
      try {
        final api   = ref.read(apiServiceProvider) as ApiService;
        final score = ref.read(proctorProvider).integrityScore;
        await api.patch('/sessions/$_sessionId/score', data: { 'score': score });
      } catch (_) {}
    });
  }

  Future<void> _initProctoringCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camController = CameraController(cam, ResolutionPreset.low, enableAudio: false);
      await _camController!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining <= 0) {
        t.cancel();
        _submitExam(forceSubmit: true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String _formatTime() {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _proctoringTimer?.cancel();
    _camController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(proctorProvider).stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      ref.read(proctorProvider).reportViolation(ViolationType.tabSwitch,
        sessionId: _sessionId,
        api: ref.read(apiServiceProvider) as ApiService,
        studentId: ref.read(authStateProvider).userId ?? '',
        details: 'User left the app/tab',
      );
    }
  }

  Future<void> _submitExam({bool forceSubmit = false}) async {
    if (_isSubmitting || _submitted) return;
    _timer?.cancel();
    _proctoringTimer?.cancel();
    setState(() => _isSubmitting = true);

    try {
      final auth = ref.read(authStateProvider);
      final api  = ref.read(apiServiceProvider) as ApiService;
      if (auth.userId == null) return;

      final List<Map<String, dynamic>> answersPayload = [];
      for (int i = 0; i < _questions.length; i++) {
        if (_answers.containsKey(i)) {
          answersPayload.add({
            'questionId': _questions[i]['_id'],
            'selectedOptionIndex': _answers[i],
          });
        }
      }

      if (_sessionId != null) {
        final score = ref.read(proctorProvider).integrityScore;
        await api.patch('/sessions/$_sessionId/score', data: { 'score': score });
        await api.patch('/sessions/$_sessionId/end');
      }

      final response = await api.post('/submissions', data: {
        'student': auth.userId,
        'exam': _examId,
        'session': _sessionId,
        'answers': answersPayload,
        'studentFaceImage': widget.capturedFaceImageBase64,
      });

      if (mounted) {
        setState(() {
          _submitted = true;
          _finalScore = response.data['score'];
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('Submission error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Submission Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
              if (e.toString().contains('already submitted'))
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('Go Home'),
                ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proctor = ref.watch(proctorProvider);
    if (_submitted) return _buildResultScreen(proctor);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Layer
            Column(
              children: [
                _buildModernHeader(proctor),
                _buildProgressBar(),
                Expanded(
                  child: _questions.isEmpty 
                    ? _buildEmptyState() 
                    : _buildQuestionView(),
                ),
                _buildModernFooter(),
              ],
            ),
            
            // Camera Overlay (Floating)
            Positioned(
              top: 70, 
              right: 20, 
              child: _buildCameraOverlay(proctor)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(ProctorService proctor) {
    final timerColor = _secondsRemaining < 300 ? Colors.red : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, 
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: timerColor, size: 16),
                    const SizedBox(width: 8),
                    Text(_formatTime(), 
                      style: GoogleFonts.outfit(color: timerColor, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          _buildIntegrityBadge(proctor.integrityScore),
        ],
      ),
    );
  }

  Widget _buildIntegrityBadge(int score) {
    final color = score >= 90 ? Colors.green : score >= 70 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: color, size: 18),
          const SizedBox(width: 8),
          Text('$score%', style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = _questions.isEmpty ? 0 : (_answers.length / _questions.length);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_answers.length} of ${_questions.length} answered', 
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    try {
      final q = _questions[_currentQuestion] as Map<String, dynamic>;
      final questionText = q['questionText'] ?? q['text'] ?? 'No Question Content Available';
      final options = List<dynamic>.from(q['options'] ?? q['choices'] ?? []);

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Question Header (Q#)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Text('QUESTION ${_currentQuestion + 1}', 
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor, 
                    fontWeight: FontWeight.w800, 
                    letterSpacing: 2, 
                    fontSize: 13
                  )),
              ),
              
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(questionText, 
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.6, color: Colors.white)),
                      const SizedBox(height: 32),
                      ...List.generate(options.length, (index) => _buildOption(index, options[index])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return _buildErrorState(e.toString());
    }
  }

  Widget _buildOption(int index, dynamic text) {
    bool isSelected = _answers[_currentQuestion] == index;
    return GestureDetector(
      onTap: () => setState(() => _answers[_currentQuestion] = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
              ),
              child: Center(
                child: Text(String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14
                  )),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(text.toString(), 
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
                )),
            ),
            if (isSelected) 
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFooter() {
    bool isLast = _currentQuestion == _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          // Previous Button
          if (_currentQuestion > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentQuestion--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Previous', style: TextStyle(color: Colors.white)),
              ),
            ),
          
          if (_currentQuestion > 0) const SizedBox(width: 16),

          // Next / Submit Button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLast 
                ? (_isSubmitting ? null : _confirmSubmit)
                : () => setState(() => _currentQuestion++),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? Colors.green : AppTheme.primaryColor,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Text(isLast ? 'Complete Exam' : 'Next Question', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOverlay(ProctorService proctor) {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_camReady && _camController != null)
              CameraPreview(_camController!)
            else
              const Center(child: Icon(Icons.videocam_off, color: Colors.white24, size: 24)),
            
            // Status Indicator
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _camReady ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (_camReady ? Colors.green : Colors.red).withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_late_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          const Text('No questions available in this exam.', 
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text('Data Rendering Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('End Exam?'),
        content: Text('You have answered ${_answers.length} of ${_questions.length} questions.\nDo you want to submit your final answers?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Review Answers')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _submitExam(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen(ProctorService proctor) {
    final max = _questions.length;
    final pct = max > 0 ? ((_finalScore ?? 0) / max * 100).round() : 0;
    final color = pct >= 70 ? Colors.green : Colors.orange;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSuccessIcon(pct),
              const SizedBox(height: 40),
              Text('Results Analyzed', style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('Exam Submitted Successfully', 
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 48),
              
              // Score Display
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    children: [
                      Text('$pct%', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: color)),
                      Text('$_finalScore / $max Points', style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              // Integrity Summary
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _resultStat('Integrity', '${proctor.integrityScore}%', proctor.integrityScore >= 80 ? Colors.green : Colors.red),
                      VerticalDivider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
                      _resultStat('Violations', '${proctor.violationLog.length}', Colors.orange),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(0, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Return to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(int pct) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: (pct >= 70 ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(pct >= 70 ? Icons.emoji_events_rounded : Icons.check_circle_rounded, 
        size: 60, color: pct >= 70 ? Colors.green : Colors.orange),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 0.5)),
      ],
    );
  }
}
