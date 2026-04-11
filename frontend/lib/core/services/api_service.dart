import 'package:dio/dio.dart';
import '../models/user.dart'; // To be created

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:5000/api', // Adjust for production
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  Future<Map<String, dynamic>> faceLogin(String email, List<double> embedding) async {
    try {
      final response = await _dio.post('/auth/face-login', data: {
        'email': email,
        'currentEmbedding': embedding,
      });
      return response.data;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<Map<String, dynamic>> startSession(String studentId, String examId) async {
    try {
      final response = await _dio.post('/sessions/start', data: {
        'student': studentId,
        'examId': examId,
      });
      return response.data;
    } catch (e) {
      throw Exception('Failed to start session: $e');
    }
  }

  Future<void> logViolation(String sessionId, String studentId, String type, String severity) async {
    try {
      await _dio.post('/violations', data: {
        'session': sessionId,
        'student': studentId,
        'type': type,
        'severity': severity,
      });
    } catch (e) {
      print('Failed to log violation: $e');
    }
  }
}
