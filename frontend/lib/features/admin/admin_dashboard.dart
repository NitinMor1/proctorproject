import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatCard(context, 'Total Students', '1,284', Icons.people, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard(context, 'Exams Taken', '856', Icons.assignment, Colors.purple),
                const SizedBox(width: 16),
                _buildStatCard(context, 'Violations', '42', Icons.warning, Colors.red),
                const SizedBox(width: 16),
                _buildStatCard(context, 'Avg. Integrity', '94%', Icons.verified, Colors.green),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentSessions(context)),
                const SizedBox(width: 24),
                Expanded(child: _buildIntegrityChart(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Exam Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildSessionTile('Nitin Mor', 'Introduction to AI', '98%', 'Clean', Colors.green),
          _buildSessionTile('Aditya Raj', 'Data Structures', '65%', 'Flagged', Colors.red),
          _buildSessionTile('Sneha Singh', 'Database Systems', '89%', 'Warning', Colors.orange),
          _buildSessionTile('Rahul Verma', 'OS & Networking', '95%', 'Clean', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSessionTile(String name, String exam, String score, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(child: Text(name[0])),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(exam, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(score, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text(status, style: TextStyle(color: color, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrityChart(BuildContext context) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Integrity Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Center(
            child: Column(
              children: [
                const Icon(Icons.pie_chart_outline, size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text('78% Low Risk', style: TextStyle(color: AppTheme.textSecondary)),
                Text('15% Warning', style: TextStyle(color: AppTheme.textSecondary)),
                Text('7% Flagged', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
