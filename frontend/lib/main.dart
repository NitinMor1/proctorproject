import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/face_auth_screen.dart';
import 'features/admin/admin_dashboard.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ProctorApp(),
    ),
  );
}

class ProctorApp extends StatelessWidget {
  const ProctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProctorAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(), // To be implemented
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text('ProctorAI', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            Text('AI-Based Remote Proctoring System', 
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                   ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaceAuthScreen()),
                    ),
                    child: const Text('Start Student Exam'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminDashboard()),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    child: const Text('Go to Admin Dashboard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
