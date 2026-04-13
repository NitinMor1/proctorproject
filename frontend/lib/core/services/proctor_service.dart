import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/services/api_service.dart';

enum ViolationType {
  faceNotDetected,
  multipleFaces,
  lookingAway,
  tabSwitch,
  fullscreenExit,
}

extension ViolationTypeExt on ViolationType {
  String get apiKey {
    switch (this) {
      case ViolationType.faceNotDetected: return 'FACE_NOT_DETECTED';
      case ViolationType.multipleFaces:   return 'MULTIPLE_FACES';
      case ViolationType.lookingAway:     return 'LOOKING_AWAY';
      case ViolationType.tabSwitch:       return 'TAB_SWITCHED';
      case ViolationType.fullscreenExit:  return 'FULLSCREEN_EXIT';
    }
  }

  String get label {
    switch (this) {
      case ViolationType.faceNotDetected: return 'Face not detected';
      case ViolationType.multipleFaces:   return 'Multiple faces detected';
      case ViolationType.lookingAway:     return 'Looking away from screen';
      case ViolationType.tabSwitch:       return 'Tab / app switch';
      case ViolationType.fullscreenExit:  return 'Fullscreen exited';
    }
  }

  int get scorePenalty {
    switch (this) {
      case ViolationType.faceNotDetected: return 5;
      case ViolationType.multipleFaces:   return 15;
      case ViolationType.lookingAway:     return 3;
      case ViolationType.tabSwitch:       return 10;
      case ViolationType.fullscreenExit:  return 5;
    }
  }

  String get severity {
    switch (this) {
      case ViolationType.multipleFaces:  return 'high';
      case ViolationType.tabSwitch:      return 'medium';
      default:                           return 'low';
    }
  }
}

class ViolationEntry {
  final ViolationType type;
  final DateTime timestamp;
  final String? details;
  ViolationEntry({required this.type, required this.timestamp, this.details});
}

class ProctorService extends ChangeNotifier {
  int _integrityScore = 100;
  int get integrityScore => _integrityScore;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  final List<ViolationEntry> _violations = [];
  List<ViolationEntry> get violations => List.unmodifiable(_violations);

  // Keep legacy getter for compat
  List<String> get violationLog => _violations
      .map((v) => '${v.timestamp.toIso8601String()}: ${v.type.label}')
      .toList();

  Timer? _monitoringTimer;
  String? _sessionId;
  ApiBaseService? _api;
  String? _studentId;

  void startMonitoring({
    required String sessionId,
    required ApiBaseService api,
    required String studentId,
  }) {
    _sessionId     = sessionId;
    _api           = api;
    _studentId     = studentId;
    _isMonitoring  = true;
    _integrityScore = 100;
    _violations.clear();
    notifyListeners();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    notifyListeners();
  }

  /// Report a violation, apply local score penalty, and POST to backend.
  void reportViolation(
    ViolationType type, {
    String? sessionId,
    ApiBaseService? api,
    String? studentId,
    String? details,
  }) {
    final sid  = sessionId ?? _sessionId;
    final sApi = api ?? _api;
    final sId  = studentId ?? _studentId;

    // Local penalty
    _integrityScore = (_integrityScore - type.scorePenalty).clamp(0, 100);
    _violations.add(ViolationEntry(type: type, timestamp: DateTime.now(), details: details));
    notifyListeners();

    debugPrint('VIOLATION [${type.apiKey}]: ${type.label}. Score: $_integrityScore');

    // Send to backend (fire and forget)
    if (sid != null && sApi != null && sId != null) {
      _postViolation(sApi, sid, sId, type, details);
    }
  }

  Future<void> _postViolation(
    ApiBaseService api,
    String sessionId,
    String studentId,
    ViolationType type,
    String? details,
  ) async {
    try {
      await api.post('/violations', data: {
        'session': sessionId,
        'student': studentId,
        'type': type.apiKey,
        'severity': type.severity,
        'comment': details ?? type.label,
      });
    } catch (e) {
      debugPrint('Failed to post violation: $e');
    }
  }
}
