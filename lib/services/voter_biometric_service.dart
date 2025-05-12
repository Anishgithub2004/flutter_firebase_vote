import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

class VoterBiometricService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Store voter's biometric data
  Future<bool> storeVoterBiometric({
    required String fingerprintData,
    required String deviceId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is a voter
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.data()?['role'] != 'voter') {
        throw Exception('Only voters can register biometric data');
      }

      // Store biometric data
      await _firestore.collection('voter_biometric_data').doc(user.uid).set({
        'userId': user.uid,
        'fingerprintData': fingerprintData,
        'deviceId': deviceId,
        'isVerified': true,
        'lastVerified': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user document to indicate biometric registration
      await _firestore.collection('users').doc(user.uid).update({
        'hasBiometric': true,
        'biometricVerified': true,
        'lastBiometricUpdate': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error storing voter biometric: $e');
      return false;
    }
  }

  // Verify voter's biometric
  Future<bool> verifyVoterBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if biometric data exists
      final biometricDoc = await _firestore
          .collection('voter_biometric_data')
          .doc(user.uid)
          .get();

      if (!biometricDoc.exists) {
        throw Exception('No biometric data found. Please register first.');
      }

      // Perform local biometric authentication
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to verify your identity',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }

      // Update last verified timestamp
      await _firestore.collection('voter_biometric_data').doc(user.uid).update({
        'lastVerified': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error verifying voter biometric: $e');
      return false;
    }
  }

  // Check if voter has registered biometric data
  Future<bool> hasRegisteredBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final biometricDoc = await _firestore
          .collection('voter_biometric_data')
          .doc(user.uid)
          .get();

      return biometricDoc.exists && biometricDoc.data()?['isVerified'] == true;
    } catch (e) {
      print('Error checking biometric registration: $e');
      return false;
    }
  }

  // Get voter's biometric data
  Future<Map<String, dynamic>?> getVoterBiometricData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final biometricDoc = await _firestore
          .collection('voter_biometric_data')
          .doc(user.uid)
          .get();

      if (!biometricDoc.exists) return null;

      return biometricDoc.data();
    } catch (e) {
      print('Error getting voter biometric data: $e');
      return null;
    }
  }

  // Delete voter's biometric data
  Future<bool> deleteVoterBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Delete biometric data
      await _firestore
          .collection('voter_biometric_data')
          .doc(user.uid)
          .delete();

      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'hasBiometric': false,
        'biometricVerified': false,
        'lastBiometricUpdate': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error deleting voter biometric: $e');
      return false;
    }
  }
}
