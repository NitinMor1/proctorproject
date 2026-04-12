import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'package:intl/intl.dart';
import 'create_exam_screen.dart';
import 'admin_exams_tab.dart';
import 'admin_submissions_tab.dart';
import 'admin_students_page.dart';
import 'admin_violations_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Create New Exam',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateExamScreen())),
          ),
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _OverviewTab(),
          AdminExamsTab(),
          AdminSubmissionsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppTheme.darkCard,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Exams'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Results'),
        ],
      ),
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/admin/stats');
      if (mounted) setState(() { _stats = res.data as Map<String, dynamic>; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_stats == null) return const SizedBox.shrink();

    final students = _stats!['totalStudents'] ?? 0;
    final exams = _stats!['totalExams'] ?? 0;
    final violations = _stats!['totalViolations'] ?? 0;
    final avgIntegrity = _stats!['avgIntegrity'] ?? 100;
    final recentSubs = (_stats!['recentSubmissions'] as List?) ?? [];
    final dist = _stats!['integrityDistribution'] as Map<String, dynamic>? ?? {};
    final lowRisk = dist['lowRisk'] ?? 0;
    final warning = dist['warning'] ?? 0;
    final flagged = dist['flagged'] ?? 0;
    final total = (lowRisk + warning + flagged) as num;

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Real-time system statistics', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),

            // ── Stat Cards ──────────────────────────────────────────
            LayoutBuilder(builder: (ctx, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(children: [
                  _statCard('Total Students', '$students', Icons.people, Colors.blue,
                    () => _navigate(const AdminStudentsPage())),
                  const SizedBox(width: 16),
                  _statCard('Exams Taken', '$exams', Icons.assignment, Colors.purple,
                    () {}),
                  const SizedBox(width: 16),
                  _statCard('Violations', '$violations', Icons.warning, Colors.red,
                    () => _navigate(const AdminViolationsPage())),
                  const SizedBox(width: 16),
                  _statCard('Avg. Integrity', '$avgIntegrity%', Icons.verified, Colors.green,
                    () {}),
                ]);
              }
              return Column(children: [
                Row(children: [
                  _statCard('Total Students', '$students', Icons.people, Colors.blue,
                    () => _navigate(const AdminStudentsPage())),
                  const SizedBox(width: 12),
                  _statCard('Exams Taken', '$exams', Icons.assignment, Colors.purple, () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statCard('Violations', '$violations', Icons.warning, Colors.red,
                    () => _navigate(const AdminViolationsPage())),
                  const SizedBox(width: 12),
                  _statCard('Avg. Integrity', '$avgIntegrity%', Icons.verified, Colors.green, () {}),
                ]),
              ]);
            }),

            const SizedBox(height: 32),

            // ── Two columns: Recent Sessions + Integrity Chart ──────
            LayoutBuilder(builder: (ctx, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRecentSessions(recentSubs)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildIntegrityChart(lowRisk, warning, flagged, total)),
                  ],
                );
              }
              return Column(children: [
                _buildRecentSessions(recentSubs),
                const SizedBox(height: 24),
                _buildIntegrityChart(lowRisk, warning, flagged, total),
              ]);
            }),
          ],
        ),
      ),
    );
  }

  void _navigate(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _statCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 16),
              Text(value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSessions(List recentSubs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Exam Sessions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboard())),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentSubs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No submissions yet.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...recentSubs.map((sub) {
              final name = sub['studentName'] ?? 'Unknown';
              final exam = sub['examTitle'] ?? 'Exam';
              final score = sub['score'] ?? 0;
              final max = sub['maxScore'] ?? 0;
              final status = sub['status'] ?? 'Clean';
              final submitted = sub['submittedAt'] != null
                  ? DateFormat('MMM d, HH:mm').format(DateTime.parse(sub['submittedAt']).toLocal())
                  : '';
              final pct = max > 0 ? '${((score / max) * 100).round()}%' : '0%';
              final color = status == 'Clean' ? Colors.green : Colors.orange;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(exam, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          if (submitted.isNotEmpty)
                            Text(submitted, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      )),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(pct, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildIntegrityChart(num lowRisk, num warning, num flagged, num total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Integrity Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No submissions yet', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else ...[
            _distributionBar('Low Risk', lowRisk, total, Colors.green),
            const SizedBox(height: 16),
            _distributionBar('Warning', warning, total, Colors.orange),
            const SizedBox(height: 16),
            _distributionBar('Flagged', flagged, total, Colors.red),
            const SizedBox(height: 24),
            // Legend
            _legendItem(Colors.green, 'Low Risk (≥ 70%)'),
            const SizedBox(height: 6),
            _legendItem(Colors.orange, 'Warning (40–69%)'),
            const SizedBox(height: 6),
            _legendItem(Colors.red, 'Flagged (< 40%)'),
          ],
        ],
      ),
    );
  }

  Widget _distributionBar(String label, num count, num total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    final pctLabel = '${(pct * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            Text('$count  ·  $pctLabel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0).toDouble(),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }
}
