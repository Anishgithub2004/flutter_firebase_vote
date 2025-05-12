import 'dart:io';
import 'dart:async'; // Add this import for TimeoutException
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add this import for MediaType
import 'dart:convert';
import '../models/user_model.dart';
import 'user_service.dart';
import 'package:http/http.dart';

class KYCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  // Update server URL to match MongoDB server
  final String _serverUrl = 'http://192.168.1.7:3000';

  // Submit KYC for verification
  Future<Map<String, dynamic>> submitKYC({
    required UserModel user,
    File? aadharCardFile,
    File? panCardFile,
    File? voterIdFile,
  }) async {
    try {
      String? aadharUrl, panUrl, voterIdUrl;

      // Upload documents to IPFS via Node.js server
      if (aadharCardFile != null) {
        final response =
            await uploadDocument(aadharCardFile, 'aadhar', user.uid);
        if (response['success']) {
          aadharUrl = response['fileUrl'];
        }
      }

      if (panCardFile != null) {
        final response = await uploadDocument(panCardFile, 'pan', user.uid);
        if (response['success']) {
          panUrl = response['fileUrl'];
        }
      }

      if (voterIdFile != null) {
        final response = await uploadDocument(voterIdFile, 'voter', user.uid);
        if (response['success']) {
          voterIdUrl = response['fileUrl'];
        }
      }

      // Update user's record with IPFS links
      final userUpdates = {
        'kycStatus': 'pending',
        'kycSubmittedAt': FieldValue.serverTimestamp(),
        'aadharCardUrl': aadharUrl,
        'panCardUrl': panUrl,
        'voterIdUrl': voterIdUrl,
      };

      await _firestore.collection('users').doc(user.uid).update(userUpdates);

      return {
        'success': true,
        'message': 'KYC submission successful. Pending verification.',
      };
    } catch (e) {
      print('Error in KYC submission: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Upload document to IPFS via Node.js server
  Future<Map<String, dynamic>> uploadDocument(
      File file, String documentType, String userId) async {
    try {
      print('Starting upload to $documentType for user $userId');
      print('Server URL: $_serverUrl');
      print('File path: ${file.path}');

      // Verify file exists and is readable
      if (!await file.exists()) {
        print('File does not exist at path: ${file.path}');
        return {
          'success': false,
          'message': 'File does not exist at path: ${file.path}',
        };
      }

      final fileLength = await file.length();
      print('File size: $fileLength bytes');

      if (fileLength == 0) {
        print('File is empty');
        return {
          'success': false,
          'message': 'File is empty',
        };
      }

      // Create multipart request
      final uri = Uri.parse('$_serverUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add file with explicit content type
      final mimeType = _getMimeType(file.path);
      final stream = http.ByteStream(file.openRead());
      final multipartFile = http.MultipartFile(
        'file',
        stream,
        fileLength,
        filename: file.path.split('/').last,
        contentType: mimeType,
      );

      print('Preparing to upload file:');
      print(' - Name: ${multipartFile.filename}');
      print(' - Size: $fileLength bytes');
      print(' - Type: ${mimeType.toString()}');

      request.files.add(multipartFile);

      // Add metadata
      request.fields['userId'] = userId;
      request.fields['documentType'] = documentType;
      request.fields['name'] = file.path.split('/').last;

      print('Sending request with fields: ${request.fields}');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw TimeoutException('Upload timed out. Please try again.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Upload successful. CID: ${data['cid']}');
          return {
            'success': true,
            'fileUrl': data['fileUrl'],
            'cid': data['cid'],
          };
        } else {
          print('Upload failed: ${data['error']}');
          return {
            'success': false,
            'message': data['error'] ?? 'Upload failed',
          };
        }
      } else {
        print('Upload failed with status ${response.statusCode}');
        try {
          final errorBody = json.decode(response.body);
          return {
            'success': false,
            'message': errorBody['error'] ??
                'Upload failed with status ${response.statusCode}',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Upload failed with status ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Error in uploadDocument: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Helper method to determine MIME type
  MediaType _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  // Get KYC status for the current user
  Future<Map<String, dynamic>> getKYCStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'success': false, 'message': 'User not found'};
      }

      final userData = userDoc.data()!;
      final kycStatus = userData['kycStatus'] ?? 'not_submitted';

      return {
        'success': true,
        'status': kycStatus,
        'submittedAt': userData['kycSubmittedAt'],
        'aadharCardUrl': userData['aadharCardUrl'],
        'panCardUrl': userData['panCardUrl'],
        'voterIdUrl': userData['voterIdUrl'],
      };
    } catch (e) {
      print('Error getting KYC status: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Admin: Verify KYC submission
  Future<Map<String, dynamic>> verifyKYC(
      String userId, String kycId, bool isApproved) async {
    try {
      final adminId = _auth.currentUser?.uid;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin not logged in'};
      }

      // Check if the current user is an admin
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        return {'success': false, 'message': 'Unauthorized access'};
      }

      // Update user record
      await _firestore.collection('users').doc(userId).update({
        'kycStatus': isApproved ? 'approved' : 'rejected',
        'kycVerifiedAt': FieldValue.serverTimestamp(),
        'isVerified': isApproved,
      });

      return {
        'success': true,
        'status': isApproved ? 'approved' : 'rejected',
        'message':
            'KYC has been ${isApproved ? 'approved' : 'rejected'} successfully',
      };
    } catch (e) {
      print('Error verifying KYC: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get KYC transaction history for the current user
  Future<List<Map<String, dynamic>>> getKYCHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('kyc_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error getting KYC history: $e');
      return [];
    }
  }

  // Admin: Get pending KYC submissions
  Future<List<Map<String, dynamic>>> getPendingKYCSubmissions() async {
    try {
      final adminId = _auth.currentUser?.uid;
      if (adminId == null) {
        return [];
      }

      // Check if the current user is an admin
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      if (!adminDoc.exists || adminDoc.data()?['role'] != 'admin') {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('kyc_transactions')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp')
          .get();

      final List<Map<String, dynamic>> pendingSubmissions = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final userDoc =
            await _firestore.collection('users').doc(data['userId']).get();

        if (userDoc.exists) {
          pendingSubmissions.add({
            'id': doc.id,
            ...data,
            'user': UserModel.fromFirestore(userDoc).toMap(),
          });
        }
      }

      return pendingSubmissions;
    } catch (e) {
      print('Error getting pending KYC submissions: $e');
      return [];
    }
  }
}
