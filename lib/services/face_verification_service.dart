import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class FaceVerificationService {
  static const String baseUrl = 'http://192.168.0.111:5000';

  // Register a new face
  Future<bool> registerFace(String userId, String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$baseUrl/register_face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'imageData': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error registering face: $e');
      return false;
    }
  }

  // Verify a face
  Future<bool> verifyFace(String userId, String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$baseUrl/verify_face'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'imageData': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error verifying face: $e');
      return false;
    }
  }

  // Save image to temporary directory
  Future<String> saveImageToTemp(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
