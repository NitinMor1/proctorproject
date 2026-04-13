import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:frontend/features/admin/admin_dashboard.dart';
import 'package:frontend/features/auth/admin_register_screen.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your credentials');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.login(email, password);
      final user = response['user'];
      if (user['role'] != 'admin') {
        setState(() { _error = 'Access denied. Admin credentials required.'; _isLoading = false; });
        return;
      }
      await ref.read(authStateProvider.notifier).login(
        response['token'], user['id'], user['email'], role: 'admin',
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
          (r) => false,
        );
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor.withValues(alpha:0.2), Colors.transparent],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                        size: 64, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text('Admin Console', style: GoogleFonts.outfit(
                      fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Restricted access — administrators only',
                      style: TextStyle(color: Colors.white.withValues(alpha:0.45), fontSize: 13)),
                    const SizedBox(height: 40),

                    // Error banner
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha:0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ]),
                      ),

                    // Email
                    _buildField(controller: _emailCtrl, label: 'Admin Email',
                      icon: Icons.email_outlined, type: TextInputType.emailAddress),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        filled: true, fillColor: AppTheme.darkCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                          ? const SizedBox(height: 22, width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In as Admin',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an admin account? ",
                            style: TextStyle(color: AppTheme.textSecondary)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                          ),
                          child: const Text('Sign up',
                              style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('← Back to Home', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label,
      required IconData icon, TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
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
