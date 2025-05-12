import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MongoDBService {
  // Update this with your computer's IP address when testing on mobile
  static const String baseUrl = 'http://192.168.0.111:3000/api';

  // Document types that match the MongoDB schema
  static const String aadharCardType = 'aadhar_card';
  static const String panCardType = 'pan_card';
  static const String voterIdType = 'voter_id';

  // Test server connection
  static Future<bool> testConnection() async {
    try {
      print('Testing server connection...');
      final response = await http.get(Uri.parse('$baseUrl/'));
      print('Server response: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Upload document to MongoDB
  static Future<String?> uploadDocument(
      File file, String documentType, String userId) async {
    try {
      print('Starting document upload...');
      print('File path: ${file.path}');
      print('Document type: $documentType');
      print('User ID: $userId');

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/documents'),
      );

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      // Add fields
      request.fields['documentType'] = documentType;
      request.fields['userId'] = userId;

      // Send request
      print('Sending request to $baseUrl/api/documents');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      print('Response status: ${response.statusCode}');
      print('Response data: $jsonResponse');

      if (response.statusCode == 201 && jsonResponse['success']) {
        return jsonResponse['documentUrl'];
      } else {
        print('Error uploading document: ${jsonResponse['error']}');
        return null;
      }
    } catch (e) {
      print('Error in uploadDocument: $e');
      return null;
    }
  }

  // Get document from MongoDB
  static Future<File?> getDocument(String documentId) async {
    try {
      print('Fetching document with ID: $documentId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/documents/$documentId'),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final base64String = responseData['file'];
        final bytes = base64Decode(base64String);

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${responseData['fileName']}');
        await tempFile.writeAsBytes(bytes);

        print('Document saved to: ${tempFile.path}');
        return tempFile;
      } else {
        print('Error getting document: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error in getDocument: $e');
      return null;
    }
  }

  // Upload KYC document to MongoDB
  static Future<String?> uploadKYCDocument({
    required String userId,
    required String documentType,
    required String filePath,
  }) async {
    try {
      // Map document types to match MongoDB schema
      final mappedType = switch (documentType) {
        'aadhar' => 'aadhar_card',
        'pan' => 'pan_card',
        'voter' => 'voter_id',
        _ => documentType,
      };

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/documents/upload'),
      );

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: '${userId}_${mappedType}.${filePath.split('.').last}',
        ),
      );

      // Add fields
      request.fields['documentType'] = mappedType;
      request.fields['userId'] = userId;
      request.fields['fileName'] =
          '${userId}_${mappedType}.${filePath.split('.').last}';

      // Send request
      print('Sending request to $baseUrl/api/documents');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      print('Response status: ${response.statusCode}');
      print('Response data: $jsonResponse');

      if (response.statusCode == 201) {
        if (jsonResponse['success'] == true &&
            jsonResponse['documentUrl'] != null) {
          print(
              'Document uploaded successfully: ${jsonResponse['documentUrl']}');
          return jsonResponse['documentUrl'];
        } else {
          print(
              'Error in response: ${jsonResponse['error'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print(
            'Error uploading KYC document. Status: ${response.statusCode}, Error: ${jsonResponse['error'] ?? 'Unknown error'}');
        return null;
      }
    } catch (e) {
      print('Error in uploadKYCDocument: $e');
      return null;
    }
  }

  // Get KYC document from MongoDB
  static Future<File?> getKYCDocument(String documentUrl) async {
    try {
      // Extract document ID from URL
      final documentId = documentUrl.split('/').last;
      print('Fetching KYC document with ID: $documentId');

      final response = await http.get(
        Uri.parse('$baseUrl/documents/$documentId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['file'] == null) {
          print('No file data found in response');
          return null;
        }

        final base64String = responseData['file'];
        final bytes = base64Decode(base64String);

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final fileName = responseData['fileName'] ??
            'document_${DateTime.now().millisecondsSinceEpoch}';
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);

        print('KYC document saved to: ${tempFile.path}');
        return tempFile;
      } else {
        print(
            'Error getting KYC document. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error in getKYCDocument: $e');
      return null;
    }
  }

  // Upload proctoring video to MongoDB
  static Future<String?> uploadProctoringVideo(File videoFile, String sessionId,
      String cameraType, String userId) async {
    try {
      print('Starting proctoring video upload...');
      print('Video path: ${videoFile.path}');
      print('Session ID: $sessionId');
      print('Camera type: $cameraType');

      // Verify file exists in cache
      if (!await videoFile.exists()) {
        print('Video file not found in cache');
        throw Exception('Video file not found in cache');
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/proctoring_videos'),
      );

      // Add file from cache
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          videoFile.path,
          filename: '${sessionId}_${cameraType}.mp4',
        ),
      );

      // Add fields
      request.fields['sessionId'] = sessionId;
      request.fields['cameraType'] = cameraType;
      request.fields['userId'] = userId;

      // Send request
      print('Sending request to $baseUrl/api/proctoring_videos');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      print('Response status: ${response.statusCode}');
      print('Response data: $jsonResponse');

      if (response.statusCode == 201 && jsonResponse['success']) {
        print('Video uploaded successfully');
        return jsonResponse['videoUrl'];
      } else {
        print('Error uploading proctoring video: ${jsonResponse['error']}');
        return null;
      }
    } catch (e) {
      print('Error in uploadProctoringVideo: $e');
      return null;
    }
  }

  // Get proctoring video from MongoDB
  static Future<File?> getProctoringVideo(
      String sessionId, String cameraType) async {
    try {
      print(
          'Fetching proctoring video for session: $sessionId, camera: $cameraType');
      final response = await http.get(
        Uri.parse('$baseUrl/api/proctoring_videos/$sessionId/$cameraType'),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final base64String = responseData['file'];
        final bytes = base64Decode(base64String);

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${responseData['fileName']}');
        await tempFile.writeAsBytes(bytes);

        print('Proctoring video saved to: ${tempFile.path}');
        return tempFile;
      } else {
        print('Error getting proctoring video: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error in getProctoringVideo: $e');
      return null;
    }
  }

  // Get all documents for a user
  static Future<List<Map<String, dynamic>>> getUserDocuments(
      String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/documents/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('Error getting user documents: ${response.body}');
        return [];
      }

      final List<dynamic> documents = json.decode(response.body);
      return documents.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting user documents: $e');
      return [];
    }
  }

  // Delete a document
  static Future<bool> deleteDocument(String documentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/documents/$documentId'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  // Check if user has all required KYC documents
  static Future<Map<String, dynamic>> checkKYCDocuments(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/check-kyc/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'hasAllDocuments': data['hasAllDocuments'] ?? false,
          'documents': data['documents'] ?? {},
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check KYC documents',
          'hasAllDocuments': false,
          'documents': {
            'aadhar': false,
            'pan': false,
            'voterId': false,
          },
        };
      }
    } catch (e) {
      print('Error checking KYC documents: $e');
      return {
        'success': false,
        'error': 'Failed to check KYC documents',
        'hasAllDocuments': false,
        'documents': {
          'aadhar': false,
          'pan': false,
          'voterId': false,
        },
      };
    }
  }

  Future<Map<String, dynamic>> verifyKYCDocuments(String userId) async {
    try {
      print('Verifying KYC documents for user: $userId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/documents/verify/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('KYC verification response: $data');
        return data;
      } else {
        print('Error verifying KYC documents: ${response.statusCode}');
        throw Exception(
            'Failed to verify KYC documents: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in verifyKYCDocuments: $e');
      rethrow;
    }
  }
}
