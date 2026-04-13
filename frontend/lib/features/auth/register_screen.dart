import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/features/student/student_exam_code_screen.dart';
import 'package:frontend/features/auth/face_enrollment_screen.dart';
import 'package:frontend/features/auth/login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading    = false;
  bool _obscure      = true;
  String? _error;
  int _currentStep   = 0; // 0=form, 1=face

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  void _goToFaceEnrollment() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _error = null; _currentStep = 1; });
  }

  Future<void> _completeRegistration(List<double> embedding) async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        faceEmbedding: embedding,
      );
      final token = response['token'];
      final user  = response['user'];
      await ref.read(authStateProvider.notifier).login(token, user['id'], user['email'], role: 'student');
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const StudentExamCodeScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _currentStep = 0; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 1) {
      return FaceEnrollmentScreen(onComplete: _completeRegistration);
    }
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(Icons.person_add_alt_1_rounded, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 20),
                  Text('Create Account', style: GoogleFonts.outfit(
                    fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Step 1 of 2 — Your details',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center),

                  // Step progress bar
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(
                      color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 4, decoration: BoxDecoration(
                      color: AppTheme.darkCard, borderRadius: BorderRadius.circular(2)))),
                  ]),
                  const SizedBox(height: 32),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
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

                  _buildField(_nameCtrl, 'Full Name', Icons.badge_outlined, TextInputType.name),
                  const SizedBox(height: 16),
                  _buildField(_emailCtrl, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      filled: true, fillColor: AppTheme.darkCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onFieldSubmitted: (_) => _goToFaceEnrollment(),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _goToFaceEnrollment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.face_retouching_natural, color: Colors.white),
                      label: const Text('Next: Enroll Face',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Already have an account?', style: TextStyle(color: AppTheme.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Login', style: TextStyle(color: AppTheme.primaryColor)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, TextInputType type) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true, fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
