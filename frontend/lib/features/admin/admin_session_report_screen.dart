import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';

/// Full per-student session report screen for admins
class AdminSessionReportScreen extends ConsumerStatefulWidget {
  final String submissionId;
  const AdminSessionReportScreen({super.key, required this.submissionId});

  @override
  ConsumerState<AdminSessionReportScreen> createState() => _AdminSessionReportScreenState();
}

class _AdminSessionReportScreenState extends ConsumerState<AdminSessionReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _fetchReport(); }

  Future<void> _fetchReport() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/submissions/${widget.submissionId}/report');
      if (mounted) setState(() { _report = Map<String, dynamic>.from(res.data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        elevation: 0,
        title: const Text('Exam Report', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
          : _buildReport(),
    );
  }

  Widget _buildReport() {
    final r          = _report!;
    final student    = r['student'] as Map? ?? {};
    final submission = r['submission'] as Map? ?? {};
    final session    = r['session'] as Map?;
    final violations = (r['violations'] as List?) ?? [];
    final answers    = (r['evaluatedAnswers'] as List?) ?? [];
    final exam       = r['exam'] as Map? ?? {};

    final score     = submission['score'] ?? 0;
    final maxScore  = submission['maxScore'] ?? 0;
    final pct       = maxScore > 0 ? ((score / maxScore) * 100).round() : 0;
    final integrity = session?['integrityScore'] ?? 100;
    final status    = session?['status'] ?? 'completed';
    final statusColor = status == 'flagged' ? Colors.red : status == 'completed' ? Colors.green : Colors.orange;
    final scoreColor  = pct >= 70 ? Colors.green : Colors.orange;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Student Header Card ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkCard, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            _facePhoto(submission['studentFaceImage']),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(student['email'] ?? '',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Text(exam['title'] ?? 'Exam',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              if (submission['submittedAt'] != null)
                Text(
                  DateFormat('MMM d, yyyy • HH:mm').format(
                    DateTime.parse(submission['submittedAt']).toLocal()),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(status.toUpperCase(),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Score Metrics ─────────────────────────────────────────
        Row(children: [
          Expanded(child: _metricCard('Exam Score',  '$score / $maxScore', '$pct%', scoreColor, Icons.score_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _metricCard('Integrity',   '$integrity%', session != null ? '${violations.length} violations' : 'N/A', integrity >= 80 ? Colors.green : Colors.red, Icons.verified_user_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _metricCard('Duration',
            session != null
              ? _duration(session!['startTime'], session!['endTime'])
              : '—',
            '${exam['durationMinutes'] ?? '?'} min limit', Colors.blue, Icons.timer_rounded)),
        ]),
        const SizedBox(height: 28),

        // ── Violation Timeline ────────────────────────────────────
        _sectionHeader('Violation Timeline', violations.length.toString(), Colors.red),
        const SizedBox(height: 12),
        if (violations.isEmpty)
          _emptyState('No violations recorded', Icons.check_circle_outline, Colors.green)
        else
          Container(
            decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              ...violations.asMap().entries.map((entry) {
                final i = entry.key;
                final v = entry.value as Map;
                final vType = v['type'] ?? '';
                final color = _violationColor(v['severity'] ?? 'low');
                final ts = v['timestamp'] != null
                  ? DateFormat('HH:mm:ss').format(DateTime.parse(v['timestamp']).toLocal()) : '—';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: i < violations.length - 1
                      ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))
                      : null,
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_violationIcon(vType), color: color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_violationLabel(vType),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (v['comment'] != null)
                        Text(v['comment'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(ts, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text((v['severity'] ?? 'low').toUpperCase(),
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                );
              }),
            ]),
          ),
        const SizedBox(height: 28),

        // ── Answer Evaluation ─────────────────────────────────────
        _sectionHeader('Answer Evaluation', '$pct% correct', scoreColor),
        const SizedBox(height: 12),
        ...answers.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value as Map;
          final isCorrect = a['isCorrect'] == true;
          final options = List<String>.from(a['options'] ?? []);
          final correctIdx = a['correctAnswerIndex'] as int? ?? -1;
          final studentIdx = a['studentAnswerIndex'] as int? ?? -1;
          final color = isCorrect ? Colors.green : Colors.red;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('Q${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(a['questionText'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: color, size: 22),
              ]),
              if (options.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...options.asMap().entries.map((opt) {
                  final oi = opt.key;
                  final optText = opt.value;
                  final isCorrectOpt = oi == correctIdx;
                  final isStudentOpt = oi == studentIdx;
                  Color? bg;
                  Color optColor = AppTheme.textSecondary;
                  if (isCorrectOpt) { bg = Colors.green.withValues(alpha: 0.1); optColor = Colors.green; }
                  if (isStudentOpt && !isCorrect) { bg = Colors.red.withValues(alpha: 0.1); optColor = Colors.red; }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Text('${String.fromCharCode(65 + oi)}. ',
                        style: TextStyle(color: optColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      Expanded(child: Text(optText, style: TextStyle(color: optColor, fontSize: 12))),
                      if (isCorrectOpt) const Icon(Icons.check, color: Colors.green, size: 14),
                      if (isStudentOpt && !isCorrect) const Icon(Icons.close, color: Colors.red, size: 14),
                    ]),
                  );
                }),
              ],
            ]),
          );
        }),
      ]),
    );
  }

  Widget _facePhoto(String? base64) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        final bytes = base64Decode(base64);
        return Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryColor, width: 2.5),
          ),
          child: ClipOval(child: Image.memory(bytes as Uint8List, fit: BoxFit.cover)),
        );
      } catch (_) {}
    }
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
      ),
      child: const Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
    );
  }

  Widget _metricCard(String label, String value, String sub, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _sectionHeader(String title, String badge, Color color) {
    return Row(children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(badge, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _emptyState(String msg, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _duration(dynamic start, dynamic end) {
    if (start == null) return '—';
    final s = DateTime.tryParse(start.toString());
    final e = end != null ? DateTime.tryParse(end.toString()) : null;
    if (s == null) return '—';
    final dur = (e ?? DateTime.now()).difference(s);
    return '${dur.inMinutes}m ${dur.inSeconds % 60}s';
  }

  Color _violationColor(String severity) {
    switch (severity) {
      case 'high':   return Colors.red;
      case 'medium': return Colors.orange;
      default:       return Colors.yellow.shade700;
    }
  }

  IconData _violationIcon(String type) {
    switch (type) {
      case 'FACE_NOT_DETECTED': return Icons.face_retouching_off;
      case 'MULTIPLE_FACES':    return Icons.group;
      case 'LOOKING_AWAY':      return Icons.visibility_off;
      case 'TAB_SWITCHED':      return Icons.tab_unselected;
      case 'FULLSCREEN_EXIT':   return Icons.fullscreen_exit;
      default:                  return Icons.warning;
    }
  }

  String _violationLabel(String type) {
    switch (type) {
      case 'FACE_NOT_DETECTED': return 'Face Not Detected';
      case 'MULTIPLE_FACES':    return 'Multiple Faces Detected';
      case 'LOOKING_AWAY':      return 'Looking Away';
      case 'TAB_SWITCHED':      return 'Tab Switch Detected';
      case 'FULLSCREEN_EXIT':   return 'Fullscreen Exited';
      default:                  return type;
    }
  }
}
