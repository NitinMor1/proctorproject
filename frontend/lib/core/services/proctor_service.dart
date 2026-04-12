import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:face_recognition_kit/face_recognition_kit.dart';

enum ViolationType {
  faceNotDetected,
  multipleFaces,
  lookingAway,
  tabSwitch,
}

class ProctorService extends ChangeNotifier {
  int _integrityScore = 100;
  int get integrityScore => _integrityScore;
  
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  final List<String> _violationLog = [];
  List<String> get violationLog => _violationLog;

  Timer? _monitoringTimer;

  void startMonitoring() {
    _isMonitoring = true;
    _integrityScore = 100;
    _violationLog.clear();
    _startTimer();
    notifyListeners();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    notifyListeners();
  }

  void _startTimer() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isMonitoring) return;
      // Perform automated checks here
    });
  }

  void reportViolation(ViolationType type, {String? details}) {
    int reduction = 0;
    String message = "";

    switch (type) {
      case ViolationType.faceNotDetected:
        reduction = 5;
        message = "Face not detected";
        break;
      case ViolationType.multipleFaces:
        reduction = 15;
        message = "Multiple faces detected";
        break;
      case ViolationType.lookingAway:
        reduction = 3;
        message = "Looking away from screen";
        break;
      case ViolationType.tabSwitch:
        reduction = 10;
        message = "Tab switch detected";
        break;
    }

    _integrityScore = (_integrityScore - reduction).clamp(0, 100);
    _violationLog.add("${DateTime.now().toIso8601String()}: $message ${details ?? ''}");
    notifyListeners();
    
    // In a real app, call Backend API here
    debugPrint("VIOLATION: $message. Current Score: $_integrityScore");
  }

  // Heuristic for "Looking Away"
  void analyzeFaceLandmarks(FaceData face) {
    // Basic heuristic: check if eyes/nose are significantly off-center
    // In a production app, use head pose estimation
    // Assuming face should be roughly in the center of the detection frame
    // This is a placeholder for actual landmark-based orientation logic
  }
}
