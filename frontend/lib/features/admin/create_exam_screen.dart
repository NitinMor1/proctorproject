import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';

class CreateExamScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingExam;
  
  const CreateExamScreen({super.key, this.existingExam});

  @override
  ConsumerState<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends ConsumerState<CreateExamScreen> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<Map<String, dynamic>> _questions = [];

  // Proctoring rules
  int _maxTabSwitches = 3;
  bool _faceRequired = true;
  bool _fullscreenRequired = true;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingExam != null) {
      _isEditing = true;
      _titleController.text = widget.existingExam!['title'] ?? '';
      _descriptionController.text = widget.existingExam!['description'] ?? '';
      _durationController.text = widget.existingExam!['durationMinutes']?.toString() ?? '';
      final rules = widget.existingExam!['proctoringRules'] as Map? ?? {};
      _maxTabSwitches = (rules['maxTabSwitches'] as num?)?.toInt() ?? 3;
      _faceRequired = rules['faceRequired'] ?? true;
      _fullscreenRequired = rules['fullscreenRequired'] ?? true;
      if (widget.existingExam!['questions'] != null) {
        for (var q in widget.existingExam!['questions']) {
          _questions.add({
            'questionText': q['questionText'],
            'options': List<String>.from(q['options']),
            'correctAnswerIndex': q['correctAnswerIndex'],
          });
        }
      }
    } else {
      _addQuestion();
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionText': '',
        'options': ['', '', '', ''],
        'correctAnswerIndex': 0,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _submitExam() async {
    final title = _titleController.text.trim();
    final durationStr = _durationController.text.trim();

    if (title.isEmpty || durationStr.isEmpty || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title, duration, and add at least one question.')));
      return;
    }

    final proctoringRules = {
      'maxTabSwitches': _maxTabSwitches,
      'faceRequired': _faceRequired,
      'fullscreenRequired': _fullscreenRequired,
    };

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      if (_isEditing) {
        await api.updateExam(
          widget.existingExam!['_id'],
          title: title,
          description: _descriptionController.text.trim(),
          durationMinutes: int.tryParse(durationStr) ?? 60,
          questions: _questions,
          proctoringRules: proctoringRules,
        );
      } else {
        await api.createExam(
          title: title,
          description: _descriptionController.text.trim(),
          durationMinutes: int.tryParse(durationStr) ?? 60,
          questions: _questions,
          proctoringRules: proctoringRules,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Exam Updated!' : 'Exam Created & Published!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Exam' : 'Create New Exam'),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: CircularProgressIndicator()))
          else
            TextButton(
              onPressed: _submitExam,
              child: Text(_isEditing ? 'Save Changes' : 'Save & Publish', style: const TextStyle(color: AppTheme.primaryColor)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exam Details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Exam Title',
                filled: true,
                fillColor: AppTheme.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                filled: true,
                fillColor: AppTheme.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Duration (Minutes)',
                filled: true,
                fillColor: AppTheme.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),

            // ── Proctoring Rules ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.security, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text('Proctoring Rules',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 20),
                // Max tab switches
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Max Tab Switches: $_maxTabSwitches',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                  Text(_maxTabSwitches == 0 ? 'Zero tolerance' : '$_maxTabSwitches allowed',
                    style: TextStyle(
                      color: _maxTabSwitches == 0 ? Colors.red : Colors.orange,
                      fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
                Slider(
                  value: _maxTabSwitches.toDouble(),
                  min: 0, max: 10, divisions: 10,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) => setState(() => _maxTabSwitches = v.toInt()),
                ),
                const SizedBox(height: 8),
                // Face required
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Require Face Visibility',
                    style: TextStyle(color: AppTheme.textSecondary)),
                  Switch(
                    value: _faceRequired,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _faceRequired = v),
                  ),
                ]),
                const SizedBox(height: 4),
                // Fullscreen required
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Require Fullscreen Mode',
                    style: TextStyle(color: AppTheme.textSecondary)),
                  Switch(
                    value: _fullscreenRequired,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _fullscreenRequired = v),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Questions', style: Theme.of(context).textTheme.headlineSmall),
                ElevatedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 40),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_questions.length, (index) => _buildQuestionCard(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int qIndex) {
    var q = _questions[qIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.textSecondary.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Question ${qIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeQuestion(qIndex),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: q['questionText']),
              onChanged: (val) => q['questionText'] = val,
              decoration: const InputDecoration(labelText: 'Question Text'),
            ),
            const SizedBox(height: 16),
            ...List.generate(4, (optIndex) {
              return Row(
                children: [
                  Radio<int>(
                    value: optIndex,
                    groupValue: q['correctAnswerIndex'],
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() {
                        q['correctAnswerIndex'] = val;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: q['options'][optIndex]),
                      onChanged: (val) => q['options'][optIndex] = val,
                      decoration: InputDecoration(labelText: 'Option ${optIndex + 1}'),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
