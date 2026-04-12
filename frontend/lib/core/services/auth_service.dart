import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api/api_endpoints.dart';
import 'package:frontend/core/services/api_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final api = ref.read(apiServiceProvider);
  return AuthService(api);
});

class AuthService {
  final ApiBaseService _api;

  AuthService(this._api);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _api.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> faceLogin(String email, List<double> embedding) async {
    final response = await _api.post(ApiEndpoints.faceLogin, data: {
      'email': email,
      'currentEmbedding': embedding,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required List<double> faceEmbedding,
  }) async {
    final response = await _api.post(ApiEndpoints.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'faceEmbedding': faceEmbedding,
    });
    return response.data;
  }
}
