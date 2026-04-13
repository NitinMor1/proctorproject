import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/student/system_check_screen.dart';
import 'package:frontend/features/exam/exam_screen.dart';

class StudentExamCodeScreen extends ConsumerStatefulWidget {
  const StudentExamCodeScreen({super.key});

  @override
  ConsumerState<StudentExamCodeScreen> createState() => _StudentExamCodeScreenState();
}

class _StudentExamCodeScreenState extends ConsumerState<StudentExamCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  int _step = 0; // 0=code entry, 1=system check, 2=go to exam
  Map<String, dynamic>? _examData;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _lookupExam() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) { setState(() => _error = 'Please enter an exam code'); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/exams/code/$code');
      setState(() { _examData = Map<String, dynamic>.from(res.data); _step = 1; });
    } catch (e) {
      setState(() => _error = 'Exam not found. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSystemCheckPassed() {
    setState(() => _step = 2);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExamScreen(examData: _examData),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    if (_step == 1) {
      return SystemCheckScreen(onAllPassed: _onSystemCheckPassed);
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ProctorAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              // Greeting
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor.withValues(alpha:0.15), Colors.transparent],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, size: 60, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 20),
              Text('Hello, ${auth.email?.split('@').first ?? 'Student'}!',
                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Enter the exam code provided by your examiner',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 48),

              // Code input card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha:0.25)),
                ),
                child: Column(children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha:0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ]),
                    ),

                  TextFormField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 6),
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha:0.4),
                        fontSize: 28, letterSpacing: 6),
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.darkBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha:0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha:0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    onFieldSubmitted: (_) => _lookupExam(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _lookupExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                        ? const SizedBox(height: 22, width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Enter Exam', style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha:0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha:0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'Before starting, the system will check your camera and internet connection.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
