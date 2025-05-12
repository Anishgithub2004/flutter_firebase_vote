import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/biometric_service.dart';

class VoterFingerprintRegistrationScreen extends StatefulWidget {
  const VoterFingerprintRegistrationScreen({super.key});

  @override
  State<VoterFingerprintRegistrationScreen> createState() =>
      _VoterFingerprintRegistrationScreenState();
}

class _VoterFingerprintRegistrationScreenState
    extends State<VoterFingerprintRegistrationScreen> {
  final BiometricService _biometricService = BiometricService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _registerFingerprint() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking biometric availability...';
    });

    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _statusMessage = 'No authenticated user found. Please login first.';
          _isLoading = false;
        });
        return;
      }

      // Check if biometric authentication is available
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) {
        setState(() {
          _statusMessage =
              'Biometric authentication is not available on this device';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Please authenticate with your fingerprint...';
      });

      // Authenticate user
      final isAuthenticated =
          await _biometricService.authenticateWithBiometrics();
      if (!isAuthenticated) {
        setState(() {
          _statusMessage = 'Authentication failed. Please try again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Storing biometric data...';
      });

      // Store biometric data and update Firestore
      await _biometricService.storeBiometricData();

      // Update user document in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'hasFingerprint': true,
        'fingerprintRegisteredAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _statusMessage = 'Fingerprint registration successful!';
        _isLoading = false;
      });

      // Show success message and return to dashboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint registration successful!')),
        );
        Navigator.pop(context); // Return to dashboard
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voter Fingerprint Registration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Register your fingerprint for secure voting',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _registerFingerprint,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register Fingerprint'),
            ),
          ],
        ),
      ),
    );
  }
}
