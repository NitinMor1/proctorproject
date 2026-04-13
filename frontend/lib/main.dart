import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/student/student_exam_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(const ProviderScope(child: ProctorApp()));
}

class ProctorApp extends ConsumerWidget {
  const ProctorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ProctorAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppRouter(),
    );
  }
}

/// Decides where to send the user on app launch based on saved token + role
class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final role = prefs.getString('user_role') ?? 'student';

    if (token != null && mounted) {
      // Restore auth state
      final userId = prefs.getString('user_id') ?? '';
      final email = prefs.getString('user_email') ?? '';
      await ref.read(authStateProvider.notifier).login(token, userId, email, role: role);
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = ref.watch(authStateProvider);
    if (!auth.isLoggedIn) return const WelcomeScreen();
    if (auth.role == 'admin') return const AdminDashboard();
    return const StudentExamCodeScreen();
  }
}

// ─── Welcome / Landing Screen ─────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF0D1B2A), Color(0xFF0A0A1A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo & Brand
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                        ),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 32, spreadRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.security, size: 52, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text('ProctorAI', style: GoogleFonts.outfit(
                      fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white,
                      letterSpacing: -1,
                    )),
                    const SizedBox(height: 8),
                    Text('AI-Powered Remote Examination System',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15)),
                    const SizedBox(height: 60),

                    // Student CTA
                    _CTAButton(
                      icon: Icons.school_rounded,
                      label: 'Student Login',
                      subtitle: 'Take your exam securely',
                      gradient: const [Color(0xFF6C63FF), Color(0xFF4FACFE)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    ),
                    const SizedBox(height: 16),

                    // Admin CTA
                    _CTAButton(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Admin Console',
                      subtitle: 'Manage exams & monitor students',
                      gradient: const [Color(0xFF1A1A3E), Color(0xFF2D2D6E)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
                    ),

                    const SizedBox(height: 48),
                    Text('Secured by biometric AI • End-to-end encrypted',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _CTAButton({
    required this.icon, required this.label, required this.subtitle,
    required this.gradient, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
