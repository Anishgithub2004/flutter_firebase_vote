import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _serverUrl =
      'http://192.168.0.115:3000'; // Updated with new IP address

  // Get current user profile
  Stream<UserModel?> getCurrentUserProfile() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user ID found');
      return Stream.value(null);
    }

    print('Fetching user profile for ID: $userId');
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        print('No document found for user ID: $userId');
        return null;
      }
      print('User document found: ${doc.data()}');
      return UserModel.fromFirestore(doc);
    }).handleError((error) {
      print('Error fetching user profile: $error');
      return null;
    });
  }

  // Upload document to Firebase Storage
  Future<String> uploadDocument(File file, String type) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5001/api/v0/add'), // Kubo RPC API address
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        final cid = jsonResponse['Hash']; // Get the CID from the response
        return 'https://ipfs.io/ipfs/$cid'; // Return the URL
      } else {
        throw Exception('Failed to upload file');
      }
    } catch (e) {
      print('Error uploading document: $e');
      rethrow;
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File file) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('No user logged in');

      final ref = _storage.ref().child('profile_pictures/$userId');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Update specific profile fields
  Future<bool> updateProfileFields({
    String? username,
    String? address,
    String? mobileNo,
    String? aadharNo,
    String? panCardNo,
    String? voterIdNo,
    int? age,
    String? gender,
    String? constituency,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final Map<String, dynamic> updates = {
        if (username != null) 'name': username,
        if (address != null) 'address': address,
        if (mobileNo != null) 'phone': mobileNo,
        if (aadharNo != null) 'aadharNumber': aadharNo,
        if (panCardNo != null) 'panNumber': panCardNo,
        if (voterIdNo != null) 'voterIdNumber': voterIdNo,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (constituency != null) 'constituency': constituency,
      };

      await _firestore.collection('users').doc(userId).update(updates);
      return true;
    } catch (e) {
      print('Error updating profile fields: $e');
      return false;
    }
  }
}
