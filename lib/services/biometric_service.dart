import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Register biometric for admin
  Future<bool> registerAdminBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // First check if user is admin
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can register biometric data');
      }

      // Verify user's identity first
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to register biometric data',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (!isAuthenticated) {
        throw Exception('Biometric authentication failed');
      }

      // Generate biometric reference
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final biometricData = '${timestamp}_unknown';

      // Store biometric data in Firestore with consistent format
      await _firestore.collection('biometric_data').doc(user.uid).set({
        'userId': user.uid,
        'biometricData': biometricData,
        'isActive': true,
        'lastVerifiedAt': FieldValue.serverTimestamp(),
        'role': 'admin',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Store reference locally
      await _secureStorage.write(
        key: 'biometric_reference_${user.uid}',
        value: biometricData,
      );

      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'hasBiometric': true,
        'biometricRegisteredAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error registering admin biometric: $e');
      return false;
    }
  }

  // Register fingerprint for a user
  Future<bool> registerFingerprint(String userId) async {
    try {
      print('Starting fingerprint registration for user: $userId');

      // Verify user's identity first
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to register fingerprint',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        print('User authenticated, proceeding with registration');

        // Generate timestamp for reference
        final timestamp = Timestamp.now();
        final biometricData = {
          'lastUpdated': timestamp,
          'isRegistered': true,
        };

        print('Generated biometric data: $biometricData');

        // Create a transaction to ensure data consistency
        await _firestore.runTransaction((transaction) async {
          print('Starting transaction to store fingerprint data');

          // Store fingerprint data in Firestore
          transaction.set(
            _firestore.collection('biometric_data').doc(userId),
            {
              'userId': userId,
              'biometricData': biometricData,
              'isActive': true,
              'lastVerified': FieldValue.serverTimestamp(),
              'role': 'voter',
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
          print('Stored fingerprint data in biometric_data collection');

          // Update user document
          transaction.update(
            _firestore.collection('users').doc(userId),
            {
              'hasFingerprint': true,
              'fingerprintRegisteredAt': FieldValue.serverTimestamp(),
            },
          );
          print('Updated user document with fingerprint status');
        });

        // Store reference locally - store the timestamp in seconds as a string
        final referenceString = '${timestamp.seconds}_unknown';
        await _secureStorage.write(
          key: 'biometric_reference_$userId',
          value: referenceString,
        );
        print('Stored biometric reference locally: $referenceString');

        return true;
      }
      print('Authentication failed during registration');
      return false;
    } catch (e) {
      print('Error registering fingerprint: $e');
      return false;
    }
  }

  // Verify fingerprint against stored data
  Future<bool> verifyFingerprint(String userId) async {
    try {
      print('Starting fingerprint verification for user: $userId');

      // Get stored reference from Firestore
      final doc =
          await _firestore.collection('biometric_data').doc(userId).get();

      if (!doc.exists) {
        print('No biometric data found in Firestore');
        return false;
      }

      final storedData = doc.data();
      if (storedData == null) {
        print('Biometric data is null');
        return false;
      }

      print('Stored data: $storedData');

      // Get the biometric data
      final biometricData = storedData['biometricData'];
      if (biometricData == null) {
        print('No biometric data found in stored data');
        return false;
      }

      // Perform biometric authentication
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Verify your fingerprint to vote',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        print('Biometric authentication failed');
        return false;
      }

      // Update last verified timestamp
      await _firestore.collection('biometric_data').doc(userId).update({
        'lastVerified': FieldValue.serverTimestamp(),
      });

      print('Biometric verification successful');
      return true;
    } catch (e) {
      print('Error verifying fingerprint: $e');
      return false;
    }
  }

  // Check if user has registered fingerprint
  Future<bool> hasRegisteredFingerprint(String userId) async {
    try {
      print('Checking fingerprint registration for user: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      final hasFingerprint = doc.data()?['hasFingerprint'] ?? false;
      print('User has registered fingerprint: $hasFingerprint');
      return hasFingerprint;
    } catch (e) {
      print('Error checking fingerprint registration: $e');
      return false;
    }
  }

  // Authenticate user with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      print('Starting biometric authentication...');

      // First check if biometrics are available
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('Biometrics not available on this device');
        return false;
      }

      print('Attempting to authenticate...');
      final result = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      print('Authentication result: $result');
      return result;
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }

  // Store biometric data
  Future<bool> storeBiometricData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final docRef = _firestore.collection('biometric_data').doc(user.uid);

      await docRef.set({
        'userId': user.uid,
        'isVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastVerified': FieldValue.serverTimestamp(),
        'biometricData': {
          'type': 'fingerprint',
          'isRegistered': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      });

      return true;
    } catch (e) {
      print('Error storing biometric data: $e');
      return false;
    }
  }

  // Get biometric data from device
  Future<String> _getBiometricData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }
      return '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      print('Error getting biometric data: $e');
      throw Exception('Failed to get biometric data');
    }
  }

  // Verify biometric
  Future<bool> verifyBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user found');
        return false;
      }

      // Use the same verification logic as verifyFingerprint
      return await verifyFingerprint(user.uid);
    } catch (e) {
      print('Error during biometric verification: $e');
      return false;
    }
  }

  // Check if user has valid biometric data
  Future<bool> hasValidBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final docRef = _firestore.collection('biometric_data').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        print('No biometric data found for user');
        return false;
      }

      final data = doc.data();
      if (data == null) return false;

      // Check if biometric data is valid
      final biometricData = data['biometricData'];
      if (biometricData == null) {
        print('Invalid biometric data - missing biometricData field');
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking biometric data: $e');
      return false;
    }
  }

  Future<bool> registerBiometric() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user found');
        return false;
      }

      print('Starting biometric registration for user: ${user.uid}');

      // First check if biometric is available
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        print('Biometric authentication not available');
        return false;
      }

      // Get list of available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        print('No biometrics available');
        return false;
      }

      print('Available biometrics: $availableBiometrics');

      // Try to authenticate
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to register your biometric data',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        print('Authentication failed');
        return false;
      }

      print('Authentication successful, generating reference...');

      // Generate a unique reference for this biometric registration
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final reference = '${timestamp}_unknown';
      print('Generated reference: $reference');

      // Store in Firestore first
      final biometricData = {
        'userId': user.uid,
        'biometricData': reference,
        'isActive': true,
        'lastVerifiedAt': FieldValue.serverTimestamp(),
        'role': 'voter',
        'timestamp': FieldValue.serverTimestamp(),
      };

      print('Storing biometric data in Firestore: $biometricData');
      await _firestore
          .collection('biometric_data')
          .doc(user.uid)
          .set(biometricData);

      // Only store in local storage after successful Firestore update
      await _secureStorage.write(
        key: 'biometric_reference_${user.uid}',
        value: reference,
      );
      print('Stored reference in local storage');

      print('Biometric registration completed successfully');
      return true;
    } catch (e) {
      print('Error during biometric registration: $e');
      return false;
    }
  }
}
