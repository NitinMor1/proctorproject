import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api/api_endpoints.dart';
import 'package:frontend/core/services/api_service.dart';

final examServiceProvider = Provider<ExamService>((ref) {
  final api = ref.read(apiServiceProvider);
  return ExamService(api);
});

class ExamService {
  final ApiBaseService _api;

  ExamService(this._api);

  Future<Map<String, dynamic>> startSession(String studentId, String examId) async {
    final response = await _api.post(ApiEndpoints.startSession, data: {
      'student': studentId,
      'examId': examId,
    });
    return response.data;
  }

  Future<void> endSession(String sessionId) async {
    await _api.patch(ApiEndpoints.endSession(sessionId));
  }

  Future<void> updateIntegrityScore(String sessionId, int score, String? event) async {
    await _api.patch(ApiEndpoints.updateScore(sessionId), data: {
      'score': score,
      'event': event,
    });
  }

  Future<void> reportViolation({
    required String sessionId,
    required String studentId,
    required String type,
    required String severity,
    String? comment,
  }) async {
    await _api.post(ApiEndpoints.logViolation, data: {
      'session': sessionId,
      'student': studentId,
      'type': type,
      'severity': severity,
      'comment': comment,
    });
  }

  Future<List<dynamic>> getSessionViolations(String sessionId) async {
    final response = await _api.get(ApiEndpoints.getViolations(sessionId));
    return response.data;
  }
}
