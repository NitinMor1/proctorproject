import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'package:intl/intl.dart';

class AdminViolationsPage extends ConsumerStatefulWidget {
  const AdminViolationsPage({super.key});

  @override
  ConsumerState<AdminViolationsPage> createState() => _AdminViolationsPageState();
}

class _AdminViolationsPageState extends ConsumerState<AdminViolationsPage> {
  List<dynamic> _violations = [];
  bool _isLoading = true;

  // Color + icon per violation type
  static const Map<String, Map<String, dynamic>> _typeConfig = {
    'FACE_NOT_DETECTED': {'label': 'Face Not Detected', 'icon': Icons.face_retouching_off, 'color': Colors.orange},
    'MULTIPLE_FACES': {'label': 'Multiple Faces', 'icon': Icons.group, 'color': Colors.red},
    'LOOKING_AWAY': {'label': 'Looking Away', 'icon': Icons.visibility_off, 'color': Colors.amber},
    'TAB_SWITCHED': {'label': 'Tab Switched', 'icon': Icons.tab, 'color': Colors.purple},
    'FULLSCREEN_EXIT': {'label': 'Fullscreen Exit', 'icon': Icons.fullscreen_exit, 'color': Colors.blue},
    'AUDIO_DETECTED': {'label': 'Audio Detected', 'icon': Icons.hearing, 'color': Colors.teal},
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/admin/violations');
      if (mounted) setState(() { _violations = res.data as List; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Violations (${_violations.length})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _violations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('No violations recorded!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('All exams appear to be clean.', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _violations.length,
                  itemBuilder: (context, i) {
                    final v = _violations[i];
                    final type = v['type'] ?? 'UNKNOWN';
                    final severity = v['severity'] ?? 'low';
                    final cfg = _typeConfig[type] ?? {'label': type, 'icon': Icons.warning, 'color': Colors.grey};
                    final color = cfg['color'] as Color;
                    final icon = cfg['icon'] as IconData;
                    final label = cfg['label'] as String;
                    final studentName = v['student']?['name'] ?? 'Unknown';
                    final studentEmail = v['student']?['email'] ?? '';
                    final ts = v['timestamp'] != null
                        ? DateFormat('MMM d, yyyy • HH:mm').format(DateTime.parse(v['timestamp']).toLocal())
                        : '';

                    return Card(
                      color: AppTheme.darkCard,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(studentName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(studentEmail, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            if (ts.isNotEmpty) Text(ts, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                        trailing: _severityBadge(severity),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _severityBadge(String severity) {
    final colors = {'low': Colors.green, 'medium': Colors.orange, 'high': Colors.red};
    final color = colors[severity] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(severity.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
