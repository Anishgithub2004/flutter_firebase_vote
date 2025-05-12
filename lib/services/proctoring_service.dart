import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'mongodb_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/candidate.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ProctoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime? _sessionStartTime;
  static const int MAX_SESSION_DURATION_MINUTES = 2; // 2 minutes time limit
  bool _isSessionActive = false;
  String? _currentSessionId;
  CameraController? _frontController;
  CameraController? _rearController;
  Timer? _monitoringTimer;
  Timer? _audioMonitoringTimer;
  Timer? _biometricCheckTimer;
  bool _isMonitoring = false;
  int _attemptsLeft = 3;
  bool _isAudioEnabled = false;
  int _consecutiveAudioViolations = 0;
  static const int MAX_AUDIO_VIOLATIONS = 3;
  final String _baseUrl = 'http://192.168.0.111:5000';

  static final ProctoringService _instance = ProctoringService._internal();
  factory ProctoringService() => _instance;
  ProctoringService._internal();

  // Start proctoring session
  Future<String> startProctoringSession(
      String userId, String electionId) async {
    if (_isSessionActive) {
      throw Exception('Session already in progress');
    }

    try {
      print('Starting proctoring session...');
      _sessionStartTime = DateTime.now();
      _isSessionActive = true;
      _currentSessionId = null;

      // Create session document in Firestore
      final sessionRef = _firestore.collection('proctoring_sessions').doc();
      final sessionId = sessionRef.id;
      _currentSessionId = sessionId;

      // Create session document
      await sessionRef.set({
        'userId': userId,
        'electionId': electionId,
        'sessionId': sessionId,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'deviceInfo': {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        }
      });

      // Initialize cameras and start monitoring
      await _initializeCameras();
      _startMonitoring();
      _startAudioMonitoring();
      _startBiometricChecks();

      // Start session timer
      _startSessionTimer(sessionId);

      print('Started session: $sessionId');
      return sessionId;
    } catch (e) {
      _isSessionActive = false;
      _currentSessionId = null;
      print('Error starting session: $e');
      throw Exception('Failed to start session: ${e.toString()}');
    }
  }

  Future<void> _initializeCameras() async {
    try {
      // Initialize both cameras
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _frontController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _rearController = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _frontController!.initialize();
      await _rearController!.initialize();

      // Start preview
      await _frontController!.startImageStream((CameraImage image) {
        // Handle image stream if needed
      });
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
      throw Exception('Failed to initialize cameras');
    }
  }

  void _startMonitoring() {
    _monitoringTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }

      try {
        // Capture images from both cameras
        final frontImage = await _frontController!.takePicture();
        final rearImage = await _rearController!.takePicture();

        // Check for multiple faces in both images
        final frontResult = await _checkMultipleFaces(frontImage.path);
        final rearResult = await _checkMultipleFaces(rearImage.path);

        if (frontResult['multiple_faces'] || rearResult['multiple_faces']) {
          _attemptsLeft--;
          if (_attemptsLeft <= 0) {
            await stopProctoringSession(_currentSessionId!);
            throw Exception(
                'Session ended: Multiple faces detected. No attempts left.');
          }
          throw Exception(
              'Multiple faces detected. ${_attemptsLeft} attempts remaining.');
        }
      } catch (e) {
        debugPrint('Monitoring error: $e');
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> _checkMultipleFaces(String imagePath) async {
    try {
      final url = Uri.parse('$_baseUrl/detect_faces');
      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      return json.decode(responseBody);
    } catch (e) {
      debugPrint('Error checking faces: $e');
      return {'multiple_faces': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkFaceDetection() async {
    try {
      if (!_isSessionActive || _frontController == null) {
        return {'face_detected': false, 'multiple_faces': false};
      }

      // Capture image from front camera
      final XFile image = await _frontController!.takePicture();

      // Check for faces in the image
      final result = await _checkMultipleFaces(image.path);

      // Clean up the captured image
      final file = File(image.path);
      if (await file.exists()) {
        await file.delete();
      }

      return {
        'face_detected': !result['multiple_faces'] && result['face_count'] > 0,
        'multiple_faces': result['multiple_faces'] ?? false,
        'face_count': result['face_count'] ?? 0
      };
    } catch (e) {
      debugPrint('Error in face detection: $e');
      return {
        'face_detected': false,
        'multiple_faces': false,
        'error': e.toString()
      };
    }
  }

  void _startSessionTimer(String sessionId) {
    Future.delayed(Duration(minutes: MAX_SESSION_DURATION_MINUTES), () async {
      if (_isSessionActive) {
        print('Maximum session duration reached');
        try {
          await stopProctoringSession(sessionId);
        } catch (e) {
          print('Error stopping session after timeout: $e');
        }
      }
    });
  }

  int getRemainingSessionTime() {
    if (_sessionStartTime == null || !_isSessionActive) return 0;
    final duration = DateTime.now().difference(_sessionStartTime!);
    final remaining = MAX_SESSION_DURATION_MINUTES - duration.inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  void _startAudioMonitoring() {
    _audioMonitoringTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }

      try {
        // Check for multiple voices
        final result = await _checkAudio();
        if (result['multiple_voices']) {
          _consecutiveAudioViolations++;
          if (_consecutiveAudioViolations >= MAX_AUDIO_VIOLATIONS) {
            await stopProctoringSession(_currentSessionId!);
            throw Exception(
                'Session ended: Multiple voices detected repeatedly.');
          }
          throw Exception(
              'Multiple voices detected. Please ensure you are alone.');
        } else {
          _consecutiveAudioViolations = 0;
        }
      } catch (e) {
        debugPrint('Audio monitoring error: $e');
        rethrow;
      }
    });
  }

  void _startBiometricChecks() {
    _biometricCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }

      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Perform biometric verification
          final verified = await _verifyBiometric(user.uid);
          if (!verified) {
            await stopProctoringSession(_currentSessionId!);
            throw Exception('Session ended: Biometric verification failed.');
          }
        }
      } catch (e) {
        debugPrint('Biometric check error: $e');
        rethrow;
      }
    });
  }

  Future<Map<String, dynamic>> _checkAudio() async {
    try {
      final url = Uri.parse('$_baseUrl/check_audio');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error checking audio: $e');
      return {'multiple_voices': false, 'error': e.toString()};
    }
  }

  Future<bool> _verifyBiometric(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/verify_biometric');
      final response = await http.post(
        url,
        body: json.encode({'userId': userId}),
        headers: {'Content-Type': 'application/json'},
      );
      final result = json.decode(response.body);
      return result['verified'] ?? false;
    } catch (e) {
      debugPrint('Error verifying biometric: $e');
      return false;
    }
  }

  // Stop proctoring session
  Future<void> stopProctoringSession(String sessionId) async {
    if (!_isSessionActive) return;

    try {
      _isSessionActive = false;
      _isMonitoring = false;
      _monitoringTimer?.cancel();
      _audioMonitoringTimer?.cancel();
      _biometricCheckTimer?.cancel();
      await _frontController?.dispose();
      await _rearController?.dispose();
      _frontController = null;
      _rearController = null;

      // Update session document
      await _firestore.collection('proctoring_sessions').doc(sessionId).update({
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
        'violations': {
          'audio': _consecutiveAudioViolations,
          'face': _attemptsLeft,
        }
      });

      print('Successfully ended session: $sessionId');
    } catch (e) {
      print('Error stopping proctoring session: $e');
      throw Exception('Failed to stop proctoring session: ${e.toString()}');
    }
  }

  // Dispose service
  void dispose() {
    _isSessionActive = false;
    _sessionStartTime = null;
    _monitoringTimer?.cancel();
    _audioMonitoringTimer?.cancel();
    _biometricCheckTimer?.cancel();
    _frontController?.dispose();
    _rearController?.dispose();
  }

  Future<List<Candidate>> getCandidates(String electionId) async {
    try {
      print('Fetching candidates for election: $electionId');
      final candidatesSnapshot = await _firestore
          .collection('elections')
          .doc(electionId)
          .collection('candidates')
          .get();

      final candidates = candidatesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Candidate(
          id: doc.id,
          name: data['name'] ?? '',
          party: data['party'] ?? '',
          photoUrl: data['photoUrl'],
          manifesto: data['manifesto'],
          electionId: electionId,
          votes: data['votes'] ?? 0,
        );
      }).toList();

      print('Retrieved ${candidates.length} candidates');
      return candidates;
    } catch (e) {
      print('Error fetching candidates: $e');
      rethrow;
    }
  }

  int get attemptsLeft => _attemptsLeft;
  bool get isMonitoring => _isMonitoring;

  Widget getCameraPreview() {
    if (_frontController == null) {
      return const Center(
        child: Text('Camera not available'),
      );
    }
    return CameraPreview(_frontController!);
  }

  // Verify biometric
  Future<bool> verifyBiometric(String userId) async {
    try {
      final url = Uri.parse('$_baseUrl/verify_biometric');
      final response = await http.post(
        url,
        body: json.encode({'userId': userId}),
        headers: {'Content-Type': 'application/json'},
      );
      final result = json.decode(response.body);
      return result['verified'] ?? false;
    } catch (e) {
      debugPrint('Error verifying biometric: $e');
      return false;
    }
  }
}
