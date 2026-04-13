import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoggedIn;
  final String? token;
  final String? userId;
  final String? email;
  final String role; // 'student' or 'admin'

  AuthState({
    this.isLoggedIn = false,
    this.token,
    this.userId,
    this.email,
    this.role = 'student',
  });

  // Keep backward compat alias
  bool get isAuthenticated => isLoggedIn;

  AuthState copyWith({
    bool? isLoggedIn,
    String? token,
    String? userId,
    String? email,
    String? role,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<void> login(String token, String userId, String email, {String role = 'student'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('user_email', email);
    await prefs.setString('user_role', role);

    state = state.copyWith(
      isLoggedIn: true,
      token: token,
      userId: userId,
      email: email,
      role: role,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    state = AuthState();
  }
}
