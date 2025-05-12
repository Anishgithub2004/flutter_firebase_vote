import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class FaceVerificationScreen extends StatefulWidget {
  final String userId;
  final bool isRegistration;

  const FaceVerificationScreen({
    super.key,
    required this.userId,
    this.isRegistration = false,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Find the front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<String?> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      return image.path;
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture image: $e';
      });
      return null;
    }
  }

  Future<bool> _verifyFace(String imagePath) async {
    try {
      final url = Uri.parse('http://192.168.0.111:5000/verify_face');
      final request = http.MultipartRequest('POST', url)
        ..fields['user_id'] = widget.userId
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final result = json.decode(responseBody);

      if (result['success'] == true) {
        final matchPercentage = result['match_percentage'] * 100;
        setState(() {
          _errorMessage =
              'Face match percentage: ${matchPercentage.toStringAsFixed(2)}%';
        });
        return result['match_percentage'] >= 0.5; // 50% match threshold
      } else if (result['error'] == 'No face images found') {
        setState(() {
          _errorMessage = 'Please register your face first';
        });
        return false;
      }
      return false;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying face: $e';
      });
      return false;
    }
  }

  Future<bool> _registerFace(String imagePath) async {
    try {
      final url = Uri.parse('http://192.168.0.111:5000/register_face');
      final request = http.MultipartRequest('POST', url)
        ..fields['user_id'] = widget.userId
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final result = json.decode(responseBody);

      return result['success'] == true;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error registering face: $e';
      });
      return false;
    }
  }

  Future<void> _processImage() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final imagePath = await _captureImage();
      if (imagePath == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to capture image';
        });
        return;
      }

      bool success;
      if (widget.isRegistration) {
        success = await _registerFace(imagePath);
      } else {
        success = await _verifyFace(imagePath);
      }

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = widget.isRegistration
              ? 'Failed to register face. Please try again.'
              : 'Face verification failed. Please try again.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing image: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRegistration ? 'Register Face' : 'Verify Face'),
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            widget.isRegistration
                                ? 'Please position your face in the center of the frame'
                                : 'Please look at the camera for verification',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isProcessing ? null : _processImage,
                            child: Text(_isProcessing
                                ? 'Processing...'
                                : widget.isRegistration
                                    ? 'Register Face'
                                    : 'Verify Face'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
