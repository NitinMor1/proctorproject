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

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final exams = await api.getExams();
      if (mounted) {
        setState(() {
          _exams = exams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching exams: $e');
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exam Code $code copied to clipboard!')),
    );
  }

  void _editExam(Map<String, dynamic> exam) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateExamScreen(existingExam: exam)),
    );
    _fetchExams(); // Refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exams.isEmpty) {
      return const Center(child: Text('No exams created yet.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _exams.length,
      itemBuilder: (context, index) {
        final exam = _exams[index];
        final code = exam['examCode'] ?? 'N/A';
        final qCount = exam['questions']?.length ?? 0;
        
        return Card(
          color: AppTheme.darkCard,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('${exam['durationMinutes']} mins • $qCount questions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(code, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.textSecondary),
                  tooltip: 'Copy Code',
                  onPressed: () => _copyToClipboard(code),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.textSecondary),
                  tooltip: 'Edit Exam',
                  onPressed: () => _editExam(exam),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
