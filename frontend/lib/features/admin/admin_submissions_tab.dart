import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';

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
      debugPrint('Error fetching exams: $e');
    }
  }

  Future<void> _fetchSubmissions() async {
    if (_selectedExamId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final subs = await api.getSubmissionsByExam(_selectedExamId!);
      if (mounted) {
        setState(() {
          _submissions = subs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching submissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exams.isEmpty && !_isLoading) {
      return const Center(child: Text('No exams found.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dropdown to select Exam
        Container(
          padding: const EdgeInsets.all(24),
          color: AppTheme.darkBg,
          child: Row(
            children: [
              const Text('Select Exam: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              if (_exams.isNotEmpty)
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withAlpha(50)),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedExamId,
                        isExpanded: true,
                        dropdownColor: AppTheme.darkCard,
                        items: _exams.map((exam) {
                          return DropdownMenuItem<String>(
                            value: exam['_id'].toString(),
                            child: Text(exam['title'] ?? 'Untitled'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedExamId = val;
                              _fetchSubmissions();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // List of submissions
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
              ? const Center(child: Text('No submissions yet for this exam.', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _submissions.length,
                  itemBuilder: (context, index) {
                    final sub = _submissions[index];
                    final student = sub['student'] ?? {};
                    final name = student['name'] ?? 'Unknown Student';
                    final email = student['email'] ?? 'No email';
                    final score = sub['score'] ?? 0;
                    final max = sub['maxScore'] ?? 0;
                    
                    return Card(
                      color: AppTheme.darkCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _showStudentDetail(context, sub),
                        leading: _buildFaceAvatar(sub),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(email),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Score', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text('$score / $max', style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: score == max ? Colors.green : Colors.orange,
                            )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFaceAvatar(Map<String, dynamic> sub) {
    final imageBase64 = sub['studentFaceImage'] as String?;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(imageBase64);
        return CircleAvatar(
          radius: 24,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    // Fallback: show name initial
    final name = (sub['student']?['name'] ?? 'U') as String;
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppTheme.primaryColor,
      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  void _showStudentDetail(BuildContext context, Map<String, dynamic> sub) {
    final student = sub['student'] ?? {};
    final name = student['name'] ?? 'Unknown';
    final email = student['email'] ?? 'No email';
    final score = sub['score'] ?? 0;
    final max = sub['maxScore'] ?? 0;
    final percent = max > 0 ? ((score / max) * 100).round() : 0;
    final imageBase64 = sub['studentFaceImage'] as String?;
    final scoreColor = percent >= 70 ? Colors.green : Colors.orange;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Face photo
              if (imageBase64 != null && imageBase64.isNotEmpty)
                () {
                  try {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor, width: 3),
                      ),
                      child: ClipOval(
                        child: Image.memory(base64Decode(imageBase64), fit: BoxFit.cover),
                      ),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                }()
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.primaryColor, width: 3),
                  ),
                  child: const Icon(Icons.person, size: 70, color: AppTheme.primaryColor),
                ),

              // Stats
              _detailRow(Icons.email, 'Email', email),
              const SizedBox(height: 12),
              _detailRow(Icons.score, 'Score', '$score / $max'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.percent, color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 12),
                  Text('Percentage: ', style: const TextStyle(color: AppTheme.textSecondary)),
                  Text('$percent%', style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}
