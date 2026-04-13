import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:camera/camera.dart';
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

  List<dynamic> get _questions => widget.examData?['questions'] ?? [];
  String get _title       => widget.examData?['title'] ?? 'Exam';
  String get _examId      => widget.examData?['_id'] ?? '';
  Map<String, dynamic> get _proctoringRules =>
      Map<String, dynamic>.from((widget.examData?['proctoringRules'] as Map?) ?? {});

  @override
  void initState() {
    super.initState();
    _answers = {};
    _secondsRemaining = (widget.examData?['durationMinutes'] ?? 60) * 60;
    WidgetsBinding.instance.addObserver(this);
    _initSession();
    _startTimer();
    _initProctoringCamera();
    // Request fullscreen on web
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
      // Start proctor service with session
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
    // Every 30 seconds, sync integrity score to backend
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

      // Build answers payload
      final List<Map<String, dynamic>> answersPayload = [];
      for (int i = 0; i < _questions.length; i++) {
        if (_answers.containsKey(i)) {
          answersPayload.add({
            'questionId': _questions[i]['_id'],
            'selectedOptionIndex': _answers[i],
          });
        }
      }

      // End session
      if (_sessionId != null) {
        final score = ref.read(proctorProvider).integrityScore;
        await api.patch('/sessions/$_sessionId/score', data: { 'score': score });
        await api.patch('/sessions/$_sessionId/end');
      }

      // Submit
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proctor = ref.watch(proctorProvider);
    if (_submitted) return _buildResultScreen(proctor);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Stack(children: [
          // Background layer with explicitly forced viewport constraints
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
            child: Column(children: [
              _buildHeader(proctor),
              
              if (proctor.integrityScore < 80)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildWarningBanner(proctor),
                ),
                
              const SizedBox(height: 24),
              if (_questions.isEmpty)
                const Expanded(child: Center(child: Text('No questions found.', style: TextStyle(color: Colors.white))))
              else
                Expanded(child: _buildQuestionArea()),
              _buildNavFooter(),
            ]),
          ),

          // Camera preview pip safely anchored top right
          Positioned(top: 16, right: 28, child: _buildCameraPip(proctor)),
        ]),
      ),
    );
  }

  Widget _buildHeader(ProctorService proctor) {
    final timeColor = _secondsRemaining < 300 ? Colors.red : AppTheme.secondaryColor;
    final scoreColor = proctor.integrityScore >= 90 ? Colors.green
      : proctor.integrityScore >= 70 ? Colors.orange : Colors.red;

    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis),
        Row(children: [
          Icon(Icons.timer, color: timeColor, size: 15),
          const SizedBox(width: 4),
          Text(_formatTime(), style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha:0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scoreColor.withValues(alpha:0.5)),
        ),
        child: Row(children: [
          Icon(Icons.verified_user, color: scoreColor, size: 16),
          const SizedBox(width: 6),
          Text('${proctor.integrityScore}%',
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    ]);
  }

  Widget _buildQuestionArea() {
    try {
      final q = _questions[_currentQuestion];
      final options = List<String>.from(q['options'] ?? []);

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Q${_currentQuestion + 1} / ${_questions.length}',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q['questionText']?.toString() ?? '',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.5, color: Colors.white)),
                const SizedBox(height: 24),
                ...List.generate(options.length, (i) {
                  final isSelected = _answers[_currentQuestion] == i;
                  return GestureDetector(
                    onTap: () => setState(() => _answers[_currentQuestion] = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withValues(alpha:0.15) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha:0.1),
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        CircleAvatar(radius: 14,
                          backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha:0.1),
                          child: Text(String.fromCharCode(65 + i), style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.primaryColor, fontSize: 11))),
                        const SizedBox(width: 14),
                        Expanded(child: Text(options[i].toString(), style: const TextStyle(fontSize: 14, color: Colors.white))),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ]),
      );
    } catch (e, stack) {
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text('UI Render Error: $e\n\n$stack', style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Widget _buildNavFooter() {
    final isLast = _currentQuestion == _questions.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        OutlinedButton(
          onPressed: _currentQuestion > 0 ? () => setState(() => _currentQuestion--) : null,
          child: const Text('← Previous'),
        ),
        Text('${_answers.length}/${_questions.length} answered',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        isLast
          ? ElevatedButton(
              onPressed: _isSubmitting ? null : () => _confirmSubmit(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSubmitting
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : ElevatedButton(
              onPressed: () => setState(() => _currentQuestion++),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Next →'),
            ),
      ]),
    );
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submit Exam?'),
        content: Text('You answered ${_answers.length} of ${_questions.length} questions.\nAre you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(pct >= 70 ? Icons.emoji_events : Icons.info, size: 80, color: color),
          const SizedBox(height: 24),
          const Text('Exam Submitted!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('$pct%', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: color)),
          Text('$_finalScore out of $max correct', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
          const SizedBox(height: 20),
          // Integrity summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _resultStat('Integrity Score', '${proctor.integrityScore}%',
                proctor.integrityScore >= 80 ? Colors.green : Colors.red),
              _resultStat('Violations', '${proctor.violationLog.length}', Colors.orange),
            ]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Return to Home'),
          ),
        ]),
      )),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _buildCameraPip(ProctorService proctor) {
    return Container(
      width: 140, height: 175,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.5), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          if (_camReady && _camController != null)
            CameraPreview(_camController!)
          else
            const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 32)),
          Positioned(bottom: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: (_camReady ? Colors.green : Colors.red).withValues(alpha:0.85),
                borderRadius: BorderRadius.circular(4)),
              child: Text(_camReady ? 'LIVE' : 'NO CAM',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
            )),
        ]),
      ),
    );
  }

  Widget _buildWarningBanner(ProctorService proctor) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha:0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 12),
        const Expanded(child: Text('Warning: Suspicious behavior detected!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        Text('${proctor.integrityScore}%', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
