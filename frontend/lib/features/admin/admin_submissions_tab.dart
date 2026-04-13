import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'admin_session_report_screen.dart';

class AdminSubmissionsTab extends ConsumerStatefulWidget {
  const AdminSubmissionsTab({super.key});

  @override
  ConsumerState<AdminSubmissionsTab> createState() => _AdminSubmissionsTabState();
}

class _AdminSubmissionsTabState extends ConsumerState<AdminSubmissionsTab> {
  List<dynamic> _exams = [];
  String? _selectedExamId;
  List<dynamic> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetchExams(); }

  Future<void> _fetchExams() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/exams');
      if (mounted) {
        setState(() {
          _exams = res.data as List;
          if (_exams.isNotEmpty) {
            _selectedExamId = _exams[0]['_id'];
            _fetchSubmissions();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubmissions() async {
    if (_selectedExamId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/submissions/exam/$_selectedExamId');
      if (mounted) setState(() { _submissions = res.data as List; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exams.isEmpty && !_isLoading) {
      return const Center(child: Text('No exams found.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return Column(children: [
      // Exam selector header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Row(children: [
          const Text('Exam: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          if (_exams.isNotEmpty)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExamId,
                  isExpanded: true,
                  dropdownColor: AppTheme.darkCard,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                  items: _exams.map((e) => DropdownMenuItem<String>(
                    value: e['_id'].toString(),
                    child: Text(e['title'] ?? 'Untitled'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() { _selectedExamId = val; _fetchSubmissions(); });
                  },
                ),
              ),
            ),
        ]),
      ),

      // Submissions list
      Expanded(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_outlined, size: 56, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('No submissions yet for this exam.',
                  style: TextStyle(color: AppTheme.textSecondary)),
              ]))
            : RefreshIndicator(
              onRefresh: _fetchSubmissions,
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _submissions.length,
                itemBuilder: (_, i) => _buildSubmissionCard(_submissions[i]),
              ),
            ),
      ),
    ]);
  }

  Widget _buildSubmissionCard(Map<dynamic, dynamic> sub) {
    final student    = sub['student'] as Map? ?? {};
    final name       = student['name'] ?? 'Unknown';
    final email      = student['email'] ?? '';
    final score      = sub['score'] ?? 0;
    final max        = sub['maxScore'] ?? 0;
    final pct        = max > 0 ? ((score / max) * 100).round() : 0;
    final pctColor   = pct >= 70 ? Colors.green : Colors.orange;
    final session    = sub['session'] as Map?;
    final integrity  = session?['integrityScore'] ?? 100;
    final iKey       = integrity >= 80 ? Colors.green : integrity >= 60 ? Colors.orange : Colors.red;
    final status     = session?['status'] ?? 'completed';
    final statusColor = status == 'flagged' ? Colors.red : Colors.green;
    final submittedAt = sub['submittedAt'] != null
      ? DateFormat('MMM d, yyyy • HH:mm').format(DateTime.parse(sub['submittedAt']).toLocal()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AdminSessionReportScreen(submissionId: sub['_id']))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Face avatar
            _faceAvatar(sub, name),
            const SizedBox(width: 14),

            // Student info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              if (submittedAt.isNotEmpty)
                Text(submittedAt, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ])),

            // Metrics
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Score
              Text('$score/$max', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 17, color: pctColor)),
              Text('$pct%', style: TextStyle(color: pctColor, fontSize: 12)),
              const SizedBox(height: 6),
              // Integrity
              Row(children: [
                Icon(Icons.verified_user, color: iKey, size: 12),
                const SizedBox(width: 4),
                Text('$integrity%', style: TextStyle(color: iKey, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }

  Widget _faceAvatar(Map sub, String name) {
    final img = sub['studentFaceImage'] as String?;
    if (img != null && img.isNotEmpty) {
      try {
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(base64Decode(img) as Uint8List));
      } catch (_) {}
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppTheme.primaryColor,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
