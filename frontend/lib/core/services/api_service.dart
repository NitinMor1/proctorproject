import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_endpoints.dart';

final apiServiceProvider = Provider<ApiBaseService>((ref) => ApiService());

abstract class ApiBaseService {
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters});
  Future<Response<dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters});
  Future<Response<dynamic>> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters});
  Future<Response<dynamic>> delete(String path);
  Future<bool> checkSubmission(String studentId, String examId);
}

class ApiService implements ApiBaseService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  SharedPreferences? _prefs;

  ApiService() {
    _initPrefs();
    
    // Add LogInterceptor to print exactly what is being sent and received
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Wait for prefs to initialize if not ready yet
        _prefs ??= await SharedPreferences.getInstance();
        
        final token = _prefs!.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Response<dynamic>> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Response<dynamic>> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.patch(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Response<dynamic>> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? 'Server error occurred: ${e.response?.statusCode}';
    }
    return 'Network connection failed: ${e.message}';
  }

  Future<Map<String, dynamic>> faceLogin(String email, List<double> embedding) async {
    try {
      final response = await post('/auth/face-login', data: {
        'email': email,
        'currentEmbedding': embedding,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<Map<String, dynamic>> startSession(String studentId, String examId) async {
    try {
      final response = await post('/sessions/start', data: {
        'student': studentId,
        'examId': examId,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Failed to start session: $e');
    }
  }

  Future<void> logViolation(String sessionId, String studentId, String type, String severity) async {
    try {
      await post('/violations', data: {
        'session': sessionId,
        'student': studentId,
        'type': type,
        'severity': severity,
      });
    } catch (e) {
      debugPrint('Failed to log violation: $e');
    }
  }

  Future<Map<String, dynamic>> createExam({
    required String title,
    required String description,
    required int durationMinutes,
    required List<Map<String, dynamic>> questions,
    Map<String, dynamic>? proctoringRules,
  }) async {
    try {
      final response = await post('/exams', data: {
        'title': title,
        'description': description,
        'durationMinutes': durationMinutes,
        'questions': questions,
        if (proctoringRules != null) 'proctoringRules': proctoringRules,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw Exception('Failed to create exam: $e');
    }
  }

  Future<List<dynamic>> getExams() async {
    try {
      final response = await get('/exams');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get exams: $e');
    }
  }

  Future<Map<String, dynamic>> updateExam(String id, {
    required String title,
    required String description,
    required int durationMinutes,
    required List<Map<String, dynamic>> questions,
    Map<String, dynamic>? proctoringRules,
  }) async {
    try {
      final response = await _dio.put('/exams/$id', data: {
        'title': title,
        'description': description,
        'durationMinutes': durationMinutes,
        'questions': questions,
        if (proctoringRules != null) 'proctoringRules': proctoringRules,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      if (e is DioException) throw Exception(_handleError(e));
      throw Exception('Failed to update exam: $e');
    }
  }

  Future<List<dynamic>> getSubmissionsByExam(String examId) async {
    try {
      final response = await get('/submissions/exam/$examId');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get submissions: $e');
    }
  }

  @override
  Future<bool> checkSubmission(String studentId, String examId) async {
    try {
      final response = await get('/submissions/check', queryParameters: {
        'student': studentId,
        'exam': examId,
      });
      return response.data['submitted'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
