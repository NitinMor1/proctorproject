class ApiEndpoints {
  static const String baseUrl = "http://localhost:5000/api";

  // Auth Endpoints
  static const String login = "/auth/login";
  static const String register = "/auth/register";
  static const String faceLogin = "/auth/face-login";

  // Session Endpoints
  static const String startSession = "/sessions/start";
  static String endSession(String id) => "/sessions/$id/end";
  static String updateScore(String id) => "/sessions/$id/score";

  // Violation Endpoints
  static const String logViolation = "/violations";
  static String getViolations(String sessionId) => "/violations/session/$sessionId";
}
