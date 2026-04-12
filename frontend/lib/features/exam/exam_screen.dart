import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import '../../core/theme.dart';
import '../../core/services/proctor_service.dart';

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
  late Map<int, int> _answers; // {questionIndex: selectedOptionIndex}
  late int _secondsRemaining;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _submitted = false;
  int? _finalScore;
  
  // Live proctoring camera
  CameraController? _camController;
  bool _camReady = false;

  List<dynamic> get _questions => widget.examData?['questions'] ?? [];
  String get _title => widget.examData?['title'] ?? 'Exam';
  String get _examId => widget.examData?['_id'] ?? '';

  @override
  void initState() {
    super.initState();
    _answers = {};
    final durationMinutes = widget.examData?['durationMinutes'] ?? 60;
    _secondsRemaining = durationMinutes * 60;
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration.zero, () {
      ref.read(proctorProvider).startMonitoring();
    });
    _startTimer();
    _initProctoringCamera();
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
      debugPrint('Proctoring camera init error: $e');
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
    _camController?.dispose();
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

  Future<void> _submitExam({bool forceSubmit = false}) async {
    if (_isSubmitting || _submitted) return;
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    try {
      final authState = ref.read(authStateProvider);
      final api = ref.read(apiServiceProvider) as ApiService;

      if (authState.userId == null) {
        debugPrint('ERROR: userId is null. Student is not logged in.');
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      // Build the answers list matching server schema
      final List<Map<String, dynamic>> answersPayload = [];
      if (_questions.isNotEmpty) {
        for (int i = 0; i < _questions.length; i++) {
          if (_answers.containsKey(i)) {
            answersPayload.add({
              'questionId': _questions[i]['_id'],
              'selectedOptionIndex': _answers[i],
            });
          }
        }
      }

      final response = await api.post('/submissions', data: {
        'student': authState.userId,
        'exam': _examId,
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

    if (_submitted) return _buildResultScreen();

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, proctor),
                const SizedBox(height: 32),
                if (_questions.isEmpty)
                  const Expanded(child: Center(child: Text('No questions found.')))
                else
                  Expanded(child: _buildQuestionArea(context)),
                _buildFooter(context),
              ],
            ),
          ),
          Positioned(
            top: 20, right: 20,
            child: _buildCameraPreview(proctor),
          ),
          if (proctor.integrityScore < 80)
            Positioned(
              bottom: 100, left: 0, right: 0,
              child: _buildWarningBanner(proctor),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProctorService proctor) {
    final timeColor = _secondsRemaining < 300 ? Colors.red : AppTheme.secondaryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  Icon(Icons.timer, color: timeColor, size: 16),
                  const SizedBox(width: 4),
                  Text('Time Remaining: ${_formatTime()}',
                    style: TextStyle(color: timeColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getScoreColor(proctor.integrityScore).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getScoreColor(proctor.integrityScore)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: _getScoreColor(proctor.integrityScore), size: 18),
              const SizedBox(width: 8),
              Text('Integrity: ${proctor.integrityScore}%',
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
    final q = _questions[_currentQuestion];
    final options = List<String>.from(q['options'] ?? []);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question ${_currentQuestion + 1} of ${_questions.length}',
            style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(q['questionText'] ?? '', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          ...List.generate(options.length, (i) => _buildOption(context, i, options[i])),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, int index, String text) {
    final labels = ['A', 'B', 'C', 'D'];
    final isSelected = _answers[_currentQuestion] == index;
    return GestureDetector(
      onTap: () => setState(() => _answers[_currentQuestion] = index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(labels[index], style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.primaryColor, fontSize: 12)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isLast = _currentQuestion == _questions.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _currentQuestion > 0 ? () => setState(() => _currentQuestion--) : null,
            child: const Text('Previous'),
          ),
          Text('${_answers.length}/${_questions.length} answered',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          isLast
            ? ElevatedButton(
                onPressed: _isSubmitting ? null : () => _confirmSubmit(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  backgroundColor: Colors.green,
                ),
                child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Exam'),
              )
            : ElevatedButton(
                onPressed: () => setState(() => _currentQuestion++),
                style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
                child: const Text('Next Question'),
              ),
        ],
      ),
    );
  }

  void _confirmSubmit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: Text('You have answered ${_answers.length} out of ${_questions.length} questions. Are you sure you want to submit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final max = _questions.length;
    final percent = max > 0 ? ((_finalScore ?? 0) / max * 100).round() : 0;
    final color = percent >= 70 ? Colors.green : Colors.orange;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(percent >= 70 ? Icons.check_circle : Icons.info, size: 80, color: color),
              const SizedBox(height: 24),
              Text('Exam Submitted!', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 16),
              Text('$percent%', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 8),
              Text('$_finalScore out of $max correct',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview(ProctorService proctor) {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_camReady && _camController != null)
              CameraPreview(_camController!)
            else
              const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 40)),
            Positioned(
              bottom: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (_camReady ? Colors.green : Colors.red).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _camReady ? 'LIVE' : 'NO CAM',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
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
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 12),
            Text('WARNING: Suspicious behavior detected!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
