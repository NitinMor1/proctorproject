import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'create_exam_screen.dart';
import 'admin_exams_tab.dart';
import 'admin_submissions_tab.dart';
import 'admin_students_page.dart';
import 'admin_violations_page.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'Overview'),
    _NavItem(Icons.assignment_rounded, 'Exams'),
    _NavItem(Icons.bar_chart_rounded, 'Results'),
    _NavItem(Icons.people_rounded, 'Students'),
    _NavItem(Icons.warning_amber_rounded, 'Violations'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    final pages = [
      const _OverviewTab(),
      const AdminExamsTab(),
      const AdminSubmissionsTab(),
      const AdminStudentsPage(),
      const AdminViolationsPage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Row(children: [
        // ── Sidebar ─────────────────────────────────────────────
        Container(
          width: isWide ? 220 : 72,
          color: AppTheme.darkCard,
          child: SafeArea(
            child: Column(children: [
              // Logo
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security, color: Colors.white, size: 22),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 12),
                    Text('ProctorAI', style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                  ],
                ]),
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),

              // Nav items
              ...List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final selected = _selectedIndex == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 14 : 0,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                          ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4))
                          : null,
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: isWide ? 40 : 56,
                          child: Icon(item.icon,
                            color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                            size: 22),
                        ),
                        if (isWide)
                          Text(item.label,
                            style: TextStyle(
                              color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            )),
                      ]),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Create Exam button
              Padding(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateExamScreen())),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 14 : 0, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: isWide ? 40 : 56,
                        child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22)),
                      if (isWide)
                        const Text('New Exam',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),

              // Logout
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Consumer(builder: (ctx, ref, _) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (ctx.mounted) {
                      Navigator.of(ctx).popUntil((r) => r.isFirst);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 14 : 0, vertical: 12),
                    child: Row(children: [
                      SizedBox(
                        width: isWide ? 40 : 56,
                        child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22)),
                      if (isWide)
                        const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 14)),
                    ]),
                  ),
                )),
              ),
            ]),
          ),
        ),

        // ── Main Content ─────────────────────────────────────────
        Expanded(
          child: Column(children: [
            // Top bar
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(children: [
                Text(_navItems[_selectedIndex].label,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: const [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 8),
                    Text('Admin', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
            ),

            // Page content
            Expanded(child: pages[_selectedIndex]),
          ]),
        ),
      ]),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
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
  void initState() { super.initState(); _fetchStats(); }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/admin/stats');
      if (mounted) setState(() { _stats = Map<String, dynamic>.from(res.data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_stats == null) return const SizedBox.shrink();

    final students      = _stats!['totalStudents'] ?? 0;
    final exams         = _stats!['totalExams'] ?? 0;
    final violations    = _stats!['totalViolations'] ?? 0;
    final avgIntegrity  = _stats!['avgIntegrity'] ?? 100;
    final recentSubs    = (_stats!['recentSubmissions'] as List?) ?? [];
    final dist          = _stats!['integrityDistribution'] as Map? ?? {};
    final lowRisk       = (dist['lowRisk'] ?? 0) as num;
    final warning       = (dist['warning'] ?? 0) as num;
    final flagged       = (dist['flagged'] ?? 0) as num;
    final total         = lowRisk + warning + flagged;

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Stat cards
          Wrap(spacing: 16, runSpacing: 16, children: [
            _statCard('Total Students', '$students', Icons.people_rounded, Colors.blue),
            _statCard('Total Exams',    '$exams',    Icons.assignment_rounded, Colors.purple),
            _statCard('Violations',     '$violations', Icons.warning_rounded, Colors.red),
            _statCard('Avg. Integrity', '$avgIntegrity%', Icons.verified_rounded, Colors.green),
          ]),
          const SizedBox(height: 32),

          // Bottom split
          LayoutBuilder(builder: (ctx, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: _buildRecentSessions(recentSubs)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildIntegrityChart(lowRisk, warning, flagged, total)),
              ]);
            }
            return Column(children: [
              _buildRecentSessions(recentSubs),
              const SizedBox(height: 20),
              _buildIntegrityChart(lowRisk, warning, flagged, total),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }

  Widget _buildRecentSessions(List recentSubs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Submissions',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (recentSubs.isEmpty)
          const Text('No submissions yet.', style: TextStyle(color: AppTheme.textSecondary))
        else
          ...recentSubs.map((sub) {
            final name    = sub['studentName'] ?? 'Unknown';
            final exam    = sub['examTitle'] ?? 'Exam';
            final score   = sub['score'] ?? 0;
            final max     = sub['maxScore'] ?? 0;
            final status  = sub['status'] ?? 'Clean';
            final pct     = max > 0 ? '${((score / max) * 100).round()}%' : '0%';
            final date    = sub['submittedAt'] != null
              ? DateFormat('MMM d, HH:mm').format(DateTime.parse(sub['submittedAt']).toLocal()) : '';
            final color   = status == 'Clean' ? Colors.green : Colors.orange;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    radius: 18,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(exam, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    if (date.isNotEmpty) Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(pct, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _buildIntegrityChart(num lowRisk, num warning, num flagged, num total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Integrity Distribution', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (total == 0)
          const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text('No data yet', style: TextStyle(color: AppTheme.textSecondary))))
        else ...[
          _bar('Low Risk',  lowRisk,  total, Colors.green),
          const SizedBox(height: 14),
          _bar('Warning',   warning,  total, Colors.orange),
          const SizedBox(height: 14),
          _bar('Flagged',   flagged,  total, Colors.red),
        ],
      ]),
    );
  }

  Widget _bar(String label, num count, num total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text('$count · ${(pct * 100).round()}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0).toDouble(),
          minHeight: 8,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        )),
    ]);
  }
}
