import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'create_exam_screen.dart';

class AdminExamsTab extends ConsumerStatefulWidget {
  const AdminExamsTab({super.key});

  @override
  ConsumerState<AdminExamsTab> createState() => _AdminExamsTabState();
}

class _AdminExamsTabState extends ConsumerState<AdminExamsTab> {
  List<dynamic> _exams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _fetchExams(); }

  Future<void> _fetchExams() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/exams');
      if (mounted) setState(() { _exams = res.data as List; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _toggleStatus(Map exam) async {
    final newStatus = exam['status'] == 'published' ? 'draft' : 'published';
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      await api.patch('/exams/${exam['_id']}/status', data: { 'status': newStatus });
      _fetchExams();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteExam(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Exam?'),
        content: const Text('This will permanently delete the exam and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      await api.delete('/exams/$id');
      _fetchExams();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));

    if (_exams.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        const Text('No exams yet', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateExamScreen())).then((_) => _fetchExams()),
          icon: const Icon(Icons.add),
          label: const Text('Create First Exam'),
        ),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _fetchExams,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _exams.length,
        itemBuilder: (context, index) {
          final exam = _exams[index] as Map;
          final isPublished = exam['status'] == 'published';
          final code = exam['examCode'] ?? '------';
          final rules = exam['proctoringRules'] as Map? ?? {};

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isPublished ? AppTheme.primaryColor : Colors.grey).withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(exam['title'] ?? 'Untitled',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${exam['durationMinutes'] ?? 0} minutes · ${(exam['questions'] as List?)?.length ?? 0} questions',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ])),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPublished ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isPublished ? Colors.green : Colors.grey).withValues(alpha: 0.4)),
                  ),
                  child: Text(isPublished ? 'Published' : 'Draft',
                    style: TextStyle(
                      color: isPublished ? Colors.green : Colors.grey,
                      fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 16),

              // Exam code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.key_rounded, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text('Code: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Text(code, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 15)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Exam code copied!'), duration: Duration(seconds: 2)));
                    },
                    child: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 18),
                  ),
                ]),
              ),

              // Proctoring rules chips
              if (rules.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  if (rules['faceRequired'] == true)
                    _ruleChip(Icons.face_retouching_natural, 'Face Required', Colors.blue),
                  if (rules['fullscreenRequired'] == true)
                    _ruleChip(Icons.fullscreen, 'Fullscreen', Colors.purple),
                  if (rules['maxTabSwitches'] != null)
                    _ruleChip(Icons.tab_unselected, 'Max ${rules['maxTabSwitches']} tab switches', Colors.orange),
                ]),
              ],

              const SizedBox(height: 16),

              // Action row
              Row(children: [
                // Toggle publish
                OutlinedButton.icon(
                  onPressed: () => _toggleStatus(exam),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isPublished ? Colors.orange : Colors.green,
                    side: BorderSide(color: isPublished ? Colors.orange : Colors.green, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(isPublished ? Icons.unpublished : Icons.publish, size: 16),
                  label: Text(isPublished ? 'Unpublish' : 'Publish', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                // Edit
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CreateExamScreen(existingExam: Map<String, dynamic>.from(exam))))
                    .then((_) => _fetchExams()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit', style: TextStyle(fontSize: 13)),
                ),
                const Spacer(),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteExam(exam['_id']),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _ruleChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
