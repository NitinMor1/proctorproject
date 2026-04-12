import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/theme.dart';
import 'package:intl/intl.dart';

class AdminStudentsPage extends ConsumerStatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  ConsumerState<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends ConsumerState<AdminStudentsPage> {
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final api = ref.read(apiServiceProvider) as ApiService;
      final res = await api.get('/admin/students');
      if (mounted) setState(() { _students = res.data as List; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Students')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text('No students registered yet.', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final s = _students[index];
                    final name = s['name'] ?? 'Unknown';
                    final email = s['email'] ?? '';
                    final count = s['submissionCount'] ?? 0;
                    final reg = s['registeredAt'] != null
                        ? DateFormat('MMM d, yyyy').format(DateTime.parse(s['registeredAt']))
                        : 'Unknown';

                    return Card(
                      color: AppTheme.darkCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Text('Registered: $reg', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            const Text('Exams', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
